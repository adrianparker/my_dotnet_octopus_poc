<#
Installs the latest version of the necessary AWS PowerShell modules.

This script is annoyingly complicated to avoid race conditions.
If two runbooks try to install a module at the same time, you run into all sorts of pain.
In development I hit this issue quite often. For example, whenever I tried to build/delete both a Dev and Prod environment at the same time.

To avoid problems, this script saves a "holding file" whenever it tries to install anything.
Each holding file contains the RunbookRunId of the runbook run that created it.
Other runbooks can check these holding files to avoid two runbooks attempting to install the same module simultaneously.

To keep this simple, I've extracted a few helper functions to \Infrastructure\helper_scripts\helper_functions.psm1:
- New-HoldFile
- Test-HoldFile
- Remove-HoldFile
- Test-ModuleInstalled
- Install-ModuleWithHoldFile
- Get-RunbookRunStatus
#>


######################################################
###                     CONFIG                     ###
######################################################


$ErrorActionPreference = "Stop"  

# Importing helper functions
Import-Module -Name "$PSScriptRoot\helper_functions.psm1" -Force

# The modules we need
$requiredModules = @(
    "AWS.Tools.Common",
    "AWS.Tools.EC2",
    "AWS.Tools.IdentityManagement",
    "AWS.Tools.SimpleSystemsManagement",
    "AWS.Tools.SecretsManager"
)
$installedModules = @()
$onHoldModules = @()

# Getting the Octopus URL and API Key from Octopus Variables 
# NOTE: If you want to check the status of competing runbook runs, you need to create an Octopus Variable called OCTOPUS_APIKEY. 
#   (Remember to make it sensitive!)
$checkHoldingProcesses = $true
$octopusApiKey = ""
try {
    $octopusApiKey = $OctopusParameters["OCTOPUS_APIKEY"]
    Write-Output "    Found OCTOPUS_APIKEY from Octopus variables."
}
catch {
    Write-Output "    Failed to read variable OCTOPUS_APIKEY from Octopus Project variables."
    Write-Output "      Will skip checks to see if competing runbookRuns are still running."
    $checkHoldingProcesses = $false
}
$OctopusUrl = ""
try {
    $OctopusUrl = $OctopusParameters["Octopus.Web.ServerUri"]
}
catch {
    Write-Output "    Failed to read variable Octopus.Web.ServerUri from Octopus System Variables."
    Write-Output "      Will skip checks to see if competing runbookRuns are still running."
    $checkHoldingProcesses = $false
}

######################################################
###                INSTALL MODULES                 ###
######################################################

foreach ($module in $requiredModules){
    $holdingProcess = $false
    $moduleAlreadyInstalled = Test-ModuleInstalled -moduleName $module
    if ($moduleAlreadyInstalled){
        Write-Output "    Module $module is already installed."
    }
    else {
        $holdingProcess = Test-HoldFile -holdFileName $module
        if ($holdingProcess){
            $onHoldModules = $onHoldModules + $module
            Write-Output "    Module $module is being installed by $holdingProcess"
        }
        else {
            Write-Output "    Installing $module."
            $installed = Install-ModuleWithHoldFile -moduleName $module
            if ($installed){
                $installedModules = $installedModules + $module
            }
        }
    }
}

######################################################
###          HOLD FOR COMPETING PROCESSES           ##
######################################################

# A little config for the holding pattern while loop
if ((-not ($octopusAPIKey.StartsWith("API-"))) -and ($onHoldModules.length -gt 0)){
    Write-Warning "Octopus API key not formatted correctly."
    Write-Output "Will skip checks that competing runbooks are actually executing."
    $checkHoldingProcesses = $false
}
$time = 0
$timeout = 100
$pollFrequency = 5
$stopwatch =  [system.diagnostics.stopwatch]::StartNew()

# Waiting in a holding pattern until all modules are installed
while ($installedModules.length -lt $requiredModules.length){
    $remainingModules = $requiredModules | Where-Object {$_ -notin $installedModules}
    foreach ($module in $remainingModules){
        if (Test-ModuleInstalled -moduleName $module){
            Write-Output "    $module is now installed"
            $installedModules += $module
        }
    }
    
    # Checking the status of any Runbooks that are holding us up.
    # If other process is not executing, delete the hold file and install.
    if ($checkHoldingProcesses){
        $unexpectedStatusses = @(
            "Success",
            "Failed",
            "TimedOut",
            "Canceled",
            "Cancelling"
        )
        foreach ($module in $remainingModules) {
            $holdingProcess = Test-HoldFile -holdFileName $module
            $holdingProcessStatus = Get-RunbookRunStatus -octopusURL $OctopusUrl -octopusAPIKey $octopusApiKey -runbookRunId $holdingProcess
            Write-Output "      $module is being installed by $holdingProcess. Status is: $holdingProcessStatus"
            if ($holdingProcessStatus -in $unexpectedStatusses){
                Write-Warning "$holdingProcess should not be holding this installation of $module"
                Write-Output "    Attempt to take over install of $module"
                Write-Output "      Deleting holding file."
                Remove-HoldFile -holdFileName $module
                Write-Output "      Installing $module"
                Install-ModuleWithHoldFile -moduleName $module
                Write-Output "    $module is now installed"              
            }
        }
    }

    # Wait a bit, then try again
    $time = [Math]::Floor([decimal]($stopwatch.Elapsed.TotalSeconds))
    if ($time -gt $timeout){
        Write-Warning "This is taking an unusually long time."
        break
    }
    Start-Sleep $pollFrequency
    
}

######################################################
###          CHECK ALL MODULES INSTALLED           ###
######################################################          

# Validating all modules installed successfully
$successfulInstalls = @()
$failedInstalls = @()
foreach ($module in $requiredModules){
    $moduleInstalled = Test-ModuleInstalled -moduleName $module
    if ($moduleInstalled){
        $successfulInstalls += $module
    }
    else {
        $failedInstalls += $module
    }
}
Write-Output "    Successfully installed the following modules: $successfulInstalls"

if ($failedInstalls.length -gt 0){
    $errorMsg = "FAILED TO INSTALL: $failedInstalls"
    Write-Error $ErrorMsg
}
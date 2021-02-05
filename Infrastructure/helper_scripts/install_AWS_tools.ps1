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
###                HELPER FUNCTION                 ###
######################################################

# Helper functions
Function Update-OnHoldModules {
    $freshInstalls = ""
    foreach ($module in $global:onHoldModules){
        $moduleInstalled = Test-ModuleInstalled -moduleName $module
        if ($moduleInstalled) {
            # Add the module to $installedModules
            $global:installedModules = $global:installedModules + $module
            # Remove the module from $onHoldModules
            $global:onHoldModules = $global:onHoldModules | Where-Object { $_ –notlike $module}
            $freshInstalls += "$module, "
        }
    }
    if ($freshInstalls -like ""){
        return $false
    }
    else {
        return $freshInstalls
    }
}

######################################################
###                INSTALL MODULES                 ###
######################################################

foreach ($module in $requiredModules){
    $moduleAlreadyInstalled = Test-ModuleInstalled -moduleName $module
    if ($moduleAlreadyInstalled){
        Write-Output "    Module $module is already installed."
    }
    else {
        $holdingProcess = Test-HoldFile -holdFileName $module
        if ($holdingProcess){
            $onHoldModules = $onHoldModules + $module
            Write-Output "    Module $module is being installed by $holdingProcess."
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
$timeout = 100
$pollFrequency = 5
if ((-not ($octopusAPIKey.StartsWith("API-"))) -and ($onHoldModules.length -gt 1)){
    Write-Warning "Octopus API key not formatted correctly."
    Write-Output "Will skip checks that competing runbooks are actually executing."
    $checkHoldingProcesses = $false
}
$stopwatch =  [system.diagnostics.stopwatch]::StartNew()

# Waiting in a holding pattern until all modules are installed
while ($onHoldModules -gt 0){
    $FreshInstalls = Update-OnHoldModules
    if ($FreshInstalls) {
        "    The following modules have now been installed: $FreshInstalls"
    }
    
    if ($onHoldModules.length -eq 0){
        # Looks like everything should be installed
        break
    }
    
    # Checking the status of any Runbooks that are holding us up.
    # If other process is not executing, delete the hold file and install.
    if ($checkHoldingProcesses){
        foreach ($module in $onHoldModules) {
            $holdingProcess = Test-HoldFile -holdFileName $module
            $holdingProcessStatus = Get-RunbookRunStatus -octopusURL $OctopusUrl -octopusAPIKey $octopusApiKey -runbookRunId $holdingProcess
            if ($holdingProcessStatus -ne ""){
                if ($holdingProcessStatus -like "Executing"){
                    Write-Output "      $module is being installed by $holdingProcess."
                }
                else {
                    Write-Warning "$module was being installed by $holdingProcess. However, $holdingProcess status is $holdingProcessStatus."
                    Write-Output "    Attempt to take over install of $module"
                    Write-Output "      Deleting holding file."
                    Remove-HoldFile -holdFileName $module
                    Write-Output "      Installing $module"
                    Install-ModuleWithHoldFile -moduleName $module
                    Update-OnHoldModules
                }
            }
        }
    }

    # If taking too long, time out
    $currentTime = [Math]::Floor([decimal]($stopwatch.Elapsed.TotalSeconds))
    if ($currentTime -gt $timeout) {
        Write-Error "TIMED OUT!: Locking processes seem to be taking an unusually long time to complete."
        break
    }

    # Wait a bit, then try again
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
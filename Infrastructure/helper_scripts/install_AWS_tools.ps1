$ErrorActionPreference = "Stop"  

# Check to see if holding file exists - implying that another process is already installing AWS Tools
# (If two processes try to install it at the same time it's likely that one will fail, causing a nasty error)
$holdingFilePath = "C:/out"
if (test-path $holdingFilePath){
    Write-Output "    $holdingFilePath already exists."
}
else {
    Write-Output "    Creating directory: $holdingFilePath"
    try {
        New-Item -Type Directory $holdingFilePath | out-null
    }
    catch {
        Write-Output "    Failed to create directory. This sometimes happens if two runbooks are running simultaneously on the same worker."
        if (test-path $holdingFilePath){
            Write-Output "    $holdingFilePath now exists now."
        }
        else {
            Write-Error "Failed to create $holdingFilePath"
        }
    }
}
$holdingFile = "$holdingFilePath/holdingfile.txt"
$warningTime = 90 # seconds
$warningGiven = $false
$timeoutTime = 120 # seconds
if (test-path $holdingFile){
    try {
        $holdingFileText = Get-Content -Path $holdingFile -Raw
        Write-Output "    $holdingFileText"
    }
    catch {
        Write-Output "    Could not read $holdingFile"
    }

    $AwsBeingInstalled = $true
    $stopwatch =  [system.diagnostics.stopwatch]::StartNew()
    while ($AwsBeingInstalled){
        Start-Sleep -s 5

        # If the other runbook has finished
        if (-not (test-path $holdingFile)){
            $AwsBeingInstalled = $false
            Write-Output "    Looks like the AWS Tools install should be finished now."
            Write-Output "    Verifying that AWS Tools is installed correctly..."
            break
        }

        # Checking to see if a new runbook has taken over
        try {
            $latestHoldingFileText = Get-Content -Path $holdingFile -Raw
        }
        catch {
            $latestHoldingFileText = $holdingfiletext
        }
        if ($latestHoldingFileText -notlike $holdingfiletext){
            Write-Output "    A new process is working on the AWS Tools install."
            Write-Output "    $latestHoldingFileText"
            Write-Output "    Re-setting the timer."
            $stopwatch.Restart()
            $holdingfiletext = $latestHoldingFileText 
        }

        # Getting the current second
        $time = [Math]::Floor([decimal]($stopwatch.Elapsed.TotalSeconds))
        
        # If the other runbook is still going
        if ($AwsBeingInstalled){
            Write-Output "      $time seconds: AWS Tools still being installed..."
        }

        # If another runbook is hogging the process for an unusually long time
        if (($time -ge $warningTime) -and (-not $warningGiven)){
            Write-Warning "Installing AWS Tools normally only takes about 70 seconds."
            $warningGiven = $true
        }

        # If another runbook has been hogging for way too long
        if ($time -ge $timeoutTime){
            Write-Output "Timed out at $time seconds."
            Write-Warning "Other Runbook has taken too long. Force delting the holding file."
            try {
                Remove-Item $holdingFile
            }
            catch {
                Write-Error "Failed to delete the holding file"
            }
        }
    }
}

# Create holding file to stop any other runbooks from installing AWS Tools at the same time
$OctopusUrl = "[OctopusUrl unknown]"
try {
    $OctopusUrl = $OctopusParameters["Octopus.Web.ServerUri"]
}
catch {
    Write-Warning "Failed to detect Octopus.Web.ServerUri from Octopus system variables."
}
$RunbookRunId = "[RunbookRunId unknown]"
try {
    $RunbookRunId = $OctopusParameters["Octopus.RunbookRun.Id"]
}
catch {
    Write-Warning "Failed to detect Octopus.RunbookRun.Id from Octopus system variables."
}
$RunbookRunUrlSuffix = "[RunbookRunUrl unknown]"
try {
    $RunbookRunUrlSuffix = $OctopusParameters["Octopus.Web.RunbookRunLink"]
}
catch {
    Write-Warning "Failed to detect Octopus.Web.RunbookRunLink from Octopus system variables."
}
$RunbookUrl = $OctopusUrl + $RunbookRunUrlSuffix 

$startTime = Get-Date

$holdingFileText = @"
Runbook $RunbookRunId started installing AWS tools at: $startTime
Runbook run can be viewed at: $RunbookUrl 
"@

Write-Output "    Creating a holding file at: $holdingFile"
try {$holdingFileText | out-file $holdingFile
}
catch {
    Write-Warning "Failed to create a holding file."
}
# Installing AWS Tools
$Installedmodules = Get-InstalledModule

if ($Installedmodules.name -contains "AWS.Tools.Common"){
    Write-Output "      Module AWS.Tools.Common is already installed "
}
else {
    Write-Output "      AWS.Tools.Common is not installed."
    Write-Output "        Installing AWS.Tools.Common..."
    Install-Module AWS.Tools.Common -Force
}

if ($Installedmodules.name -contains "AWS.Tools.EC2"){
    Write-Output "      Module AWS.Tools.EC2 is already installed."
}
else {
    Write-Output "      AWS.Tools.EC2 is not installed."
    Write-Output "        Installing AWS.Tools.EC2..."
    Install-Module AWS.Tools.EC2 -Force
}

if ($Installedmodules.name -contains "AWS.Tools.IdentityManagement"){
    Write-Output "      Module AWS.Tools.IdentityManagement is already installed "
}
else {
    Write-Output "      AWS.Tools.IdentityManagement is not installed."
    Write-Output "        Installing AWS.Tools.IdentityManagement..."
    Install-Module AWS.Tools.IdentityManagement -Force
}

if ($Installedmodules.name -contains "AWS.Tools.SimpleSystemsManagement"){
    Write-Output "      Module AWS.Tools.SimpleSystemsManagement is already installed "
}
else {
    Write-Output "      AWS.Tools.SimpleSystemsManagement is not installed."
    Write-Output "        Installing AWS.Tools.SimpleSystemsManagement..."
    Install-Module AWS.Tools.SimpleSystemsManagement -Force
}

Write-Output "      AWS Tools is set up and ready to use."

# Delete holding file
Write-Output "    Removing holding file."
try {
    Remove-Item $holdingFile
}
catch {
    if (test-path $holdingFilePath){
        $holdingFileText = Get-Content -Path $holdingFile -Raw
        Write-Error "Tried to delete holding file at $holdingFilePath, but it does exist. Content: $holdingFileText"
    }
    else {
        Write-Warning "Tried to delete holding file at $holdingFilePath, but it wasnt there?"
    }
}

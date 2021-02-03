Function Install-ModuleSafely {
    param (
        [Parameter(Mandatory=$true)]$moduleName = "",
        $holdFileDir = "C:/holdingFiles",
        [Parameter(Mandatory=$true)]$octopusApiKey = ""
    )

    # Attempting to read some variables from Octopus Deploy
    $OctopusUrl = "[OctopusUrl unknown]"
    try {
        $OctopusUrl = $OctopusParameters["Octopus.Web.ServerUri"]
    }
    $RunbookRunId = "[RunbookRunId unknown]"
    try {
        $RunbookRunId = $OctopusParameters["Octopus.RunbookRun.Id"]
    }

    # Creating a directory to store holding files
    if (-not (test-path $holdFileDir)){
        Write-Verbose "    Creating directory: $holdFileDir"
        try {
            New-Item -Type Directory $holdFileDir | out-null
        }
        catch {
            if (-not (test-path $holdFileDir)){
                Write-Error "Failed to create $holdFileDir when trying to install $moduleName"
            }
        }
    }

    # The holding file should be saved to this location
    $holdingFile = "$holdFileDir/$moduleName.txt"

    # IF another runbook has created a holding file
    # AND the other runbook is currently executing
    # THEN wait until the holding file dissappears
    # OTHERWISE, create a new holding file and continue
    $currentWaitTime = 0
    $previousText = ""
    while ($currentWaitTime -lt 100){
        $currentHoldingFileText = ""
        # IF Another runbook has created a holding file
        if (test-path $holdingFile){
            # Reading the hold file to check which RunbookRun is holding us up.
            try {
                $currentHoldingFileText = Get-Content -Path $holdingFile -Raw
                Write-Verbose "    Installation is blocked by $currentHoldingFileText"
            }
            catch {
                Write-Verbose "    Could not read $holdingFile"
            }
            # If it's a different RunbookRun from last time, let's restart our timer.
            if ($previousText -notlike $currentHoldingFileText){
                $currentWaitTime = 0
            }
            # Checking to see if the other RunbookRun is actually executing
            try {
                $otherRunbookRunStatus = Get-RunbookRunStatus -octopusURL $OctopusUrl -octopusAPIKey $octopusApiKey -runbookRunId $currentHoldingFileText
            }
            catch {
                Write-Warning "    Function Get-RunbookRunStatus failed. Cannot verify status of RunbookRun: $currentHoldingFileText"
            }
            # If the other RunbookRun is not actually executing, it probably failed.
            # Delete the holding file and break the loop. 
            if (($otherRunbookRunStatus -notlike "Executing") -and ($otherRunbookRunStatus -ne $false)){
                Write-Verbose "    $currentHoldingFileText status is $otherRunbookRunStatus"
                Write-Verbose "    Ignoring hold file."
                try {
                    Remove-Item $holdingFile
                }
                catch {
                    Write-Warning "Tried to delete $holdingFile but failed."
                }
                break
            }
        }
        # ELSE, there is no holding file. Break out of the loop
        else {
            break
        }
        # Preparing for another trip around this loop
        Start-Sleep 5
        $currentWaitTime = $currentWaitTime + 5
        $previousText = $currentHoldingFileText    
    }

    # Creating the holding file
    Write-Verbose "    Creating a holding file at: $holdingFile"
    try {$RunbookRunId | out-file $holdingFile
    }
    catch {
        Write-Warning "Failed to create a holding file."
    }

    # Installing the module
    if ($Installedmodules.name -contains $moduleName){
        Write-Output "      $moduleName is already installed "
    }
    else {
        Write-Output "      $moduleName is not installed."
        Write-Output "        Installing $moduleName..."
        Install-Module $moduleName -Force
    }

    # Removing the holding file
    try {
        Remove-Item $holdingFile
    }
    catch {
        Write-Warning "Tried to delete $holdingFile but failed."
    }
}

Function Get-RunbookRunStatus {
    param (
        [Parameter(Mandatory=$true)]$octopusURL, # e.g. "https://example.octopus.app"
        [Parameter(Mandatory=$true)]$octopusAPIKey, # e.g. "API-12345667890ABCDEF"
        [Parameter(Mandatory=$true)]$runbookRunId # e.g. "RunbookRuns-123"
    )

    if (-not ($octopusAPIKey.StartsWith("API-"))){
        return $false
    }

    # Using API Key provided above to create a header to authenticate against the Octopus API
    $header = @{ "X-Octopus-ApiKey" = $octopusAPIKey }

    # First we need to use the API to find the ServerTask link for the Runbook Run
    $runbookRun = (Invoke-RestMethod -Method Get -Uri "$octopusURL/api/Spaces-1/runbookruns" -Headers $header).Items | Where-Object {($_.Id -like $runbookRunId)}
    $taskUrlSuffix = $runbookRun.Links.Task
    $taskUrl = $octopusURL + $taskUrlSuffix

    # Then we make a second API call to determine the status of the ServerTask
    $serverTask = (Invoke-RestMethod -Method Get -Uri $taskUrl -Headers $header)
    
    $state = $serverTask.State
    
    return $state
}
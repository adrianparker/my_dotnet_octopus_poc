Function Get-RunbookRunStatus {
    param (
        [Parameter(Mandatory=$true)]$octopusURL, # e.g. "https://example.octopus.app"
        [Parameter(Mandatory=$true)]$octopusAPIKey, # e.g. "API-12345667890ABCDEF"
        [Parameter(Mandatory=$true)]$runbookRunId # e.g. "RunbookRuns-123"
    )

    <#
    Possible states include:
    - Executing
    - Success
    - Failed
    - TimedOut
    - Canceled
    - Canceling (or Cancelling? Not managed to repro and link below is ambiguous.)
    - Queued
    #>

    if (-not ($octopusAPIKey.StartsWith("API-"))){
        Write-Error "Octopus API Key is not valid: $octopusAPIKey"
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

Function New-HoldFile {
    param (
        $holdFileName = "hold",
        $holdFileDir = "C:/holdingFiles"
    )

    # Creating directory for holding files
    if (-not (test-path $holdFileDir)){
        Write-Verbose "    Creating directory: $holdFileDir"
        try {
            New-Item -Type Directory $holdFileDir | out-null
        }
        catch {
            Write-Verbose "    Failed to create directory. This sometimes happens if two runbooks are running simultaneously on the same worker."
            # creating a little random delay to avoid race conditions
            $random = Get-Random -Maximum 10
            Start-Sleep $random
            if (test-path $holdFileDir){
                Write-Verbose "    $holdFileDir now exists now."
            }
            else {
                Write-Error "Failed to create $holdFileDir"
            }
        }
    }

    # Holding file will be created here
    $holdingFile = "$holdFileDir/$holdFileName.txt"
    
    # Checking the RunbookRunId
    $RunbookRunId = "[RunbookRunId unknown]"
    try {
        $RunbookRunId = $OctopusParameters["Octopus.RunbookRun.Id"]
    }
    catch {
        Write-Warning "Unable to read Octopus.RunbookRun.Id from Octopus variables"
    }
    
    # Creating the holding file
    try {
        $RunbookRunId | out-file $holdingFile | out-null
        return $true
    }
    catch {
        Write-Warning "Failed to create holding file."
        return $false
    }
}

Function Test-HoldFile {
    param (
        $holdFileName = "hold",
        $holdFileDir = "C:/holdingFiles"
    )

    # Holding file should be here
    $holdingFile = "$holdFileDir/$holdFileName.txt"
    
    # If the hold file doesn't exist, return false
    if (-not (test-path $holdFileDir)){
        # Hold file does not exists
        return $false
    }

    # Otherwise, return the content of the holding file 
    try {
        $text = Get-Content -Path $holdingFile -Raw
    }
    catch {
        $text = "Unable to read hold file $holdingFile"
    }
    return $text
}

Function Remove-HoldFile {
    param (
        $holdFileName = "hold",
        $holdFileDir = "C:/holdingFiles"
    )
    
    # Holding file should be here
    $holdingFile = "$holdFileDir/$holdFileName.txt"

    # Deleting the holding file
    try {
        Remove-Item $holdingFile | out-null
    }
    catch {
        Write-Warning "Tried to delete $holdingFile but failed."
    }
}

Function Install-ModuleWithHoldFile {
    param (
        [Parameter(Mandatory=$true)]$moduleName
    )
    
    # Creates a hold file, to warn any parrallel processes
    $holdFileCreated = New-HoldFile -holdFileName $moduleName

    if ($holdFileCreated){
        # Installs the module
        Install-Module $moduleName -Force | out-null
    
        # Removes the hold file
        Remove-HoldFile -holdFileName $moduleName | out-null
        return $true
    }
    else {
        return $false
    }
}

Function Test-ModuleInstalled {
    param (
        [Parameter(Mandatory=$true)]$moduleName
    )

    If (Get-InstalledModule $moduleName -ErrorAction silentlycontinue) {
        return $true
    }
    else {
        return $false
    }
}
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

    # Otherwise, return the content of the holding file 
    try {
        $text = Get-Content -Path $holdingFile -Raw
        return $text
    }
    catch {
        return $false
    }
    Write-Error "Something went wrong with the Test-HoldFile function"
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
        $installed = $false
        try {
            Install-Module $moduleName -Force | out-null
            $installed = $true
        }
        catch {
            Write-Warning "Failed to install $moduleName. Most likely some other process is doing it."
        }
        # Removes the hold file
        Remove-HoldFile -holdFileName $moduleName | out-null
        return $installed
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
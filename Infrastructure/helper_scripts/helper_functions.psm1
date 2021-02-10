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
        Write-Output "Tried to delete $holdingFile but failed."
    }
}

Function Remove-AllHoldFiles {
    param (
        $holdFileDir = "C:/holdingFiles"
    )

    # Deleting all the holding file
    try {
        Remove-Item "$holdFileDir/*" -Force
    }
    catch {
        Write-Warning "Tried to delete $holdFileDir/*, but failed."
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

# Pings a given IPv4 addrerss to see if the defaul IIS site is running
function Test-IIS {
    param (
        $ip
    )
    try { 
        $content = Invoke-WebRequest -Uri $ip -TimeoutSec 1 -UseBasicParsing
    }
    catch {
        return $false
    }
    if ($content.toString() -like "*iisstart.png*"){
    return $true
    }
}

# Checks whether a tentacle exists with a specific IP address
function Test-Tentacle {
    param (
        [Parameter(Mandatory=$true)][string]$ip,
        [Parameter(Mandatory=$true)][string]$OctopusUrl,
        [Parameter(Mandatory=$true)][string]$APIKey        
    )
    # Authenticating to the API
    try {
        $header = @{ "X-Octopus-ApiKey" = $APIKey }
    }
    catch {
        Write-Warning 'Failed to read the Octopus API Key from $OctopusParameters["API_KEY"].'
    }
    $URL = "https://" + $ip + ":10933/"
    $allMachines = ((Invoke-WebRequest ("$OctopusUrl/api/machines") -Headers $header -UseBasicParsing).content | ConvertFrom-Json).items
    if ($allMachines.Uri -contains $URL){
        return $true
    }
    else {
        return $false
    }
}

# Updates calimari on a given machine
function Update-Calamari {
    param (
        [Parameter(Mandatory=$true)][string]$ip,
        [Parameter(Mandatory=$true)][string]$OctopusUrl,
        [Parameter(Mandatory=$true)][string]$APIKey
    )
    
    # Creating an API header from API key
    $header = @{ "X-Octopus-ApiKey" = $APIKey }

    $Uri = "https://" + $ip + ":10933/"

    # Use Octopus API to work out MachineName from MachineId
    $allMachines = ((Invoke-WebRequest ("$OctopusUrl/api/machines") -Headers $header -UseBasicParsing).content | ConvertFrom-Json).items
    $thisMachine = $allMachines | Where-Object {$_.Uri -like $Uri}
    $MachineName = $thisMachine.Name
    $MachineId = $thisMachine.Id
    
    # The body of the API call
    $body = @{ 
        Name = "UpdateCalamari" 
        Description = "Updating calamari on $MachineName" 
        Arguments = @{ 
            Timeout= "00:05:00" 
            MachineIds = @($MachineId) #$MachineId could contain an array of machines too
        } 
    } | ConvertTo-Json
    
    Invoke-RestMethod $OctopusUrl/api/tasks -Method Post -Body $body -Headers $header | out-null
}

Function Test-SecretsManagerRoleExists {
    try {
        Get-IAMRole SecretsManager | out-null
        return $true
    }
    catch {
        return $false
    } 
}

Function Test-RoleAddedToProfile {
    try {
        $added = (Get-IAMInstanceProfileForRole -RoleName SecretsManager) | Where-Object {$_.InstanceProfileName -like "RandomQuotes"}
    }
    catch {
        # The Secrets Manager role does not exist 
        return $false
    }
    if ($added){
        # The Secrets Manager role exists, and is added to the RandomQuotes profile
        return $true
    }
    else {
        # The Secrets Manager role exists, but is not added to the RandomQuotes profile 
        return $false
    }
}

Function Test-RandomQuotesProfileExists {
    try {
        Get-IAMInstanceProfile -InstanceProfileName RandomQuotes | out-null
        return $true
    }
    catch {
        return $false
    }
}

Function Test-SecurityGroup {
    param (
        $groupName
    )
    try {
        Get-EC2SecurityGroup -GroupName $groupName | out-null
        return $true
    }
    catch {
        return $false
    }
}

Function Test-SecurityGroupPorts {
    param (
        $groupName,
        $requiredPorts = @()
    )
    try {
        $sg = Get-EC2SecurityGroup -GroupName $groupName
        $openPorts = $sg.IpPermissions.FromPort
        foreach ($port in $requiredPorts) {
            if ($port -notin $openPorts){
                # SecurityGroup exists, but is misconfigured
                return $false
            }
        }
        # SecurityGroup exists, and all the required ports are open
        return $true
    }
    catch {
        # SecurityGroup probably does not exist
        return $false
    }
}

function Test-KeyPair {
    param (
        $name
    )

    try {
        Get-EC2KeyPair -KeyName $name | out-null
        return $true
    }
    catch {
        return $false
    }
}
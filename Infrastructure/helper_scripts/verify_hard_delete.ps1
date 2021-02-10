param(
    [Switch]$SkipKeyPair
)

# Importing helper functions
Import-Module -Name "$PSScriptRoot\helper_functions.psm1" -Force

# Explicitely checking that various objects are gone
if (Test-SecretsManagerRoleExists){
    Write-Warning "Uh oh! SecretsManager role still exists!"
}
if (Test-RandomQuotesProfileExists){
    Write-Warning "Uh oh! RandomQuotes profile still exists!"
}
if (Test-SecurityGroup -groupName RandomQuotes){
    Write-Warning "Uh oh! RandomQuotes security group still exists!"
}
if ((-not $SkipKeyPair) -and (Test-KeyPair -name "RandomQuotes")){
    Write-Warning "Uh oh! RandomQuotes key pair still exists!"
}

# Cleaning up any left over PowerShell module installation hold files
Remove-AllHoldFiles

# Checking for any other objects with a "RandomQuotes" tag
$allTaggedResources = Get-EC2Tag 
$randomQuotesTaggedObjects = $allTaggedResources | Where-Object {$_.Key -like "*RandomQuotes*"}

# Removing any instances from list that are currently being stopped/terminated
$instances = $randomQuotesTaggedObjects | Where-Object {$_.ResourceType -like "instance"}
$instanceIds = $instances.ResourceId
$acceptableStates = @("shutting-down","terminated","stopping","stopped")
ForEach ($instanceId in $instanceIds){
    if ((Get-EC2Instance -InstanceId $instanceId -Filter @{Name="instance-state-name";Values=$acceptableStates}).Instances){
        $randomQuotesTaggedObjects = $randomQuotesTaggedObjects | Where-Object {$_.ResourceId -notlike $instanceId}
    } 
}

# If there are any resources still in the list, something probably went wrong
if($randomQuotesTaggedObjects.Length -gt 0){
    Write-Warning "Uh oh: It looks like some resources are still running. Please check the following resources manually."
    Write-Output $randomQuotesTaggedObjects  
}
else {
    Write-Output "SUCCESS: All objects with a RandomQuotes tag have been/are being deleted."
}
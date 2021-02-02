# Getting all objects with a tag key that contains "RandomQuotes"
$allTaggedResources = Get-EC2Tag 
$randomQuotesTaggedObjects = $allTaggedResources | Where-Object {$_.Key -like "*RandomQuotes*"}

# Removing any instances that are currently being stopped/terminated
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
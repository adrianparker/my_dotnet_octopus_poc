param(
    $securityGroupName = "RandomQuotes"
)

$ErrorActionPreference = "Stop"  

# Importing helper functions
Import-Module -Name "$PSScriptRoot\helper_functions.psm1" -Force

$attempt = 1
$totalAttempts = 20
$waitTime = 5

# Deleting security group
while ($attempt -lt $totalAttempts){
    Write-Output "      Attempt $attempt / $totalAttempts to delete security group: $securityGroupName"
    if (Test-SecurityGroup -groupName $securityGroupName) {
        
        try {
            Remove-EC2SecurityGroup -GroupName $securityGroupName -Force
            if  (Test-SecurityGroup -groupName $securityGroupName) {
                Write-Error "Failed to remove security group $securityGroupNam."
            }
            else {
                Write-Output "    Security group $securityGroupName has been deleted."
                break
            }

        }
        catch {
            Write-Output "        Failed to remove security group. Error was:"
            $lastError = $Error[0]
            Write-Output "          $lastError"
            if ($attempt -eq 1) {
                Write-Output "        (We probably need to wait about a minute for the instances to shut down.)"
            }
            if ($attempt -lt $totalAttempts) {
                Write-Output "        Waiting $waitTime seconds then trying again."
                Start-Sleep -s $waitTime
            }
            else {
                Write-Error "Failed to delete security group. Ran out of attempts. If it was dependencies, ensure all instances are terminated, then try again."
            }
        }
        $attempt = $attempt + 1
    }
    else {
        "    Security group $securityGroupName does not exist in EC2. No need to delete it."
        break
    }
    $attempt = $attempt + 1
}

param(
    $securityGroupName = "RandomQuotes"
)

$ErrorActionPreference = "Stop"  



$createGroup = $false
try {
    Get-EC2SecurityGroup -GroupName $securityGroupName | out-null
    Write-Output "    Security group $securityGroupName already exists."
}
catch {
    Write-Output "    Security group $securityGroupName does not exist."
    $createGroup = $true
}

if ($createGroup){
    # Creates a new security group
    Write-Output "    Creating security group $securityGroupName."
    $securityGroup = New-EC2SecurityGroup -GroupName $securityGroupName -Description "Accepts Web, RDP and Octopus traffic from any IP address."

    # Tags the security group
    $Tag = New-Object Amazon.EC2.Model.Tag
    $Tag.Key = "RandomQuotes"
    $Tag.Value = ""
    New-EC2Tag -Resource $securityGroup -Tag $Tag

    # Creates an IP rule to enable inbound RDP and Octopus traffic from any device and adds it to security group
    Write-Output "    Enabling public RDP traffic to all VMs in the group $securityGroupName."
    $ip1 = @{ IpProtocol="tcp"; FromPort="3389"; ToPort="3389"; IpRanges="0.0.0.0/0" } # Remote Desktop
    $ip2 = @{ IpProtocol="tcp"; FromPort="10933"; ToPort="10933"; IpRanges="0.0.0.0/0" } # Octopus Deploy
    $ip3 = @{ IpProtocol="tcp"; FromPort="80"; ToPort="80"; IpRanges="0.0.0.0/0" } # Website hosting
    Grant-EC2SecurityGroupIngress -GroupName $securityGroupName -IpPermission @($ip1, $ip2, $ip3)
}
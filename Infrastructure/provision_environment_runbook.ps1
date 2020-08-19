param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()]$awsAccessKey,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()]$awsSecretKey,
    $defaulAwsRegion = "eu-west-1", # Other carbon neutral regions are listed here: https://aws.amazon.com/about-aws/sustainability/
    $securityGroupName = "octopus-demobox",
    $count = 1,
    $instanceType = "t2.micro", # 1 vCPU, 1GiB Mem, free tier elligible: https://aws.amazon.com/ec2/instance-types/
    $ami = "ami-0216167faf008006e", # Microsoft Windows Server 2019 Base with Containers
    $tagName = "RandomQuotes",
    $tagValue = "Created manually",
    $octoUrl = "",
    $octoEnv = "",
    [Switch]$DeployTentacle
)

$ErrorActionPreference = "Stop"  

Write-Output "*"
Write-Output "Setup..."
Write-Output "*"

# If (this script it executed by Octopus AND $DeployTentacle is true):
# Updating default values for octoEnv, octoUrl and tagValue
if ($DeployTentacle){
    try {
        if ($octoUrl -like ""){
            $msg = "Octopus URL detected: " + $OctopusParameters["Octopus.Web.ServerUri"]
            Write-Output $msg
            $octoUrl = $OctopusParameters["Octopus.Web.ServerUri"]
        }
    }
    catch {
        if ($DeployTentacle){
            $DeployTentacle = $false
            Write-Warning "No Octopus URL detected. Cannot deploy the Tentacle"
        }
    }
}

try {
    if ($octoEnv -like ""){
        $msg = "Octopus Environment detected: " + $OctopusParameters["Octopus.Environment.Name"]
        Write-Output $msg
        $octoEnv = $OctopusParameters["Octopus.Environment.Name"]
    }
}
catch {
    $DeployTentacle = $false
    Write-Warning "No Octopus Environment detected. Cannot deploy the Tentacle"
}

# If no default tag has been provided, but we do have an octoEnv, set tagValue to octoEnv
if (($tagValue -like "Created manually") -and ($OctoEnv -notlike "") ){
    $tagValue = $octoEnv
}


Write-Output "  Execution root dir: $PSScriptRoot"
Write-Output "*"

# Install AWS tools
Write-Output "Executing .\helper_scripts\install_AWS_tools.ps1..."
Write-Output "  (No parameters)"
& $PSScriptRoot\helper_scripts\install_AWS_tools.ps1
Write-Output "*"

# Configure your default profile
Write-Output "Executing .\helper_scripts\configure_default_aws_profile.ps1..."
Write-Output "  (No parameters)"
& $PSScriptRoot\helper_scripts\configure_default_aws_profile.ps1 -AwsAccessKey $awsAccessKey -AwsSecretKey $awsSecretKey -DefaulAwsRegion $defaulAwsRegion
Write-Output "*"

# Creates a security group in AWS to allow RDP sessions on all your demo VMs
Write-Output "Executing .\helper_scripts\create_security_group.ps1..."
Write-Output "  Parameters: -securityGroupName $securityGroupName"
& $PSScriptRoot\helper_scripts\create_security_group.ps1 -securityGroupName $securityGroupName
Write-Output "*"

# Creates the VMs
Write-Output "Executing .\helper_scripts\create_demoboxes.ps1..."
Write-Output "  Parameters: -count $count -instanceType $instanceType -ami $ami -tagName $tagName -tagValue $tagValue -octoUrl $octoUrl -octoEnv $octoEnv -DeployTentacle:$DeployTentacle"
& $PSScriptRoot\helper_scripts\create_demoboxes.ps1 -count $count -instanceType $instanceType -ami $ami -tagName $tagName -tagValue $tagValue -octoUrl $octoUrl -octoEnv $octoEnv -DeployTentacle:$DeployTentacle
Write-Output "*"
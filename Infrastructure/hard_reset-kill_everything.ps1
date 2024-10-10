param(
    $awsAccessKey = "",
    $awsSecretKey = "",
    $defaulAwsRegion = "ap-southeast-2", # Other carbon neutral regions are listed here: https://aws.amazon.com/about-aws/sustainability/
    [Switch]$SkipKeyPair,
    [Switch]$SkipSecrets
)

$ErrorActionPreference = "Stop"  

# Setting default values for parameters

$missingParams = @()

if ($awsAccessKey -like ""){
    try {
        $awsAccessKey = $OctopusParameters["AWS_ACCOUNT.AccessKey"]
        Write-Output "Found value for awsAccessKey from Octopus variables." 
    }
    catch {
        $missingParams = $missingParams + "-awsAccessKey"
    }
}

if ($awsSecretKey -like ""){
    try {
        $awsSecretKey = $OctopusParameters["AWS_ACCOUNT.SecretKey"]
        Write-Output "Found value for awsSecretKey from Octopus variables." 
    }
    catch {
        $missingParams = $missingParams + "-awsSecretKey"
    }
}

if ($missingParams.Count -gt 0){
    $errorMessage = "Missing the following parameters: "
    foreach ($param in $missingParams) {
        $errorMessage += "$param, "
    }
    Write-Error $errorMessage
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
Write-Output "  Parameters: -AwsAccessKey $awsAccessKey -AwsSecretKey *** -DefaulAwsRegion $defaulAwsRegion"
& $PSScriptRoot\helper_scripts\configure_default_aws_profile.ps1 -AwsAccessKey $awsAccessKey -AwsSecretKey $awsSecretKey -DefaulAwsRegion $defaulAwsRegion
Write-Output "*"

# Delete the RandomQuotes Instances
Write-Output "Executing .\helper_scripts\delete_all_randomquotes_infra.ps1..."
Write-Output "  (No parameters)"
& $PSScriptRoot\helper_scripts\delete_all_randomquotes_infra.ps1 
Write-Output "*"

if ($SkipKeyPair){
    Write-Output "Skipping the keypair..."
}
else {
    # Delete the RandomQuotes Keypair
    Write-Output "Executing .\helper_scripts\delete_randomquotes_keypair.ps1..."
    Write-Output "  (No parameters)"
    & $PSScriptRoot\helper_scripts\delete_randomquotes_keypair.ps1 
}
Write-Output "*"

# Delete the RandomQuotes Security Group
Write-Output "Executing .\helper_scripts\delete_randomquotes_securitygroup.ps1..."
Write-Output "  (No parameters)"
& $PSScriptRoot\helper_scripts\delete_randomquotes_securitygroup.ps1 
Write-Output "*"

# Delete IAM Role
Write-Output "Executing .\helper_scripts\delete_randomquotes_iam_role.ps1..."
Write-Output "  (No parameters)"
& $PSScriptRoot\helper_scripts\delete_randomquotes_iam_role.ps1 
Write-Output "*"

if ($SkipSecrets){
    Write-Output "Skipping the secrets..."
}
else {
    # Deleting AWS Secrets
    Write-Output "Deleting AWS Secret: OCTOPUS_APIKEY"
    Remove-SECSecret -SecretId OCTOPUS_APIKEY -DeleteWithNoRecovery:$true -Force | Out-Null
    Write-Output "Deleting AWS Secret: OCTOPUS_THUMBPRINT"
    Remove-SECSecret -SecretId OCTOPUS_THUMBPRINT -DeleteWithNoRecovery:$true -Force | Out-Null
}
Write-Output "*"

# Verifying that everything has been deleted
Write-Output "Executing .\helper_scripts\verify_hard_delete.ps1..."
Write-Output "  (No parameters)"
& $PSScriptRoot\helper_scripts\verify_hard_delete.ps1 -SkipKeyPair:$SkipKeyPair
Write-Output "*"

Write-Output " "
Write-Output "RandomQuotes is Dead."

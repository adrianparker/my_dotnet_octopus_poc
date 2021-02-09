$ErrorActionPreference = "Stop"

# Importing helper functions
Import-Module -Name "$PSScriptRoot\helper_functions.psm1" -Force

# If role exists, delete it
if (Test-SecretsManagerRoleExists) {
    Write-Output "      Removing policy from SecretsManager role."
    Get-IAMAttachedRolePolicyList -RoleName SecretsManager | Unregister-IAMRolePolicy -RoleName SecretsManager
    
    Write-Output "      Attempting to remove SecretsManager role RendomQuotes profile."
    try {
        Remove-IAMRoleFromInstanceProfile -InstanceProfileName RandomQuotes -RoleName SecretsManager -Force
        Write-Output "      Removed role SecretsManager from profile RandomQuotes"
    }
    catch {
        Write-Output "      Role SecretsManager was not added to profile RandomQuotes"
    }
    
    Write-Output "      Removing SecretsManager role."
    Remove-IAMRole -RoleName SecretsManager -Force    
}

# If RandomQuotes profile exists, delete it.
try {
    Remove-IAMInstanceProfile -InstanceProfileName RandomQuotes -Force
    Write-Output "      Removed profile RandomQuotes."
}
catch {
    Write-Output "      Profile RandomQuotes does not exist."
}
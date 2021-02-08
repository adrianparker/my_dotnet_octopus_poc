try {
    Remove-IAMRoleFromInstanceProfile -InstanceProfileName RandomQuotes -RoleName SecretsManager -Force
    Write-Output "    Existing SecretsManager role removed from profile RandomQuotes."
}
catch {
    Write-Output "    SecretsManager role is not already added to profile RandomQuotes"
}

try {
    Remove-IAMInstanceProfile -InstanceProfileName RandomQuotes -Force
    Write-Output "    Removed existing profile RandomQuotes."
}
catch {
    Write-Output "    Profile RandomQuotes does not already exist."
}

Write-Output "    Creating new profile: RandomQuotes"
New-IAMInstanceProfile -InstanceProfileName RandomQuotes | out-null

Write-Output "    Adding SecretsManager role to profile RandomQuotes."
Add-IAMRoleToInstanceProfile -InstanceProfileName RandomQuotes -RoleName SecretsManager

param(
    $keyPairName = "RandomQuotes"
)

$ErrorActionPreference = "Stop"  

# Importing helper functions
Import-Module -Name "$PSScriptRoot\helper_functions.psm1" -Force

# Deleting keypair
$keyPairExistsBefore = Test-KeyPair $keyPairName
if ($keyPairExistsBefore) {
    Write-Output "    Keypair exists in EC2."
    Write-Output "    Deleting keypair: $keyPairName"
    Remove-EC2KeyPair -KeyName $keyPairName -Force
}
else {
    "    $keyPairName keypair does not exist in EC2. No need to delete it."
}

# Verifying keypair deleted
$keyPairExistsAfter = Test-KeyPair $keyPairName
if ($keyPairExistsBefore -and $keyPairExistsAfter) {
    Write-Error "    Failed to delete keypair: $keyPairName"
}
if ($keyPairExistsBefore -and -not $keyPairExistsAfter) {
    Write-Output "    Keypair successfully deleted."
}

$ErrorActionPreference = "Stop"  

# Importing helper functions
Import-Module -Name "$PSScriptRoot\helper_functions.psm1.psm1" -Force

$octopusAPIKey = ""
try {
    $octopusApiKey = $OctopusParameters["OCTOPUS_APIKEY"]
    Write-Output "    Found OCTOPUS_APIKEY from Octopus variables."
}
catch {
    Write-Output "    Failed to read variable OCTOPUS_APIKEY."
    Write-Output "      Will skip checks to see if competing runbookRuns are still running."
}

# Installiing the modules
Write-Output "    Installing AWS.Tools.Common."
Install-ModuleSafely -moduleName "AWS.Tools.Common" -octopusApiKey $octopusApiKey
Write-Output "    Installing AWS.Tools.EC2."
Install-ModuleSafely -moduleName "AWS.Tools.EC2" -octopusApiKey $octopusApiKey
Write-Output "    Installing AWS.Tools.IdentityManagement."
Install-ModuleSafely -moduleName "AWS.Tools.IdentityManagement" -octopusApiKey $octopusApiKey
Write-Output "    Installing AWS.Tools.SimpleSystemsManagement."
Install-ModuleSafely -moduleName "AWS.Tools.SimpleSystemsManagement" -octopusApiKey $octopusApiKey
Write-Output "    Installing AWS.Tools.SecretsManager."
Install-ModuleSafely -moduleName "AWS.Tools.SecretsManager" -octopusApiKey $octopusApiKey
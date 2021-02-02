param(
    $octoUrl = "",
    $octoApiKey = ""
)

$ErrorActionPreference = "Stop"

# Setting default values for parameters
$missingParams = @()

if ($octoUrl -like ""){
    try {
        $octoUrl = $OctopusParameters["Octopus.Web.ServerUri"]
        Write-Output "    Found value for octoUrl from Octopus variables: $octoUrl" 
    }
    catch {
        $missingParams = $missingParams + "-octoUrl"
    }
}

if ($octoApiKey -like ""){
    try {
        $octoApiKey = $OctopusParameters["OCTOPUS_APIKEY"]
        Write-Output "    Found value for octoApiKey from Octopus variables." 
    }
    catch {
        $missingParams = $missingParams + "-octoApiKey"
    }
}

if ($missingParams.Count -gt 0){
    $errorMessage = "Missing the following parameters: "
    foreach ($param in $missingParams) {
        $errorMessage += "$param, "
    }
    Write-Error $errorMessage
}

# API header for Octopus Deploy
$octoApiHeader = @{ "X-Octopus-ApiKey" = $octoApiKey }

# Finding all the environments
$environments = ((Invoke-WebRequest "$octoUrl/api/environments" -Headers $octoApiHeader -UseBasicParsing).content | ConvertFrom-Json).items

# Deleting all the VMs and tentacles
ForEach ($envName in $environments.Name) {
    Write-Output "  Executing $PSScriptRoot\kill_infra.ps1..."
    Write-Output "   Parameters: -octoEnvName $envName"
    & $PSScriptRoot\kill_infra.ps1 -octoEnvName $envName -octoUrl $octoUrl -octoApiKey $octoApiKey 
}

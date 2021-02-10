# Importing helper functions
Import-Module -Name "C:\Startup\scripts\userdata_helper_functions.psm1" -Force

# Download tentacle installer
Write-Output "    Downloading latest Octopus Tentacle MSI..."
$tentacleDownloadPath = "http://octopusdeploy.com/downloads/latest/OctopusTentacle64"
$tentaclePath = "C:\Startup.\Tentacle.msi"
if ((test-path $tentaclePath) -ne $true) {
  Download-File $tentacleDownloadPath $tentaclePath
}
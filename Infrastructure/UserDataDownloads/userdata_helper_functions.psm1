function Download-File 
{
  param (
    [string]$url,
    [string]$saveAs
  )
 
  Write-Output "    Downloading $url to $saveAs"
  $downloader = new-object System.Net.WebClient
  $downloader.DownloadFile($url, $saveAs)
}

# Function to securely retrieve secrets from AWS Secrets Manager
function get-secret(){
    param ($secret)
    $secretValue = Get-SECSecretValue -SecretId $secret
    # values are returned in format: {"key":"value"}
    $splitValue = $secretValue.SecretString -Split '"'
    $cleanedSecret = $splitValue[3]
    return $cleanedSecret
}

function Get-MyPublicIPAddress
{
  Write-Host "    Getting public IP address" # Important: Use Write-Host here, not Write-output!
  $downloader = new-object System.Net.WebClient
  $ip = $downloader.DownloadString("http://ifconfig.me/ip")
  return $ip
}
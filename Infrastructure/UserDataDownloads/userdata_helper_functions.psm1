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
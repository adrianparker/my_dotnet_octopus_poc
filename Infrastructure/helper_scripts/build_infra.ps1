param(
    $count = 1,
    $instanceType = "t2.micro", # 1 vCPU, 1GiB Mem, free tier elligible: https://aws.amazon.com/ec2/instance-types/
    $role = "RandomQuotes-WebServer",
    $tagValue = "Created manually",
    $octoUrl = "",
    $octoEnv = "",
    [Switch]$DeployTentacle,
    [Switch]$Wait
)

$ErrorActionPreference = "Stop"

################################################################
###                       PREPARATION                        ###
################################################################

# Importing helper functions
Import-Module -Name "$PSScriptRoot\helper_functions.psm1" -Force

# Getting the required instance ami for AWS region
$image = Get-SSMLatestEC2Image -ImageName Windows_Server-2019-English-Full-Bas* -Path ami-windows-latest | Where-Object {$_.Name -like "Windows_Server-2019-English-Full-Base"} | Select-Object Value
$ami = $image.Value
Write-Output "    Windows_Server-2019-English-Full-Base image in this AWS region has ami: $ami"

# Reading VM_UserData
$userDataPath = "$PSScriptRoot\VM_UserData.ps1"
if (-not (Test-Path $userDataPath)){
    Write-Error "No UserData (VM startup script) found at $userDataPath!"
}
$userData = Get-Content -Path $userDataPath -Raw

# If deploying the tentacle, preparing VM_UserData code accordingly
if ($DeployTentacle){
    Write-Output "    Updating UserData to auto-deploy the tentacle."
    # If deploying tentacle, uncomment the deploy tentacle script
    $userData = $userData.replace("<# DEPLOY TENTACLE"," ")
    $userData = $userData.replace("DEPLOY TENTACLE #>"," ")
    # Provide the octopus URL, environment and role
    $userData = $userData.replace("__OCTOPUSURL__",$octoUrl)
    $userData = $userData.replace("__ENV__",$octoEnv)
    $userData = $userData.replace("__ROLE__",$role)
}

# Base 64 encoding VM_UserData. More info here: 
# https://docs.aws.amazon.com/AWSEC2/latest/WindowsGuide/ec2-windows-user-data.html
Write-Output "    Base 64 encoding UserData."
$encodedUserData = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($userData))

# Retrieving th Octopus API Key from Octopus variables (only required if deploying tentacles)
if ($DeployTentacle){
    try {
        $APIKey = $OctopusParameters["OCTOPUS_APIKEY"]
    }
    catch {
        Write-Error 'Failed to read the Octopus API Key from $OctopusParameters["OCTOPUS_APIKEY"].'
    }
}

################################################################
###                    LANCHING INSTANCES                    ###
################################################################

Write-Output "    Launching $count instances of type $instanceType and ami $ami."
Write-Output "      Instances will each have tag $role with value $tagValue."

# Launching the instances
$NewInstances = New-EC2Instance -ImageId $ami -MinCount $totalRequired -MaxCount $totalRequired -InstanceType $instanceType -UserData $encodedUserData -KeyName RandomQuotes -SecurityGroup RandomQuotes -IamInstanceProfile_Name RandomQuotes

# Tagging all the instances
$NewInstanceIds = $NewInstances.InstanceId
ForEach ($InstanceID in $NewInstanceIds){
    New-EC2Tag -Resources $( $InstanceID ) -Tags @(
        @{ Key=$role; Value=$tagValue}
    );
}

################################################################
###             VERIFYING INSTANCES ARE RUNNING              ###
################################################################

# Checking if it worked
Write-Output "    Verifying that all instances have been/are being created:"

ForEach ($id in $NewInstanceIds){
    $status = Get-EC2InstanceStatus -InstanceId $id
    $instanceStateName = $status.InstanceState.Name
    Write-Output "      Instance $id is in state $instanceStateName"
}

Write-Output "    Waiting for instances to start. (This normally takes about 30 seconds.)"
$NewRunningInstances = @{}
$timeout = 120 # seconds
$stopwatch =  [system.diagnostics.stopwatch]::StartNew()

While ($NewRunningInstances.count -lt $count){
    # Getting the IDs of all pending instances
    $pendingIds = $NewInstanceIds | Where-Object {$_ -notin $NewRunningInstances.Keys}   
    
    # Checking to see if they are running yet
    ForEach ($id in $pendingIds){
        $instanceStateName = (Get-EC2InstanceStatus -InstanceId $id).InstanceState.Name.Value
        if ($instanceStateName -like "runnning"){
            $ip = (Get-EC2Instance -InstanceId $id).Instances.PublicIpAddress
            $NewRunningInstances.add($id,$ip)
            Write-Output "        Instance $id is running. IP address is: $ip"
        }
    }
    
    # Logging
    $numRunning = $NewRunningInstances.count
    if ($numRunning -eq $count){
        Write-Output "    $time seconds: All instances are running!"
        break
    }
    else {
        Write-Output "      $time seconds: $numRunning out of $count instances are running."
    }

    # Short hold, then try again
    $time = [Math]::Floor([decimal]($stopwatch.Elapsed.TotalSeconds))
    if ($time -gt $timeout){
        Write-Error "Timed out at $time seconds."
    }
    Start-Sleep -s 5
}

################################################################
###         VERIFYING IIS AND TENTACLE REGISTRATION          ###
################################################################

$logMsg = "    Waiting for IIS to start on new instance(s). Normally 3-5 mins."
if ($deployTentacle){
    $logMsg = "    Waiting for IIS setup and Tentacle registration. Normally 7-10 mins."
}
Write-Output $logMsg

$ipAddresses = $NewRunningInstances.Values
$iisInstalls = @()
$tentaclesRegistered = @()
$timeout = 1200 # seconds
$stopwatch.Restart()
$complete = $false

while (-not $complete){
    # Check IIS
    $pendingIisInstalls = $ipAddresses | Where-Object {$_ -notin $iisInstalls}
    foreach ($ip in $pendingIisInstalls){
        if (Test-IIS -ip $ip){
            $iisInstalls += $ip
            Write-Output "        IIS is running on $ip"
        }
    }
    
    # Check Tentacles (if $deployTentacle)
    if ($deployTentacle){
        $pendingTentacles = $ipAddresses | Where-Object {$_ -notin $tentaclesRegistered}
        foreach ($ip in $pendingTentacles){
            if (Test-Tentacle -ip $ip -OctopusUrl $octoUrl -APIKey $APIKey){
                $tentaclesRegistered += $ip
                Write-Output "        Tentacle is listening on $ip"
                Write-Output "          Updating Calamari on $ip"
                # Update-Calamari function is in ./helperfunctions.psm1
                Update-Calimari -ip $ip -OctopusUrl $octoUrl -APIKey $APIKey
            }
        }
    }

    # If finished, break the loop
    if ($deployTentacle){
        if ($tentaclesRegistered.count -eq $count){
            $complete = $true
            Write-Output "SUCCESS! All instances are running."
            break
        }
    }
    else {
        if ($iisInstalls.count -eq $count){
            $complete = $true
            Write-Output "SUCCESS! All instances are running."
            break
        }
    }
    
    # Seems we don't yet have all of our machines: Let's wait 30s and try again
    $time = [Math]::Floor([decimal]($stopwatch.Elapsed.TotalSeconds))
    $numIis = $iisInstalls.count
    $numTentacles = $tentaclesRegistered.count
    if ($deployTentacle){
        $msg = "      $time seconds: $numIis / $count instances have configured IIS"
    }
    else {
        $msg = "      $time seconds: $numIis / $count IIS installs and $numTentacles / $count tentacles are ready."
    }
    Write-Output $msg
    
    # If we've been waiting too long, time out
    if ($time -gt $timeout){
        Write-Error "Timed out at $time seconds. Timeout currently set to $timeout seconds. There is a parameter on this script to adjust the default timeout."
    }

    Start-Sleep -s 15
}
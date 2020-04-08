param(
    [parameter()]
    # [string] $VMName,
    [string] $ec2Instance,
    [parameter()]
    # [string] $gceManageInt = 'nic0',
    [string] $ec2ManagementInt = 'Primary network interface',
    [parameter()]
    [string] $k2host = '10.202.2.33',
    [parameter()]
    [int] $lunCount = 6,
    [parameter()]
    [int] $lunSizeInGB = 40,
    [parameter()]
    [ValidateSet('Linux','Windows',IgnoreCase = $false)]
    [string] $OS = "Linux",
    [parameter()]
    [switch] $disableDeduplication,
    [parameter()]
    [System.Management.Automation.PSCredential] $K2credentials
)

if (!$K2credentials) {
    $K2credentials = Import-Clixml .\admin.xml
    $K2credentials
}

# OMG ALL THESE FUNCTIONS!

function PrepVolumes {
# Ask for: Host, volume size, number of, volume group
    param(
        [parameter(Mandatory)]
        [string] $hostName,
        [parameter(Mandatory)]
        [ValidateSet('Linux','Windows','ESX',IgnoreCase = $false)]
        [string] $hostType,
        [parameter(Mandatory)]
        [int] $sizeInGB,
        [parameter()]
        [int] $numberOfVolumes = 1,
        [parameter()]
        [switch] $disableDeduplication
    )

    $returnarray = @()

    # query for host and create if non exist
    if (!(Get-K2Host -name $hostName -WarningAction silentlycontinue)) {
        $newhost = New-K2Host -Name $hostName -Type $hostType 
    } else {
        $newhost = Get-K2Host -name $hostName
    }

    # Create Volume Groups

    $volumeGroup = $hostName + '_volgrp-DD' 
    if (!(Get-K2VolumeGroup -Name $volumeGroup -WarningAction silentlycontinue)) {
        if ($disableDeDuplication) {
            $volumeGroup = $volumeGroup.Replace('-DD',$null)
            $newvolgroup = New-K2VolumeGroup -Name $volumeGroup -DisableDeduplication
        } else {
            $newvolgroup = New-K2VolumeGroup -Name $volumeGroup 
        }
    }

    # Tally the existing volumes for $start var

    if (Get-K2Volume | Where-Object {$_.name -match $VMName}) {
        $start = (Get-K2Volume | where-object {$_.name -match $VMName}).count
        $numberOfVolumes = $numberOfVolumes + $start
        $start++
    } else {
        $start = 1
    }

    while ($start -le $numberOfVolumes) {
        $volName = $hostName + '-' + $start
        if (Get-K2Volume -name $volName -WarningAction silentlycontinue) {
            Write-Verbose "-- $volname  already existing, trying next"
            $numberOfVolumes++
            $start++
            Continue
            start-sleep -Seconds 1
        }
        Write-Verbose "-- Creating $volName"
        $newvol = New-K2Volume -VolumeGroup $volumeGroup -Name $volName -SizeGB $sizeInGB
        $start++
        $o = new-object psobject
        $o | Add-Member -MemberType NoteProperty -Name 'VolumeName' -Value $newvol.name
        $o | Add-Member -MemberType NoteProperty -Name 'VolumeID' -Value $newvol.id
        $o | Add-Member -MemberType NoteProperty -Name 'HostName' -Value $newhost.name
        $o | Add-Member -MemberType NoteProperty -Name 'HostID' -Value $newhost.id
        $o | Add-Member -MemberType NoteProperty -Name 'VolumeGroupName' -Value $newvolgroup.name
        $o | Add-Member -MemberType NoteProperty -Name 'VolumeGroupID' -Value $newvolgroup.id
        $returnarray += $o
    }

    return $returnarray

}

function New-MenuFromArray {
    param(
        [Parameter(Mandatory)]
        [array]$array,
        [Parameter(Mandatory)]
        [string]$property,
        [Parameter()]
        [string]$message = "Select item"
    )
    <#
    .SYNOPSIS

    Creates a text menu based on an array as provided. 

    .EXAMPLE

    $filearray = Get-ChildItem | Where-Object {!$_.PSIsContainer}
    $selectedfile = Build-MenuFromArray -array $filearray -property "name" -message "Select file from the list"

    #>

    Write-Host '------'
    $menuarray = @()
        foreach ($i in $array) {
            $o = New-Object psobject
            $o | Add-Member -MemberType NoteProperty -Name $property -Value $i.$property
            $menuarray += $o
        }
    $menu = @{}
    for (
        $i=1
        $i -le $menuarray.count
        $i++
    ) { Write-Host "$i. $($menuarray[$i-1].$property)" 
        $menu.Add($i,($menuarray[$i-1].$property))
    }
    Write-Host '------'
    [int]$mntselect = Read-Host $message
    $menu.Item($mntselect)
    Write-Host `n`n
}

function New-K2HostMapping {
    param(
        [parameter(Mandatory)]
        [string] $hostID,
        [parameter(Mandatory)]
        [string] $volumeID
    )

    $hoststring = '/hosts/' + $hostID
    $volumestring = '/volumes/' + $volumeID

    $hostArray = New-Object psobject
    $hostArray | Add-Member -MemberType NoteProperty -Name 'ref' -Value $hoststring

    $volumeArray = New-Object psobject
    $volumeArray | Add-Member -MemberType NoteProperty -Name 'ref' -Value $volumestring

    
    $o = new-object psobject
    $o | Add-Member -MemberType NoteProperty -Name 'host' -Value $hostarray
    $o | Add-Member -MemberType NoteProperty -Name 'volume' -Value $volumeArray

    return $o | ConvertTo-Json -Depth 10
}

function Unblock-CertificatePolicy {
      
if ([System.Net.ServicePointManager]::CertificatePolicy -notlike 'TrustAllCertsPolicy') {
    Add-Type -TypeDefinition @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
    [System.Net.ServicePointManager]::CertificatePolicy = New-Object -TypeName TrustAllCertsPolicy
}
}

function Invoke-K2RESTCall {
    param(
        [parameter(Mandatory)]
        [string] $URI,
        [parameter(Mandatory)]
        [ValidateSet('GET','POST','PATCH','DELETE')]
        [string] $method,
        [parameter()]
        [array] $body,
        [parameter(Mandatory)]
        [System.Management.Automation.PSCredential] $credentials
    )

    $endpointURI = $URI

    # Make the call. 
    if ($PSVersionTable.PSEdition -eq 'Core') {
        if ($body) {
            $results = Invoke-RestMethod -Method $method -Uri $endpointURI -Body $body -Credential $credentials -SkipCertificateCheck -ContentType 'application/json' 
        } else {
            $results = Invoke-RestMethod -Method $method -Uri $endpointURI -Credential $credentials -SkipCertificateCheck
        }
    } elseif ($PSVersionTable.PSEdition -eq 'Desktop') {
        if ([System.Net.ServicePointManager]::CertificatePolicy -notlike 'TrustAllCertsPolicy') { 
            Write-Verbose "Correcting certificate policy"
            Unblock-CertificatePolicy
        }
        if ([Net.ServicePointManager]::SecurityProtocol -notmatch 'Tls12') {
            [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol + 'Tls12'
        }
        if ($body) {
            $results = Invoke-RestMethod -Method $method -Uri $endpointURI -Body $body -Credential $credentials -ContentType 'application/json' 
        } else {
            $results = Invoke-RestMethod -Method $method -Uri $endpointURI -Credential $credentials 
        }
    }

    return $results
}

function Get-WinRMiqn {
    param(
        [parameter(Mandatory)]
        [string] $hostname,
        [parameter(Mandatory)]
        [System.Management.Automation.PSCredential] $credentials
    )
    Add-WinrRMTrustedHost -trustedHost $hostname | Out-Null
    return Invoke-Command -ComputerName $hostname -Credential $credentials -ScriptBlock {(Get-InitiatorPort | Where-Object {$_.instancename}).nodeaddress}
}


function Invoke-WinRMRescan {
    param(
        [parameter(Mandatory)]
        [string] $hostname,
        [parameter(Mandatory)]
        [System.Management.Automation.PSCredential] $credentials,
        [parameter(Mandatory)]
        [string] $k2instance
    )
    Add-WinrRMTrustedHost -trustedHost $hostname
    Invoke-Command -ComputerName $hostname -Credential $credentials -ScriptBlock {Update-IscsiTarget -InitiatorPort (Get-InitiatorPort | Where-Object {$_.instancename})}
}

function New-K2HostIqn {
    param(
        [parameter(Mandatory)]
        [string] $hostname,
        [parameter(Mandatory)]
        [string] $iqn
    )

    $k2hostinfo = Get-K2Host -Name $hostname
    $hostprefix = '/hosts/' + $k2hostinfo.id

    $r = New-Object psobject
    $r | Add-Member -MemberType NoteProperty -Name 'ref' -Value $hostprefix

    $o = New-Object psobject
    $o | Add-Member -MemberType NoteProperty -Name 'iqn' -Value $iqn
    $o | Add-Member -MemberType NoteProperty -Name 'host' -Value $r

    return $o | ConvertTo-Json -Depth 10
}

function Add-WinrRMTrustedHost {
    param(
        [parameter(Mandatory)]
        [string] $trustedHost
    )
    
    [array]$thosts = (winrm get winrm/config/client | Where-Object {$_ -match 'TrustedHosts'}).replace('TrustedHosts =',$null).trim().split(',')
    if ($thosts) {
        $thosts += $trustedHost
    }
    $thoststring = ($thosts -join ",")
    $fullstring = "winrm set winrm/config/client '@{TrustedHosts=" + '"' + $thoststring + '"' + '}' + "'"
    Invoke-Expression -Command $fullstring
}

# ----------------------------
#       Heavy lifting
# ----------------------------

# Connect to the storage array 
Write-Output "--- Connecting to K2 array at $k2host ---"
try {
    Connect-K2Array -K2Array $k2host -Username $K2credentials.UserName -Password $K2credentials.GetNetworkCredential().password
} catch {
    return Cannot connect to $k2host
}

## Get the IP information of the compute instances. 

if (!$ec2Instance) {
    try {
        $array = Get-ec2instance
    } catch {
        Return Cannot connect to Google Cloud. Please check gcloud init settings
    }
    $ec2Instance = New-MenuFromArray -array $array -property name -message "Select GCP compute host to provision"
}

Write-Output "--- Selected $ec2Instance as AWS VM ---"

try {
    # $cVM = Get-GceInstance -Name $VMName
    $cVM = Get-EC2Instance -InstanceId $ec2Instance
} catch {
    Return "!! Cannot locate the GCE VM instance named $VMName"
}
$managementIP = ($cVM.Instances.networkinterfaces | Where-Object {$_.description -match $ec2ManagementInt})[0].privateipaddress

$VMName = ($cVM.RunningInstance.tags | where-object {$_.key -eq 'Name'}).value

if (!$managementIP) {
    return "No IP address for interface $ec2ManagementInt"
}

# Get iSCSI port IPs

Write-Output "--- Grabbing the iSCSI ports for $k2host ---"

$endpointURI = 'https://' + $k2host + '/api/v2/system/iscsi_ports'
$k2iSCSIPorts = Invoke-K2RESTCall -URI $endpointURI -method GET -credentials $K2credentials

Write-Output "--- Discovered iSCSI ports: ---"
Write-Output $k2iSCSIPorts.hits.ip_address

# Scan the host to present iqns to the K2

Write-Output "--- Scanning host $VMName at $managementIP for target $iscsi, this may take a while ---"

$iscsi = $k2iSCSIPorts.hits[0].ip_address
if ($OS -eq 'Linux') {
    # Invoke-SSHRescan -hostname $managementIP -credentials $VMCredentials -k2instance $iscsi
    $userhoststring = 'centos@' + $managementIP
    $discoverycmd = "sudo iscsiadm -m discovery -t sendtargets -p '" + $iscsi + ":3260' -o delete -o new"
    .\plink.exe -i .\PSKeyPairAPP.ppk $userhoststring -batch $discoverycmd
    Start-Sleep -Seconds 3
    $discoverycmd = "sudo iscsiadm -m node --login"
    .\plink.exe -i .\PSKeyPairAPP.ppk $userhoststring -batch $discoverycmd
} elseif ($OS -eq 'Windows') {
    Invoke-WinRMRescan -hostname $managementIP -credentials $VMCredentials -k2instance $iscsi
}

# Gather the iqns

if ($OS -eq "Linux") {
    # $iqnlist = Get-SSHiqn -hostname $managementIP -credentials $VMCredentials
    $discoverycmd = "cat /etc/iscsi/initiatorname.iscsi"
    $iqnlist = .\plink.exe -i .\PSKeyPairAPP.ppk $userhoststring -batch $discoverycmd
    $iqnlist = $iqnlist.Replace('InitiatorName=',$null)
} elseif ($OS -eq 'Windows') {
    $iqnlist = Get-WinRMiqn -hostname $managementIP -credentials $VMCredentials
}

if (!$iqnlist) {
    Return No iqn output was generated. Please check host configuration. 
} 



Write-Output "--- Discovered the following iqns ---"
Write-Output $iqnlist

# Create the volumes

Write-Output "--- Creating $lunCount volumes at $lunSizeInGB GB in size ---"

if ($disableDeduplication) {
    $volPrep = PrepVolumes -hostName $VMName -hostType $OS -sizeInGB $lunSizeInGB -numberOfVolumes $lunCount -disableDeduplication
} else {
    $volPrep = PrepVolumes -hostName $VMName -hostType $OS -sizeInGB $lunSizeInGB -numberOfVolumes $lunCount
}


# associate the iqns with the host

Write-Output "--- Associating iqn with $VMName ---"

$endpointURI = 'https://' + $k2host + '/api/v2/host_iqns'
$ciqns = (Invoke-K2RESTCall -URI $endpointURI -method GET -credentials $K2credentials).hits
$hostprefix = '/hosts/' + $volPrep[0].hostid


foreach ($i in $iqnlist) {
    if (!($ciqns | Where-Object {$_.iqn -eq $i}).host.ref) {
        $endpointURI = 'https://' + $k2host + '/api/v2/host_iqns'
        $body = New-K2HostIqn -hostname $VMName -iqn $i
        Invoke-K2RESTCall -URI $endpointURI -method POST -body $body -credentials $K2credentials
    }
}


# Map the volumes to the host

Write-Output "--- Mapping the new luns to host $VMName ---"

foreach ($i in $volPrep) {
    $endpointURI = 'https://' + $k2host + '/api/v2/mappings'
    $body = New-K2HostMapping -hostID $i.HostID -volumeID $i.VolumeID
    Invoke-K2RESTCall -URI $endpointURI -method POST -body $body -credentials $K2credentials
}

# Rescan the host to see the volumes. 

Write-Output "--- Finalizing the LUN scans on $VMName ---"

$iscsi = $k2iSCSIPorts.hits[0].ip_address
if ($OS -eq 'Linux') {
    # Invoke-SSHRescan -hostname $managementIP -credentials $VMCredentials -k2instance $iscsi
    $userhoststring = 'centos@' + $managementIP
    $discoverycmd = "sudo iscsiadm -m discovery -t sendtargets -p '" + $iscsi + ":3260'"
    .\plink.exe -i .\PSKeyPairAPP.ppk $userhoststring -batch $discoverycmd
    Start-Sleep -Seconds 3
    $discoverycmd = "sudo iscsiadm -m node --login"
    .\plink.exe -i .\PSKeyPairAPP.ppk $userhoststring -batch $discoverycmd
    $discoverycmd = "sudo rescan-scsi-bus.sh"
    .\plink.exe -i .\PSKeyPairAPP.ppk $userhoststring -batch $discoverycmd
} elseif ($OS -eq 'Windows') {
    Invoke-WinRMRescan -hostname $managementIP -credentials $VMCredentials -k2instance $iscsi
}

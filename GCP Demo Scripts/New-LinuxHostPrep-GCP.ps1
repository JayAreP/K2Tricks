param(
    [parameter(mandatory)]
    [string] $name,
    [parameter(mandatory)]
    [int] $sizeInGB,
    [parameter(mandatory)]
    [int] $numberOfVolumes
)

function getiqn {
    param(
        [string] $gceInstance,
        [string] $keyFile
    )

    try {
        $cVM = Get-GceInstance -Name $gceInstance
    } catch {
        Return "!! Cannot locate the GCE VM instance named $gceInstance" | Write-Error
    }
    $managementIP = ($cVM.NetworkInterfaces | where-object {$_.name -eq 'nic0'}).NetworkIP

    $userhoststring = 'jr_phillips_personal@' + $managementIP
    $discoverycmd = "sudo /var/local/deploy/newSystem.sh"
    $response = ssh.exe -i $keyFile $userhoststring -o "StrictHostKeyChecking no" $discoverycmd
    return $response.Split('=')[-1]
}

# Get the iqn
$iqn = getiqn -gceInstance $name -keyFile .\jr_phillips_personal

# Create the host
Write-Host "Creating Host object -> $name"
New-SDPHost -name $name -type Linux

# Create the volume group
$vgname = $name + '-vg'
Write-Host "Creating Volume Group object -> $vgname"
New-SDPVolumeGroup -name $vgname

# Create the volumes
$number = 1
while ($number -le $numberOfVolumes) {
    $volname = $name + '-vol-' + $number
    Write-Host "Creating Volume object -> $volname"
    New-SDPVolume -VolumeGroupName $vgname -sizeInGB $sizeInGB -name $volname
    Write-Host "Mapping to host -> $name"
    New-SDPHostMapping -volumeName $volname -hostName $name
    $number++
}

# Add host connection information
if ($iqn) {Set-SDPHostIqn -iqn $iqn -hostName $name}

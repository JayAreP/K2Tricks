# Example Script for automated deployment of volumes using the SDP module. 

param(
    [parameter(mandatory)]
    [string] $name,
    [parameter(mandatory)]
    [int] $sizeInGB,
    [parameter(mandatory)]
    [int] $numberOfVolumes
)

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
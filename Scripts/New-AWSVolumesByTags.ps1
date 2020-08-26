param(
    [parameter(Mandatory)]
    [string] $instanceID
)

Function New-HostPrep {

    param(
        [parameter(mandatory)]
        [string] $name,
        [parameter(mandatory)]
        [int] $sizeInGB,
        [parameter(mandatory)]
        [int] $numberOfVolumes,
        [parameter(Mandatory)]
        [ValidateSet('Linux','Windows','ESX',IgnoreCase = $false)]
        [string] $type,
        [parameter()]
        [string] $iqn,
        [parameter()]
        [string] $pwwn
    )

    New-SDPHost -name $name -type $type

    $vgname = $name + '-vg'
    New-SDPVolumeGroup -name $vgname

    $number = 1
    while ($number -le $numberOfVolumes) {
        $volname = $name + '-vol-' + $number
        New-SDPVolume -VolumeGroupName $vgname -sizeInGB $sizeInGB -name $volname
        New-SDPHostMapping -volumeName $volname -hostName $name
        $number++
    }

    if ($iqn) {Set-SDPHostIqn -iqn $iqn -hostName $name}
    if ($pwwn) {Set-SDPHostPwwn -pwwn $pwwn -hostName $name}

}


$tags = (Get-EC2Instance -InstanceId $instanceID).instances.tag
$o = New-Object psobject
foreach ($i in $tags) {
    $o | add-member -MemberType NoteProperty -Name $i.Key -Value $i.value
}

if ($o.numVols) {
    New-HostPrep -name $o.name -sizeInGB $o.volSizeInGB -numberOfVolumes $o.numVols -type $o.provisionOS
}

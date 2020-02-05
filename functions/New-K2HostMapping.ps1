function New-K2HostMapping {
    param(
        [parameter(Mandatory)]
        [string] $hostID,
        [parameter(Mandatory)]
        [string] $volumeGroupID
    )

    $hoststring = '/hosts/' + $hostID
    $volumestring = '/volume_groups/' + $volumeID

    $hostArray = New-Object psobject
    $hostArray | Add-Member -MemberType NoteProperty -Name 'ref' -Value $hoststring

    $volumeArray = New-Object psobject
    $volumeArray | Add-Member -MemberType NoteProperty -Name 'ref' -Value $volumestring

    
    $o = new-object psobject
    $o | Add-Member -MemberType NoteProperty -Name 'host' -Value $hostarray
    $o | Add-Member -MemberType NoteProperty -Name 'volume' -Value $volumeArray

    return $o | ConvertTo-Json -Depth 10
}
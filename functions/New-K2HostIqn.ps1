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
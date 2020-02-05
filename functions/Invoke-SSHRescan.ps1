function Invoke-SSHRescan {
    param(
        [parameter(Mandatory)]
        [string] $hostname,
        [parameter(Mandatory)]
        [System.Management.Automation.PSCredential] $credentials,
        [parameter(Mandatory)]
        [string] $k2instance
    )
    if (!(Get-SSHSession -HostName $hostname)) {
        $sshsesh = New-SSHSession -ComputerName $hostname -Credential $credentials -AcceptKey
    } else {
        $sshsesh = (Get-SSHSession -HostName $hostname)[0]
    }

    $discoverycmd = "iscsiadm -m discovery -t sendtargets -p '" + $k2instance + ":3260'"
    $request = Invoke-SSHCommand -Command $discoverycmd -SessionId $sshsesh.sessionId

    return $request
}
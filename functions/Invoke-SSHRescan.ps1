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

    $discoverycmd = "sudo iscsiadm -m discovery -t sendtargets -p '" + $k2instance + ":3260'"
    Invoke-SSHCommand -Command $discoverycmd -SessionId $sshsesh.sessionId
    $discoverycmd = "sudo iscsiadm -m node --login &"
    Invoke-SSHCommand -Command $discoverycmd -SessionId $sshsesh.sessionId
    $discoverycmd = "sudo iscsiadm --mode session --op show"
    $request = Invoke-SSHCommand -Command $discoverycmd -SessionId $sshsesh.sessionId
    $discoverycmd = "ls /dev/disk/by-path/ | grep  " + $k2instance
    Invoke-SSHCommand -Command $discoverycmd -SessionId $sshsesh.sessionId

    return $request.output
}
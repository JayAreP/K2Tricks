function Get-SSHiqn {
    param(
        [parameter(Mandatory)]
        [string] $hostname,
        [parameter(Mandatory)]
        [System.Management.Automation.PSCredential] $credentials
    )
    if (!(Get-SSHSession -HostName $hostname)) {
        $sshsesh = New-SSHSession -ComputerName $hostname -Credential $credentials -AcceptKey
    } else {
        $sshsesh = (Get-SSHSession -HostName $hostname)[0]
    }

    $discoverycmd = "cat /etc/iscsi/initiatorname.iscsi"
    $request = Invoke-SSHCommand -Command $discoverycmd -SessionId $sshsesh.sessionId
    $inits = $request.output | where-object {$_ -match 'InitiatorName'}
    $results = @()
    foreach ($i in $inits) {
        $results += $i.replace('InitiatorName=',$null).trimend()
    }
    return $results
}
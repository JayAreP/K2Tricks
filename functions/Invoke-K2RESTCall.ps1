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
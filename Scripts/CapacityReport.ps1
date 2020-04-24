
# K2 Paramters
# You can generate a secure credential file for powershell like so:
# get-credential | export-clixml .\admin.xml
$k2 = "172.16.10.10"
$credfile = .\admin.xml

# FileServerParameters
$fileshare = '\\server\share\folder'


# Functions
function ConvertTo-GBString {
    param(
        [int64] $inputInt,
        [int] $roundDecimal = 2
    )
    $gb = ($inputInt / 1gb)
    $gbrounded = [math]::Round($gb,$roundDecimal)
    $gbstring = $gbrounded.tostring() + ' GB'
    return $gbstring
}

Function Get-K2SystemCapacity {
    param(
        [string] $k2,
        [System.Management.Automation.PSCredential] $credentials
    )
    $endpointURI = 'https://' + $k2 + '/api/v2/system/capacity'
    $response = Invoke-RestMethod -Method GET -URI $endpointURI -Credential $credentials 
    return $response.hits
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

# -----------------
# - Heavy Lifting -
# -----------------
 
Unblock-CertificatePolicy

# Create the credential object

$creds = Import-Clixml $credfile

# Generate the capacity statistics

$capacity = Get-K2SystemCapacity -k2 $k2 -credentials $creds
$captable = @{}
$caplist = ($capacity | Get-Member -MemberType NoteProperty | select-object name).name
foreach ($i in $caplist) {
    if ($capacity.$i -as [int64]) {
        $obstring = convertto-gbstring -inputInt $capacity.$i
    } else {
        continue
    }
    $captable.add($i,$obstring)
}

$captable.remove('id')

$date = get-date -Format s

# Deposite the file
$filename = 'K2-' + $k2.replace('.','-') + '-' + $date.Replace(':','-').trim() + '.csv'
$fullpath = $fileshare + '\' + $filename
$captable | Export-Csv -NoTypeInformation -Path 
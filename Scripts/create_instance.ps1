param(
    [parameter(Mandatory)]
    [string] $name
)

$name = $name.ToLower()

## Build nested objects:
# Display
$displayDevice = New-Object PSObject
$displayDevice | Add-Member -MemberType NoteProperty -Name "enableDisplay" -Value $false

# metadata
$metadata = New-Object PSObject
$metadata | Add-Member -MemberType NoteProperty -Name "kind" -Value 'compute#metadata'
$metadata | Add-Member -MemberType NoteProperty -Name "items" -Value @()

# tags
$tags = New-Object PSObject
$tags | Add-Member -MemberType NoteProperty -Name "items" -Value @()

# disks
$diskchild = New-Object PSObject
$diskchild | Add-Member -MemberType NoteProperty -Name "kind" -Value 'compute#attachedDisk'
$diskchild | Add-Member -MemberType NoteProperty -Name "type" -Value 'PERSISTENT'
$diskchild | Add-Member -MemberType NoteProperty -Name "boot" -Value $true
$diskchild | Add-Member -MemberType NoteProperty -Name "mode" -Value 'READ_WRITE'
$diskchild | Add-Member -MemberType NoteProperty -Name "autoDelete" -Value $true
$diskchild | Add-Member -MemberType NoteProperty -Name "deviceName" -Value $name
$initializeParams = New-Object PSObject
$initializeParams | Add-Member -MemberType NoteProperty -Name "sourceImage" -Value "projects/k2c-app-demo/global/images/app-template-5-22-2020"
$initializeParams | Add-Member -MemberType NoteProperty -Name "diskType" -Value "projects/k2c-app-demo/zones/us-central1-f/diskTypes/pd-standard"
$initializeParams | Add-Member -MemberType NoteProperty -Name "diskSizeGb" -Value "10"
$diskchild | Add-Member -MemberType NoteProperty -Name "initializeParams" -Value $initializeParams
# $diskchild | Add-Member -MemberType NoteProperty -Name "diskEncryptionKey" -Value @()

# networkInterfaces
$interfaceList =@('default','data-k2c-application-subnet')
$networkInterfaces = @()
foreach ($n in $interfaceList) {
    $kindType = 'projects/k2c-app-demo/regions/us-central1/subnetworks/' + $n
    $i = New-Object psobject
    $i | Add-Member -MemberType NoteProperty -Name 'kind' -Value 'compute#networkInterface'
    $i | Add-Member -MemberType NoteProperty -Name 'subnetwork' -Value $kindType
    $i | Add-Member -MemberType NoteProperty -Name 'aliasIpRanges' -Value @()
    $networkInterfaces += $i
}

# scheduling
$scheduling = New-Object PSObject
$scheduling | Add-Member -MemberType NoteProperty -Name "preemptible" -Value $False
$scheduling | Add-Member -MemberType NoteProperty -Name "onHostMaintenance" -Value 'MIGRATE'
$scheduling | Add-Member -MemberType NoteProperty -Name "automaticRestart" -Value $true
$scheduling | Add-Member -MemberType NoteProperty -Name "nodeAffinities" -Value @()

# reservationAffinity
$reservationAffinity = New-Object PSObject
$reservationAffinity | Add-Member -MemberType NoteProperty -Name "consumeReservationType" -Value 'ANY_RESERVATION'

# serviceAccounts
$serviceAccountsScopes = @(
    'https://www.googleapis.com/auth/devstorage.read_only',
    'https://www.googleapis.com/auth/logging.write',
    'https://www.googleapis.com/auth/monitoring.write',
    'https://www.googleapis.com/auth/servicecontrol',
    'https://www.googleapis.com/auth/service.management.readonly',
    'https://www.googleapis.com/auth/trace.append'
)
$serviceAccounts = New-Object PSObject
$serviceAccounts | Add-Member -MemberType NoteProperty -Name "email" -Value '983328183414-compute@developer.gserviceaccount.com'
$serviceAccounts | Add-Member -MemberType NoteProperty -Name "scopes" -Value $serviceAccountsScopes

## Object Build

$o = New-Object psobject
$o | Add-Member -MemberType NoteProperty -Name "kind" -Value 'compute#instance'
$o | Add-Member -MemberType NoteProperty -Name "name" -Value $name
$o | Add-Member -MemberType NoteProperty -Name "zone" -Value "projects/k2c-app-demo/zones/us-central1-f"
$o | Add-Member -MemberType NoteProperty -Name "machineType" -Value "projects/k2c-app-demo/zones/us-central1-f/machineTypes/c2-standard-30"
$o | Add-Member -MemberType NoteProperty -Name "displayDevice" -Value $displayDevice
$o | Add-Member -MemberType NoteProperty -Name "metadata" -Value $metadata
$o | Add-Member -MemberType NoteProperty -Name "tags" -Value $tags
$o | Add-Member -MemberType NoteProperty -Name "disks" -Value @($diskchild)
$o | Add-Member -MemberType NoteProperty -Name "canIpForward" -Value $False
$o | Add-Member -MemberType NoteProperty -Name "networkInterfaces" -Value @($networkInterfaces)
$o | Add-Member -MemberType NoteProperty -Name "description" -Value '""'
# $o | Add-Member -MemberType NoteProperty -Name "labels" -Value @()
$o | Add-Member -MemberType NoteProperty -Name "scheduling" -Value $scheduling
$o | Add-Member -MemberType NoteProperty -Name "deletionProtection" -Value $False
$o | Add-Member -MemberType NoteProperty -Name "reservationAffinity" -Value $reservationAffinity
$o | Add-Member -MemberType NoteProperty -Name "serviceAccounts" -Value @($serviceAccounts)

$endpointURI = 'https://www.googleapis.com/compute/v1/projects/k2c-app-demo/zones/us-central1-f/instances'

$cred = gcloud auth print-access-token
$headers = @{ Authorization = "Bearer $cred" }

$bodyjson = $o | ConvertTo-Json -Depth 10

Invoke-RestMethod -Method Post -Uri $endpointURI.ToLower() -Body $bodyjson -Headers $headers -ContentType: "application/json; charset=utf-8"
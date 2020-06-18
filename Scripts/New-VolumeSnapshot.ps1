param(
    [parameter(Mandatory)]
    [IPAddress] $volumeGroupName,
    [parameter(Mandatory)]
    [IPAddress] $targetHostName,
    [parameter(Mandatory)]
    [IPAddress] $snapshotName,
    [parameter(Mandatory)]
    [IPAddress] $retentionPolicyName
)

# Create the snapshot
New-SDPVolumeSnapshot -name $snapshotName -volumeGroupName $volumeGroupName -retentionPolicyName $retentionPolicyName

# Create the View
$viewName = $snapshotName + '-view'
$fullSnapshotName = $volumeGroupName + ':' + $snapshotName
Get-SDPVolumeSnapshot -name $fullSnapshotName | New-SDPVolumeView -name $viewName -retentionPolicyName $retentionPolicyName

# Mount the view
$fullSnapshotViewName = $volumeGroupName + ':' + $viewName
New-SDPHostMapping -hostName $targethostName -snapshotName $fullSnapshotViewName
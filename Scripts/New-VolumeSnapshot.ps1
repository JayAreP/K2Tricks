param(
    [parameter(Mandatory)]
    [string] $volumeGroupName,
    [parameter(Mandatory)]
    [string] $targetHostName,
    [parameter(Mandatory)]
    [string] $snapshotName,
    [parameter(Mandatory)]
    [string] $retentionPolicyName
)

# Create the snapshot
New-SDPVolumeGroupSnapshot -name $snapshotName -volumeGroupName $volumeGroupName -retentionPolicyName $retentionPolicyName

# Create the View
$viewName = $snapshotName + '-view'
$fullSnapshotName = $volumeGroupName + ':' + $snapshotName
Get-SDPVolumeGroupSnapshot -name $fullSnapshotName | New-SDPVolumeView -name $viewName -retentionPolicyName $retentionPolicyName

# Mount the view
$fullSnapshotViewName = $volumeGroupName + ':' + $viewName
New-SDPHostMapping -hostName $targethostName -snapshotName $fullSnapshotViewName

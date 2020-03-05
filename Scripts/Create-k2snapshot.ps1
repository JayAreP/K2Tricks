param(
    [parameter()]
    [string] $volumeGroup,
    [parameter()]
    [string] $volumeName,
    [parameter()]
    [string] $hostGroup,
    [parameter()]
    [string] $hostName,
    [parameter(Mandatory)]
    [string] $retentionPolicy,
    [parameter(Mandatory)]
    [string] $snapshotName
)

# Delcare a name for the snapshot view
$rnd = Get-Random
$viewName = $snapshotName + '-view-' + $rnd

# Decide if a volume or volume group was specified, and create the snapshot. 
if ($volumeGroup) {
    if ($volumeName) {
        return "Please only select -volumeName or -volumeGroup, not both."
    }
    Get-K2VolumeGroup -Name $volumeGroup | New-K2Snapshot -ShortName $snapshotName -RetentionPolicyName $retentionPolicy
} elseif ($volumeName) {
    Get-K2Volume -Name $volumeName | New-K2Snapshot -ShortName $snapshotName -RetentionPolicyName $retentionPolicy
}

# Pause for the operation to complete. 
Start-sleep -Seconds 10

# Create the view. 
Get-K2Snapshot -ShortName $snapshotName | New-K2View -ShortName $viewName -RetentionPolicyName $retentionPolicy

# Pause for the operation to complete. 
Start-Sleep -seconds 10

# Map the view to the host or host group. 
if ($hostGroup) {
    if ($hostName) {
        return "Please only select -hostName or -hostGroup, not both."
    }
    Get-K2View -ShortName $viewName | New-K2Mapping -HostGroup $hostGroup
} elseif ($hostName) {
    Get-K2View -ShortName $viewName | New-K2Mapping -Hostname $hostName
}



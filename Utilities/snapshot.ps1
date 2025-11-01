<#
.SYNOPSIS
    Creates snapshots of multiple VMs for server patching operations.

.DESCRIPTION
    This script connects to a vCenter server and creates snapshots of VMs specified in a text file.
    Snapshots include VM memory to ensure complete state capture. Each snapshot is timestamped
    and includes a description indicating it was created for server patching purposes.

.PARAMETER Server
    vCenter Server or ESXi host IP address or FQDN (default: 192.168.2.133)

.PARAMETER Credential
    PSCredential object for authentication. If not provided, will prompt for credentials.

.PARAMETER VMListPath
    Path to text file containing VM names (one per line). Default: C:\temp\vm_list.txt

.PARAMETER IncludeMemory
    Switch to include VM memory in snapshot (default: enabled). Memory snapshots allow full VM recovery.

.PARAMETER Description
    Custom description for the snapshot. Default: "Snapshot taken on <date> by LVS for server patching"

.EXAMPLE
    .\snapshot.ps1

    Creates memory snapshots for all VMs listed in C:\temp\vm_list.txt using default server.

.EXAMPLE
    .\snapshot.ps1 -Server "vcenter.company.com" -VMListPath "D:\patching\servers.txt"

    Uses custom server and VM list path to create snapshots.

.EXAMPLE
    $cred = Get-Credential
    .\snapshot.ps1 -Server "192.168.0.171" -Credential $cred -Description "Pre-patch snapshot"

    Uses pre-defined credentials and custom description.

.EXAMPLE
    Connect-VIServer -Server "192.168.2.133"
    .\snapshot.ps1 -VMListPath "C:\servers.txt"

    Uses existing vCenter connection to create snapshots.

.NOTES
    Author: LVS
    Modified: 2025-10-28
    Requires: VMware PowerCLI module
    Version: 2.0

    IMPORTANT: Ensure adequate datastore space before creating snapshots with memory.
               Memory snapshots can consume significant storage.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Server = "192.168.2.133",

    [Parameter(Mandatory = $false)]
    [System.Management.Automation.PSCredential]$Credential,

    [Parameter(Mandatory = $false)]
    [string]$VMListPath = "C:\temp\vm_list.txt",

    [Parameter(Mandatory = $false)]
    [switch]$IncludeMemory = $true,

    [Parameter(Mandatory = $false)]
    [string]$Description = "Snapshot taken on $(Get-Date) by LVS for server patching"
)

#region Main Script

Write-Host "`n=== VMware Snapshot Creation Script ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date)" -ForegroundColor Cyan

# Connect to vCenter if not already connected
$needsConnection = $true
if ($global:DefaultVIServer -and $global:DefaultVIServer.IsConnected) {
    Write-Host "`nUsing existing connection to: $($global:DefaultVIServer.Name)" -ForegroundColor Green
    $needsConnection = $false
}

if ($needsConnection) {
    try {
        if (-not $Credential) {
            Write-Host "`nEnter credentials for $Server" -ForegroundColor Cyan
            $Credential = Get-Credential -Message "Enter credentials for $Server"
        }

        Write-Host "Connecting to vCenter Server: $Server" -ForegroundColor Cyan
        Connect-VIServer -Server $Server -Credential $Credential -ErrorAction Stop | Out-Null
        Write-Host "Successfully connected to $Server" -ForegroundColor Green
    }
    catch {
        Write-Host "ERROR: Failed to connect to $Server : $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

# Check if VM list file exists
if (-not (Test-Path $VMListPath)) {
    Write-Host "`nERROR: VM list file not found: $VMListPath" -ForegroundColor Red
    Write-Host "Please create this file with one VM name per line." -ForegroundColor Yellow
    if ($needsConnection) {
        Disconnect-VIServer -Server * -Confirm:$false -ErrorAction SilentlyContinue
    }
    exit 1
}

# Read VM names from file
$vmNames = Get-Content -Path $VMListPath | Where-Object { $_.Trim() -ne "" }

if ($vmNames.Count -eq 0) {
    Write-Host "`nERROR: VM list file is empty: $VMListPath" -ForegroundColor Red
    if ($needsConnection) {
        Disconnect-VIServer -Server * -Confirm:$false -ErrorAction SilentlyContinue
    }
    exit 1
}

Write-Host "`nFound $($vmNames.Count) VM(s) in list file" -ForegroundColor Cyan
Write-Host "Creating snapshots with memory: $IncludeMemory" -ForegroundColor Cyan
Write-Host "`nStarting snapshot creation..." -ForegroundColor Cyan

# Track statistics
$successCount = 0
$failCount = 0

foreach ($vmName in $vmNames) {
    $vmName = $vmName.Trim()

    if ([string]::IsNullOrWhiteSpace($vmName)) {
        continue
    }

    Write-Host "`nProcessing VM: $vmName" -ForegroundColor Yellow

    try {
        $vm = Get-VM -Name $vmName -ErrorAction Stop

        # Generate snapshot name with timestamp
        $snapshotName = "Snapshot_$(Get-Date -Format 'yyyyMMdd_HHmmss')"

        # Create snapshot
        if ($IncludeMemory) {
            New-Snapshot -VM $vm -Name $snapshotName -Description $Description -Memory -Confirm:$false -ErrorAction Stop | Out-Null
            Write-Host "  SUCCESS: Created snapshot with memory - $snapshotName" -ForegroundColor Green
        }
        else {
            New-Snapshot -VM $vm -Name $snapshotName -Description $Description -Confirm:$false -ErrorAction Stop | Out-Null
            Write-Host "  SUCCESS: Created snapshot (no memory) - $snapshotName" -ForegroundColor Green
        }

        $successCount++
    }
    catch {
        if ($_.Exception.Message -like "*not found*") {
            Write-Host "  ERROR: VM not found - $vmName" -ForegroundColor Red
        }
        else {
            Write-Host "  ERROR: Failed to create snapshot - $($_.Exception.Message)" -ForegroundColor Red
        }
        $failCount++
    }
}

# Display summary
Write-Host "`n=== Snapshot Creation Summary ===" -ForegroundColor Cyan
Write-Host "Total VMs processed: $($vmNames.Count)" -ForegroundColor Cyan
Write-Host "Successful snapshots: $successCount" -ForegroundColor Green
Write-Host "Failed snapshots: $failCount" -ForegroundColor $(if ($failCount -gt 0) { "Red" } else { "Green" })
Write-Host "`nCompleted at: $(Get-Date)" -ForegroundColor Cyan

# Disconnect if we connected in this script
if ($needsConnection) {
    Disconnect-VIServer -Server * -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host "Disconnected from vCenter server" -ForegroundColor Cyan
}

#endregion
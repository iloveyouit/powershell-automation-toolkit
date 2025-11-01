<#
.SYNOPSIS
    Enhanced Daily VM Power On Script with Host Maintenance Mode Management
    
.DESCRIPTION
    Powers on specified virtual machines with enhanced checks:
    - Verifies VMware connection status
    - Checks ESXi host maintenance mode
    - Provides interactive option to exit maintenance mode
    - Powers on VMs: Den-DC, Ubuntu01, Den-Server01, and Den-vCenter
    
.PARAMETER vCenterServer
    vCenter Server IP or hostname (default: 192.168.0.171)
    
.PARAMETER vCenterUser
    vCenter username (default: root)
    
.PARAMETER ESXiHost
    ESXi host to check for maintenance mode (optional)
    If not specified, will check all connected hosts
    
.EXAMPLE
    .\daily_poweron_enhanced.ps1

    Powers on VMs using default settings (192.168.0.171, root user).
    Checks for maintenance mode and prompts interactively if detected.

.EXAMPLE
    .\daily_poweron_enhanced.ps1 -vCenterServer "vcenter.company.com" -vCenterUser "administrator@vsphere.local"

    Powers on VMs on a specific vCenter Server with custom username.

.EXAMPLE
    .\daily_poweron_enhanced.ps1 -ESXiHost "esxi01.company.com"

    Powers on VMs and checks maintenance mode status only for the specified host.

.EXAMPLE
    $cred = Get-Credential
    Connect-VIServer -Server "192.168.0.171" -Credential $cred
    .\daily_poweron_enhanced.ps1

    Uses an existing vCenter connection to power on VMs (will not prompt for credentials).

.NOTES
    Author: System Administrator
    Date: 2025-10-27
    Requires: VMware PowerCLI module
    Version: 2.0 (Enhanced)
#>

[CmdletBinding()]
param(
    [string]$vCenterServer = "192.168.0.171",
    [string]$vCenterUser = "root",
    [string]$ESXiHost = $null
)

#region Helper Functions

function Write-ColorMessage {
    param(
        [string]$Message,
        [string]$Type = "Info"
    )
    
    switch ($Type) {
        "Success" { Write-Host $Message -ForegroundColor Green }
        "Warning" { Write-Host $Message -ForegroundColor Yellow }
        "Error"   { Write-Host $Message -ForegroundColor Red }
        "Info"    { Write-Host $Message -ForegroundColor Cyan }
        "Header"  { Write-Host $Message -ForegroundColor Magenta }
        default   { Write-Host $Message }
    }
}

function Test-VMwareConnection {
    <#
    .SYNOPSIS
        Checks if there's an active VMware connection
    #>
    
    Write-ColorMessage "`n=== Checking VMware Connection ===" "Header"
    
    $connection = $global:DefaultVIServer
    
    if ($null -eq $connection) {
        Write-ColorMessage "No active VMware connection found." "Warning"
        return $false
    }
    elseif ($connection.IsConnected) {
        Write-ColorMessage "Connected to: $($connection.Name)" "Success"
        Write-ColorMessage "User: $($connection.User)" "Info"
        Write-ColorMessage "Version: $($connection.Version)" "Info"
        return $true
    }
    else {
        Write-ColorMessage "VMware connection exists but is not active." "Warning"
        return $false
    }
}

function Get-HostMaintenanceStatus {
    <#
    .SYNOPSIS
        Checks maintenance mode status for ESXi host(s)
    #>
    param(
        [string]$HostName = $null
    )
    
    Write-ColorMessage "`n=== Checking Host Maintenance Mode Status ===" "Header"
    
    try {
        if ($HostName) {
            $hosts = Get-VMHost -Name $HostName -ErrorAction Stop
        }
        else {
            $hosts = Get-VMHost -ErrorAction Stop
        }
        
        $maintenanceHosts = @()
        
        foreach ($vmhost in $hosts) {
            $status = [PSCustomObject]@{
                HostName         = $vmhost.Name
                ConnectionState  = $vmhost.ConnectionState
                InMaintenance    = ($vmhost.ConnectionState -eq 'Maintenance')
                PowerState       = $vmhost.PowerState
                Version          = $vmhost.Version
            }
            
            if ($status.InMaintenance) {
                $maintenanceHosts += $status
                Write-ColorMessage "`nHost: $($status.HostName)" "Warning"
                Write-ColorMessage "  Status: IN MAINTENANCE MODE" "Warning"
                Write-ColorMessage "  Power State: $($status.PowerState)" "Info"
                Write-ColorMessage "  Version: $($status.Version)" "Info"
            }
            else {
                Write-ColorMessage "`nHost: $($status.HostName)" "Success"
                Write-ColorMessage "  Status: $($status.ConnectionState)" "Success"
                Write-ColorMessage "  Power State: $($status.PowerState)" "Info"
            }
        }
        
        return $maintenanceHosts
    }
    catch {
        Write-ColorMessage "Error checking host status: $($_.Exception.Message)" "Error"
        return $null
    }
}

function Exit-MaintenanceMode {
    <#
    .SYNOPSIS
        Takes ESXi host out of maintenance mode
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$HostName
    )
    
    try {
        Write-ColorMessage "`nAttempting to exit maintenance mode for: $HostName" "Info"
        
        $vmhost = Get-VMHost -Name $HostName -ErrorAction Stop
        
        if ($vmhost.ConnectionState -eq 'Maintenance') {
            Set-VMHost -VMHost $vmhost -State Connected -Confirm:$false -ErrorAction Stop
            
            # Wait for state change
            Start-Sleep -Seconds 5
            
            $vmhost = Get-VMHost -Name $HostName
            if ($vmhost.ConnectionState -ne 'Maintenance') {
                Write-ColorMessage "Successfully exited maintenance mode!" "Success"
                Write-ColorMessage "Current State: $($vmhost.ConnectionState)" "Success"
                return $true
            }
            else {
                Write-ColorMessage "Host is still in maintenance mode. May need more time." "Warning"
                return $false
            }
        }
        else {
            Write-ColorMessage "Host is not in maintenance mode. Current state: $($vmhost.ConnectionState)" "Info"
            return $true
        }
    }
    catch {
        Write-ColorMessage "Error exiting maintenance mode: $($_.Exception.Message)" "Error"
        return $false
    }
}

#endregion

#region Main Script

Write-ColorMessage "`n=====================================" "Header"
Write-ColorMessage "   Enhanced VM Power On Script" "Header"
Write-ColorMessage "=====================================" "Header"
Write-ColorMessage "Timestamp: $(Get-Date)" "Info"

# Step 1: Check for existing VMware connection
$isConnected = Test-VMwareConnection

# Step 2: Connect to vCenter if not already connected
if (-not $isConnected) {
    Write-ColorMessage "`nAttempting to connect to vCenter Server: $vCenterServer" "Info"
    
    try {
        $Credential = Get-Credential -UserName $vCenterUser -Message "Enter credentials for vCenter Server $vCenterServer"
        
        Connect-VIServer -Server $vCenterServer -Credential $Credential -ErrorAction Stop | Out-Null
        Write-ColorMessage "Successfully connected to vCenter!" "Success"
    }
    catch {
        Write-ColorMessage "Failed to connect to vCenter: $($_.Exception.Message)" "Error"
        exit 1
    }
}

# Step 3: Check host maintenance mode status
$maintenanceHosts = Get-HostMaintenanceStatus -HostName $ESXiHost

# Step 4: Handle maintenance mode if detected
if ($maintenanceHosts.Count -gt 0) {
    Write-ColorMessage "`n!!! WARNING: $($maintenanceHosts.Count) host(s) in maintenance mode !!!" "Warning"
    
    foreach ($mHost in $maintenanceHosts) {
        Write-ColorMessage "`nHost in Maintenance: $($mHost.HostName)" "Warning"
        
        # Interactive prompt
        $response = Read-Host "Do you want to take this host out of maintenance mode? (Y/N)"
        
        if ($response -match '^[Yy]') {
            $success = Exit-MaintenanceMode -HostName $mHost.HostName
            
            if (-not $success) {
                Write-ColorMessage "Failed to exit maintenance mode. VMs may not start properly." "Warning"
                $continue = Read-Host "Continue with VM power-on anyway? (Y/N)"
                if ($continue -notmatch '^[Yy]') {
                    Write-ColorMessage "Script terminated by user." "Info"
                    exit 0
                }
            }
        }
        else {
            Write-ColorMessage "Maintenance mode will remain active. VMs on this host may not start." "Warning"
        }
    }
}
else {
    Write-ColorMessage "`nAll hosts are operational (not in maintenance mode)." "Success"
}

# Step 5: Power on VMs
Write-ColorMessage "`n=== Starting VM Power On Process ===" "Header"

$VMsToStart = @(
    "Den-DC",
    "Den-Server01",
    "Den-vCenter",
    "CoreDC"
)

foreach ($VMName in $VMsToStart) {
    try {
        $VM = Get-VM -Name $VMName -ErrorAction Stop
        
        Write-ColorMessage "`nProcessing VM: $VMName" "Info"
        Write-ColorMessage "  Current State: $($VM.PowerState)" "Info"
        Write-ColorMessage "  Host: $($VM.VMHost.Name)" "Info"
        
        # Check if VM's host is in maintenance mode
        if ($VM.VMHost.ConnectionState -eq 'Maintenance') {
            Write-ColorMessage "  WARNING: VM is on a host in maintenance mode!" "Warning"
        }
        
        if ($VM.PowerState -eq "PoweredOff") {
            Write-ColorMessage "  Powering on VM..." "Info"
            Start-VM -VM $VM -Confirm:$false -ErrorAction Stop | Out-Null
            Write-ColorMessage "  Successfully started VM: $VMName" "Success"
        }
        elseif ($VM.PowerState -eq "PoweredOn") {
            Write-ColorMessage "  VM is already powered on" "Success"
        }
        else {
            Write-ColorMessage "  VM is in unexpected state: $($VM.PowerState)" "Warning"
        }
    }
    catch {
        Write-ColorMessage "  Error with VM $VMName : $($_.Exception.Message)" "Error"
    }
}

# Step 6: Final status check
Start-Sleep -Seconds 5

Write-ColorMessage "`n=== Final VM Status ===" "Header"
Get-VM -Name $VMsToStart | Select-Object Name, PowerState, NumCpu, MemoryGB, @{N='Host';E={$_.VMHost.Name}} | Format-Table -AutoSize

Write-ColorMessage "`n=== Script Completed ===" "Header"
Write-ColorMessage "Completed at: $(Get-Date)" "Success"

# Optional: Disconnect from vCenter
# Uncomment if you want to automatically disconnect
# Disconnect-VIServer -Confirm:$false

#endregion

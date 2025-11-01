<#
.SYNOPSIS
    Enhanced Daily VM Power Off Script with Host Maintenance Mode Management

.DESCRIPTION
    Powers off specified virtual machines with enhanced shutdown sequence:
    - Verifies VMware connection status
    - Performs graceful shutdown with guest OS shutdown where possible
    - Waits for all VMs to power off completely
    - Optionally places ESXi host into maintenance mode after all VMs are off
    - Powers off VMs: Den-DC, Den-Server01, Den-vCenter, and CoreDC

.PARAMETER vCenterServer
    vCenter Server IP or hostname (default: 192.168.0.171)

.PARAMETER vCenterUser
    vCenter username (default: root)

.PARAMETER ESXiHost
    ESXi host to place in maintenance mode (optional)
    If not specified, will prompt for which host to use

.PARAMETER EnableMaintenanceMode
    Switch to enable automatic maintenance mode after VM shutdown
    If not specified, will prompt interactively

.PARAMETER GracefulTimeout
    Timeout in seconds for graceful shutdown (default: 120)

.NOTES
    Author: System Administrator
    Date: 2025-10-28
    Requires: VMware PowerCLI module
    Version: 2.0 (Enhanced)
#>

[CmdletBinding()]
param(
    [string]$vCenterServer = "192.168.0.171",
    [string]$vCenterUser = "root",
    [string]$ESXiHost = $null,
    [switch]$EnableMaintenanceMode,
    [int]$GracefulTimeout = 120
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

function Stop-VMGracefully {
    <#
    .SYNOPSIS
        Performs graceful shutdown of a VM with fallback to force stop
    #>
    param(
        [Parameter(Mandatory=$true)]
        $VM,
        [int]$Timeout = 120
    )

    try {
        Write-ColorMessage "`nProcessing VM: $($VM.Name)" "Info"
        Write-ColorMessage "  Current State: $($VM.PowerState)" "Info"
        Write-ColorMessage "  Host: $($VM.VMHost.Name)" "Info"
        Write-ColorMessage "  VMware Tools: $($VM.ExtensionData.Guest.ToolsStatus)" "Info"

        if ($VM.PowerState -eq "PoweredOff") {
            Write-ColorMessage "  VM is already powered off" "Success"
            return $true
        }

        if ($VM.PowerState -ne "PoweredOn") {
            Write-ColorMessage "  VM is in unexpected state: $($VM.PowerState)" "Warning"
            return $false
        }

        # Try graceful shutdown if VMware Tools is available
        if ($VM.ExtensionData.Guest.ToolsStatus -eq "toolsOk") {
            Write-ColorMessage "  Attempting graceful shutdown (VMware Tools detected)..." "Info"
            Shutdown-VMGuest -VM $VM -Confirm:$false -ErrorAction Stop | Out-Null

            # Wait for graceful shutdown
            $elapsed = 0
            $vmRef = $VM
            while ($vmRef.PowerState -eq "PoweredOn" -and $elapsed -lt $Timeout) {
                Start-Sleep -Seconds 10
                $elapsed += 10
                $vmRef = Get-VM -Name $VM.Name
                Write-ColorMessage "  Waiting for graceful shutdown... ($elapsed/$Timeout seconds)" "Info"
            }

            # Check if shutdown succeeded
            if ($vmRef.PowerState -eq "PoweredOff") {
                Write-ColorMessage "  Successfully shut down via guest OS" "Success"
                return $true
            }
            else {
                Write-ColorMessage "  Graceful shutdown timed out, forcing power off..." "Warning"
                Stop-VM -VM $vmRef -Confirm:$false -ErrorAction Stop | Out-Null
                Write-ColorMessage "  Forced power off successful" "Warning"
                return $true
            }
        }
        else {
            # VMware Tools not available, force power off
            Write-ColorMessage "  VMware Tools not available, forcing power off..." "Warning"
            Stop-VM -VM $VM -Confirm:$false -ErrorAction Stop | Out-Null
            Write-ColorMessage "  Forced power off successful" "Warning"
            return $true
        }
    }
    catch {
        Write-ColorMessage "  Error stopping VM: $($_.Exception.Message)" "Error"
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

    Write-ColorMessage "`n=== Checking Host Status ===" "Header"

    try {
        if ($HostName) {
            $hosts = Get-VMHost -Name $HostName -ErrorAction Stop
        }
        else {
            $hosts = Get-VMHost -ErrorAction Stop
        }

        foreach ($vmhost in $hosts) {
            Write-ColorMessage "`nHost: $($vmhost.Name)" "Info"
            Write-ColorMessage "  Connection State: $($vmhost.ConnectionState)" "Info"
            Write-ColorMessage "  Power State: $($vmhost.PowerState)" "Info"
            Write-ColorMessage "  Version: $($vmhost.Version)" "Info"

            # Count running VMs
            $runningVMs = Get-VM -Location $vmhost | Where-Object { $_.PowerState -eq "PoweredOn" }
            Write-ColorMessage "  Running VMs: $($runningVMs.Count)" "Info"
        }

        return $hosts
    }
    catch {
        Write-ColorMessage "Error checking host status: $($_.Exception.Message)" "Error"
        return $null
    }
}

function Enter-MaintenanceMode {
    <#
    .SYNOPSIS
        Places ESXi host into maintenance mode
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$HostName
    )

    try {
        Write-ColorMessage "`n=== Entering Maintenance Mode ===" "Header"
        Write-ColorMessage "Host: $HostName" "Info"

        $vmhost = Get-VMHost -Name $HostName -ErrorAction Stop

        # Check if already in maintenance mode
        if ($vmhost.ConnectionState -eq 'Maintenance') {
            Write-ColorMessage "Host is already in maintenance mode" "Success"
            return $true
        }

        # Check for running VMs
        $runningVMs = Get-VM -Location $vmhost | Where-Object { $_.PowerState -eq "PoweredOn" }
        if ($runningVMs.Count -gt 0) {
            Write-ColorMessage "`nWARNING: $($runningVMs.Count) VM(s) still running on this host:" "Warning"
            $runningVMs | ForEach-Object { Write-ColorMessage "  - $($_.Name)" "Warning" }

            $response = Read-Host "`nProceed with maintenance mode anyway? (Y/N)"
            if ($response -notmatch '^[Yy]') {
                Write-ColorMessage "Maintenance mode cancelled by user" "Info"
                return $false
            }
        }

        Write-ColorMessage "`nPlacing host into maintenance mode..." "Info"
        Write-ColorMessage "This may take several minutes..." "Info"

        Set-VMHost -VMHost $vmhost -State Maintenance -Confirm:$false -ErrorAction Stop | Out-Null

        # Wait for state change
        Start-Sleep -Seconds 10

        $vmhost = Get-VMHost -Name $HostName
        if ($vmhost.ConnectionState -eq 'Maintenance') {
            Write-ColorMessage "`nSuccessfully entered maintenance mode!" "Success"
            Write-ColorMessage "Current State: $($vmhost.ConnectionState)" "Success"
            return $true
        }
        else {
            Write-ColorMessage "`nHost state: $($vmhost.ConnectionState)" "Warning"
            Write-ColorMessage "May need more time to enter maintenance mode" "Warning"
            return $false
        }
    }
    catch {
        Write-ColorMessage "Error entering maintenance mode: $($_.Exception.Message)" "Error"
        return $false
    }
}

#endregion

#region Main Script

Write-ColorMessage "`n========================================" "Header"
Write-ColorMessage "   Enhanced VM Power Off Script" "Header"
Write-ColorMessage "========================================" "Header"
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

# Step 3: Get initial host status
$hosts = Get-HostMaintenanceStatus -HostName $ESXiHost

# Step 4: Power off VMs
Write-ColorMessage "`n=== Starting VM Power Off Process ===" "Header"

$VMsToStop = @(
    "Den-DC",
    "Den-Server01",
    "Den-vCenter",
    "CoreDC"
)

$failedVMs = @()

foreach ($VMName in $VMsToStop) {
    try {
        $VM = Get-VM -Name $VMName -ErrorAction Stop
        $success = Stop-VMGracefully -VM $VM -Timeout $GracefulTimeout

        if (-not $success) {
            $failedVMs += $VMName
        }
    }
    catch {
        Write-ColorMessage "`nError retrieving VM $VMName : $($_.Exception.Message)" "Error"
        $failedVMs += $VMName
    }
}

# Step 5: Wait and verify all VMs are off
Start-Sleep -Seconds 5

Write-ColorMessage "`n=== Final VM Status ===" "Header"
$finalStatus = Get-VM -Name $VMsToStop | Select-Object Name, PowerState, NumCpu, MemoryGB, @{N='Host';E={$_.VMHost.Name}}
$finalStatus | Format-Table -AutoSize

# Check if any VMs are still running
$stillRunning = $finalStatus | Where-Object { $_.PowerState -eq "PoweredOn" }

if ($stillRunning.Count -gt 0) {
    Write-ColorMessage "`nWARNING: $($stillRunning.Count) VM(s) still running:" "Warning"
    $stillRunning | ForEach-Object { Write-ColorMessage "  - $($_.Name)" "Warning" }
    $failedVMs += $stillRunning.Name
}

# Step 6: Maintenance mode handling
if ($failedVMs.Count -eq 0) {
    Write-ColorMessage "`n=== All VMs Successfully Powered Off ===" "Success"

    # Determine if we should enter maintenance mode
    $shouldEnterMaintenance = $false

    if ($EnableMaintenanceMode) {
        $shouldEnterMaintenance = $true
    }
    else {
        Write-ColorMessage "`n=== Maintenance Mode Option ===" "Header"
        $response = Read-Host "Do you want to place the ESXi host into maintenance mode? (Y/N)"
        if ($response -match '^[Yy]') {
            $shouldEnterMaintenance = $true
        }
    }

    if ($shouldEnterMaintenance) {
        # Determine which host to use
        $targetHost = $ESXiHost

        if (-not $targetHost) {
            Write-ColorMessage "`nAvailable hosts:" "Info"
            $allHosts = Get-VMHost
            for ($i = 0; $i -lt $allHosts.Count; $i++) {
                Write-ColorMessage "  [$i] $($allHosts[$i].Name)" "Info"
            }

            if ($allHosts.Count -eq 1) {
                $targetHost = $allHosts[0].Name
                Write-ColorMessage "`nUsing only available host: $targetHost" "Info"
            }
            else {
                $selection = Read-Host "`nEnter host number (or host name)"
                if ($selection -match '^\d+$') {
                    $targetHost = $allHosts[[int]$selection].Name
                }
                else {
                    $targetHost = $selection
                }
            }
        }

        # Enter maintenance mode
        $success = Enter-MaintenanceMode -HostName $targetHost

        if ($success) {
            Write-ColorMessage "`n=== Maintenance Mode Active ===" "Success"
        }
        else {
            Write-ColorMessage "`n=== Maintenance Mode Failed ===" "Warning"
        }
    }
    else {
        Write-ColorMessage "`nMaintenance mode skipped - hosts remain operational" "Info"
    }
}
else {
    Write-ColorMessage "`n=== Power Off Completed with Errors ===" "Warning"
    Write-ColorMessage "Failed VMs: $($failedVMs -join ', ')" "Warning"
    Write-ColorMessage "Maintenance mode will NOT be enabled due to failed shutdowns" "Warning"
}

# Step 7: Final summary
Write-ColorMessage "`n========================================" "Header"
Write-ColorMessage "   Power Off Process Complete" "Header"
Write-ColorMessage "========================================" "Header"
Write-ColorMessage "Completed at: $(Get-Date)" "Success"
Write-ColorMessage "VMs processed: $($VMsToStop.Count)" "Info"
Write-ColorMessage "Failed shutdowns: $($failedVMs.Count)" "Info"

# Optional: Disconnect from vCenter
# Uncomment if you want to automatically disconnect
# Disconnect-VIServer -Confirm:$false

#endregion

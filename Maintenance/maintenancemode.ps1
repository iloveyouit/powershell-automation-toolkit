<#
.SYNOPSIS
    Manages ESXi host maintenance mode operations.

.DESCRIPTION
    This script provides functions to:
    - Connect to vCenter/ESXi hosts
    - Enter maintenance mode on ESXi hosts
    - Exit maintenance mode on ESXi hosts
    - Check maintenance mode status

.PARAMETER Server
    vCenter Server or ESXi host IP address or FQDN (default: 192.168.0.171)

.PARAMETER Credential
    PSCredential object for authentication. If not provided, will prompt for credentials.

.PARAMETER Action
    The action to perform: Enter, Exit, or Status (default: Status)

.EXAMPLE
    .\maintenancemode.ps1 -Server "192.168.0.171" -Action Status

    Checks the current maintenance mode status of the specified host.

.EXAMPLE
    .\maintenancemode.ps1 -Server "192.168.0.171" -Action Enter

    Places the specified host into maintenance mode.

.EXAMPLE
    .\maintenancemode.ps1 -Server "192.168.0.171" -Action Exit

    Exits the specified host from maintenance mode.

.EXAMPLE
    $cred = Get-Credential
    .\maintenancemode.ps1 -Server "vcenter.company.com" -Credential $cred -Action Enter

    Uses pre-defined credentials to enter maintenance mode.

.NOTES
    Author: System Administrator
    Date: 2025-10-28
    Requires: VMware PowerCLI module
    Version: 2.0
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Server = "192.168.0.171",

    [Parameter(Mandatory = $false)]
    [System.Management.Automation.PSCredential]$Credential,

    [Parameter(Mandatory = $false)]
    [ValidateSet('Enter', 'Exit', 'Status')]
    [string]$Action = 'Status'
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

#endregion

#region Main Script

Write-ColorMessage "`n=== ESXi Host Maintenance Mode Manager ===" "Header"
Write-ColorMessage "Timestamp: $(Get-Date)" "Info"

# Get credentials if not provided
if (-not $Credential) {
    Write-ColorMessage "`nEnter credentials for $Server" "Info"
    $Credential = Get-Credential -Message "Enter credentials for $Server"
}

# Connect to vCenter Server
try {
    Write-ColorMessage "`nConnecting to: $Server" "Info"
    Connect-VIServer -Server $Server -Credential $Credential -ErrorAction Stop | Out-Null
    Write-ColorMessage "Successfully connected to $Server" "Success"
}
catch {
    Write-ColorMessage "Failed to connect to $Server : $($_.Exception.Message)" "Error"
    exit 1
}

# Get host information
try {
    $vmHost = Get-VMHost -Name $Server -ErrorAction Stop

    Write-ColorMessage "`n=== Current Host Status ===" "Header"
    Write-ColorMessage "Host: $($vmHost.Name)" "Info"
    Write-ColorMessage "Connection State: $($vmHost.ConnectionState)" "Info"
    Write-ColorMessage "Power State: $($vmHost.PowerState)" "Info"
    Write-ColorMessage "Version: $($vmHost.Version)" "Info"

    $isInMaintenance = $vmHost.ConnectionState -eq "Maintenance"
    Write-ColorMessage "In Maintenance Mode: $isInMaintenance" $(if ($isInMaintenance) { "Warning" } else { "Success" })

    # Count running VMs
    $runningVMs = Get-VM -Location $vmHost | Where-Object { $_.PowerState -eq "PoweredOn" }
    Write-ColorMessage "Running VMs: $($runningVMs.Count)" "Info"

    if ($runningVMs.Count -gt 0) {
        Write-ColorMessage "`nRunning VMs on host:" "Warning"
        $runningVMs | ForEach-Object { Write-ColorMessage "  - $($_.Name)" "Warning" }
    }
}
catch {
    Write-ColorMessage "Failed to get host information: $($_.Exception.Message)" "Error"
    Disconnect-VIServer -Server * -Confirm:$false -ErrorAction SilentlyContinue
    exit 1
}

# Perform action based on parameter
switch ($Action) {
    'Enter' {
        Write-ColorMessage "`n=== Entering Maintenance Mode ===" "Header"

        if ($vmHost.ConnectionState -eq 'Maintenance') {
            Write-ColorMessage "Host is already in maintenance mode" "Info"
        }
        else {
            if ($runningVMs.Count -gt 0) {
                Write-ColorMessage "`nWARNING: $($runningVMs.Count) VM(s) are still running!" "Warning"
                $confirm = Read-Host "Continue anyway? (Y/N)"
                if ($confirm -notmatch '^[Yy]') {
                    Write-ColorMessage "Operation cancelled by user" "Info"
                    Disconnect-VIServer -Server * -Confirm:$false -ErrorAction SilentlyContinue
                    exit 0
                }
            }

            try {
                Write-ColorMessage "Placing host into maintenance mode..." "Info"
                Set-VMHost -VMHost $vmHost -State Maintenance -Confirm:$false -ErrorAction Stop | Out-Null
                Start-Sleep -Seconds 5

                $vmHost = Get-VMHost -Name $Server
                if ($vmHost.ConnectionState -eq 'Maintenance') {
                    Write-ColorMessage "Successfully entered maintenance mode" "Success"
                }
                else {
                    Write-ColorMessage "Host state: $($vmHost.ConnectionState)" "Warning"
                }
            }
            catch {
                Write-ColorMessage "Failed to enter maintenance mode: $($_.Exception.Message)" "Error"
            }
        }
    }

    'Exit' {
        Write-ColorMessage "`n=== Exiting Maintenance Mode ===" "Header"

        if ($vmHost.ConnectionState -ne 'Maintenance') {
            Write-ColorMessage "Host is not in maintenance mode" "Info"
        }
        else {
            try {
                Write-ColorMessage "Taking host out of maintenance mode..." "Info"
                Set-VMHost -VMHost $vmHost -State Connected -Confirm:$false -ErrorAction Stop | Out-Null
                Start-Sleep -Seconds 5

                $vmHost = Get-VMHost -Name $Server
                if ($vmHost.ConnectionState -ne 'Maintenance') {
                    Write-ColorMessage "Successfully exited maintenance mode" "Success"
                    Write-ColorMessage "Current state: $($vmHost.ConnectionState)" "Success"
                }
                else {
                    Write-ColorMessage "Host state: $($vmHost.ConnectionState)" "Warning"
                }
            }
            catch {
                Write-ColorMessage "Failed to exit maintenance mode: $($_.Exception.Message)" "Error"
            }
        }
    }

    'Status' {
        # Status already displayed above
        Write-ColorMessage "`nUse -Action Enter or -Action Exit to change maintenance mode" "Info"
    }
}

# Display final status
Write-ColorMessage "`n=== Final Host Status ===" "Header"
$finalStatus = Get-VMHost -Name $Server | Select-Object Name, ConnectionState,
    @{Name="MaintenanceMode"; Expression={$_.ConnectionState -eq "Maintenance"}},
    PowerState, Version

$finalStatus | Format-List

Write-ColorMessage "`n=== Operation Complete ===" "Header"
Write-ColorMessage "Completed at: $(Get-Date)" "Success"

# Disconnect from vCenter Server
Disconnect-VIServer -Server * -Confirm:$false -ErrorAction SilentlyContinue
Write-ColorMessage "Disconnected from vCenter server" "Info"

#endregion

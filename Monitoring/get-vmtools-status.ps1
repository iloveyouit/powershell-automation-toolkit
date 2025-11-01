[CmdletBinding()] param(
    [Parameter(Mandatory=$false, Position=0, HelpMessage="FQDN or IP of vCenter or ESXi host")]
    [string]$Server = "192.168.0.171",
    [Parameter(Mandatory=$false, HelpMessage="Credential object to connect. If not supplied, you will be prompted.")]
    [System.Management.Automation.PSCredential]$Credential,
    [Parameter(Mandatory=$false, HelpMessage="Filter by Datacenter name (exact match or wildcard)")]
    [string]$Datacenter,
    [Parameter(Mandatory=$false, HelpMessage="Filter by Cluster name (exact match or wildcard)")]
    [string]$Cluster,
    [Parameter(Mandatory=$false, HelpMessage="Filter by Folder name (exact match or wildcard)")]
    [string]$Folder,
    [Parameter(Mandatory=$false, HelpMessage="Filter by VM name (supports wildcards)")]
    [string]$Name,
    [Parameter(Mandatory=$false, HelpMessage="Only include powered-on VMs")]
    [switch]$OnlyPoweredOn,
    [Parameter(Mandatory=$false, HelpMessage="Only show VMs with out-of-date VMware Tools")]
    [switch]$OutOfDate,
    [Parameter(Mandatory=$false, HelpMessage="Only show VMs with VMware Tools not installed")]
    [switch]$NotInstalled,
    [Parameter(Mandatory=$false, HelpMessage="Only show VMs with VMware Tools not running")]
    [switch]$NotRunning,
    [Parameter(Mandatory=$false, HelpMessage="Optional CSV output path")]
    [string]$OutputCsv,
    [Parameter(Mandatory=$false, HelpMessage="Show progress bar for large environments")]
    [switch]$ShowProgress
)

begin {
    function Write-ColorMessage {
        param(
            [string]$Message,
            [ValidateSet("Info", "Success", "Warning", "Error", "Header")]
            [string]$Type = "Info"
        )
        $color = switch ($Type) {
            "Info"    { "Cyan" }
            "Success" { "Green" }
            "Warning" { "Yellow" }
            "Error"   { "Red" }
            "Header"  { "Magenta" }
        }
        Write-Host $Message -ForegroundColor $color
    }

    function Ensure-PowerCLIInstalled {
        if (-not (Get-Command -Name Connect-VIServer -ErrorAction SilentlyContinue)) {
            Write-ColorMessage "VMware PowerCLI is not available. Install it with: Install-Module -Name VMware.PowerCLI -Scope CurrentUser" -Type Error
            throw "PowerCLI not installed"
        }
    }

    function Initialize-PowerCLIConfiguration {
        # Ignore certificate warnings for self-signed certificates
        $null = Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false -Scope Session -WarningAction SilentlyContinue
        $null = Set-PowerCLIConfiguration -ParticipateInCEIP $false -Confirm:$false -Scope Session -WarningAction SilentlyContinue
    }

    function Connect-ToVIServer {
        param(
            [string]$Server,
            [System.Management.Automation.PSCredential]$Cred
        )

        # Check if already connected to this server
        $existingConnection = $global:DefaultVIServer | Where-Object { $_.Name -eq $Server -and $_.IsConnected }
        if ($existingConnection) {
            Write-ColorMessage "Already connected to vCenter: $Server" -Type Info
            return
        }

        try {
            if ($null -eq $Cred) {
                $Cred = Get-Credential -Message "Enter credentials for $Server (vCenter or ESXi)"
            }
            Write-ColorMessage "Connecting to vCenter: $Server..." -Type Info
            $null = Connect-VIServer -Server $Server -Credential $Cred -ErrorAction Stop
            Write-ColorMessage "Successfully connected to $Server" -Type Success
        }
        catch {
            Write-ColorMessage "Failed to connect to '$Server': $($_.Exception.Message)" -Type Error
            throw
        }
    }

    function Get-ScopedVMs {
        param(
            [string]$Dc,
            [string]$Clu,
            [string]$Fld,
            [string]$VmName,
            [switch]$PoweredOnOnly
        )
        $scope = @()
        if ($Dc) { $scope += Get-Datacenter -Name $Dc -ErrorAction SilentlyContinue }
        if ($Clu) { $scope += Get-Cluster -Name $Clu -ErrorAction SilentlyContinue }
        if ($Fld) { $scope += Get-Folder  -Name $Fld -ErrorAction SilentlyContinue }

        $vmQuery = @{}
        if ($VmName) { $vmQuery.Name = $VmName }
        if ($scope.Count -gt 0) {
            $vms = $scope | Get-VM @vmQuery -ErrorAction SilentlyContinue
        }
        else {
            $vms = Get-VM @vmQuery -ErrorAction SilentlyContinue
        }
        if ($PoweredOnOnly) {
            $vms = $vms | Where-Object { $_.PowerState -eq 'PoweredOn' }
        }
        return $vms
    }

    function Get-VMToolsReportRow {
        param([VMware.VimAutomation.ViCore.Types.V1.Inventory.VirtualMachine]$Vm)

        if (-not $Vm) {
            Write-ColorMessage "Null VM object passed to Get-VMToolsReportRow" -Type Warning
            return
        }

        $view = $Vm | Get-View -ErrorAction SilentlyContinue
        if (-not $view) {
            Write-ColorMessage "Could not get view for VM: $($Vm.Name)" -Type Warning
            return
        }

        $guest = $view.Guest
        $config = $view.Config

        # Safely get datastore
        $datastoreName = ''
        try {
            $ds = $Vm | Get-Datastore -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($ds) { $datastoreName = $ds.Name }
        } catch {
            $datastoreName = 'N/A'
        }

        # Safely get folder
        $folderName = ''
        try {
            if ($Vm.Folder) { $folderName = $Vm.Folder.Name }
        } catch {
            $folderName = 'N/A'
        }

        $toolsStatus           = $guest.ToolsStatus          # toolsOk, toolsOld, toolsNotInstalled, toolsNotRunning
        $toolsVersion          = $guest.ToolsVersion
        $toolsVersionStatus2   = $guest.ToolsVersionStatus2  # guestToolsCurrent, guestToolsNeedUpgrade, guestToolsUnmanaged, guestToolsNotInstalled
        $toolsRunningStatus    = $guest.ToolsRunningStatus   # guestToolsRunning, guestToolsNotRunning, guestToolsExecutingScripts
        $guestState            = $guest.GuestState           # running, notRunning, unknown
        $ips                   = $guest.IPAddress
        $osFullName            = $guest.GuestFullName

        [pscustomobject]@{
            VMName              = $Vm.Name
            PowerState          = [string]$Vm.PowerState
            VMHost              = $Vm.VMHost.Name
            Datastore           = $datastoreName
            Folder              = $folderName
            GuestOS             = $osFullName
            GuestState          = $guestState
            ToolsStatus         = $toolsStatus
            ToolsRunningStatus  = $toolsRunningStatus
            ToolsVersion        = $toolsVersion
            ToolsVersionStatus2 = $toolsVersionStatus2
            IPAddresses         = ($ips -join ',')
        }
    }

    function Filter-VMToolsStatus {
        param(
            [Parameter(ValueFromPipeline=$true)]
            [object[]]$VMData,
            [switch]$OutOfDate,
            [switch]$NotInstalled,
            [switch]$NotRunning
        )

        process {
            foreach ($vm in $VMData) {
                $include = $true

                if ($OutOfDate -and $vm.ToolsVersionStatus2 -ne 'guestToolsNeedUpgrade') {
                    $include = $false
                }
                if ($NotInstalled -and $vm.ToolsStatus -ne 'toolsNotInstalled') {
                    $include = $false
                }
                if ($NotRunning -and $vm.ToolsRunningStatus -ne 'guestToolsNotRunning') {
                    $include = $false
                }

                if ($include) {
                    $vm
                }
            }
        }
    }

    function Show-VMToolsSummary {
        param([object[]]$Report)

        Write-Host ""
        Write-ColorMessage "=== VMware Tools Status Summary ===" -Type Header
        Write-Host ""

        $total = $Report.Count
        $poweredOn = ($Report | Where-Object { $_.PowerState -eq 'PoweredOn' }).Count
        $poweredOff = ($Report | Where-Object { $_.PowerState -eq 'PoweredOff' }).Count

        $toolsOk = ($Report | Where-Object { $_.ToolsStatus -eq 'toolsOk' }).Count
        $toolsOld = ($Report | Where-Object { $_.ToolsStatus -eq 'toolsOld' }).Count
        $toolsNotInstalled = ($Report | Where-Object { $_.ToolsStatus -eq 'toolsNotInstalled' }).Count
        $toolsNotRunning = ($Report | Where-Object { $_.ToolsStatus -eq 'toolsNotRunning' }).Count

        Write-ColorMessage "Total VMs: $total" -Type Info
        Write-Host "  - Powered On:  $poweredOn" -ForegroundColor Cyan
        Write-Host "  - Powered Off: $poweredOff" -ForegroundColor Cyan
        Write-Host ""

        Write-ColorMessage "VMware Tools Status:" -Type Info
        Write-Host "  - " -NoNewline
        Write-Host "OK (Current):    $toolsOk" -ForegroundColor Green
        Write-Host "  - " -NoNewline
        Write-Host "Out of Date:     $toolsOld" -ForegroundColor Yellow
        Write-Host "  - " -NoNewline
        Write-Host "Not Installed:   $toolsNotInstalled" -ForegroundColor Red
        Write-Host "  - " -NoNewline
        Write-Host "Not Running:     $toolsNotRunning" -ForegroundColor Yellow
        Write-Host ""
    }
}

process {
    Write-ColorMessage "=== VMware Tools Status Report ===" -Type Header
    Write-Host ""

    Ensure-PowerCLIInstalled
    Initialize-PowerCLIConfiguration
    Connect-ToVIServer -Server $Server -Cred $Credential

    try {
        Write-ColorMessage "Gathering VM inventory..." -Type Info
        $vms = Get-ScopedVMs -Dc $Datacenter -Clu $Cluster -Fld $Folder -VmName $Name -PoweredOnOnly:$OnlyPoweredOn

        if (-not $vms) {
            Write-ColorMessage "No VMs matched the specified filters." -Type Warning
            return
        }

        Write-ColorMessage "Found $($vms.Count) VMs. Collecting VMware Tools status..." -Type Info
        Write-Host ""

        # Collect VM Tools data with optional progress
        $report = @()
        $i = 0
        foreach ($vm in ($vms | Sort-Object -Property Name)) {
            $i++
            if ($ShowProgress) {
                Write-Progress -Activity "Collecting VMware Tools Status" -Status "Processing VM: $($vm.Name)" -PercentComplete (($i / $vms.Count) * 100)
            }
            $row = Get-VMToolsReportRow -Vm $vm
            if ($row) {
                $report += $row
            }
        }
        if ($ShowProgress) {
            Write-Progress -Activity "Collecting VMware Tools Status" -Completed
        }

        # Apply filtering switches
        if ($OutOfDate -or $NotInstalled -or $NotRunning) {
            Write-ColorMessage "Applying status filters..." -Type Info
            $filteredReport = $report | Filter-VMToolsStatus -OutOfDate:$OutOfDate -NotInstalled:$NotInstalled -NotRunning:$NotRunning
            if (-not $filteredReport) {
                Write-ColorMessage "No VMs matched the specified VMware Tools status filters." -Type Warning
                Show-VMToolsSummary -Report $report
                return
            }
            $report = $filteredReport
        }

        # Show summary
        Show-VMToolsSummary -Report $report

        # Output results
        if ($OutputCsv) {
            $dir = Split-Path -Path $OutputCsv -Parent
            if ($dir -and -not (Test-Path -Path $dir)) {
                New-Item -Path $dir -ItemType Directory -Force | Out-Null
            }
            $report | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8
            Write-ColorMessage "Exported VM Tools status for $($report.Count) VMs to: $OutputCsv" -Type Success
        }
        else {
            $report | Format-Table -AutoSize -Wrap
        }
    }
    catch {
        Write-ColorMessage "Error during execution: $($_.Exception.Message)" -Type Error
        throw
    }
    finally {
        Write-Host ""
        Write-ColorMessage "Disconnecting from vCenter..." -Type Info
        Disconnect-VIServer -Server * -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
        Write-ColorMessage "Completed successfully!" -Type Success
    }
}

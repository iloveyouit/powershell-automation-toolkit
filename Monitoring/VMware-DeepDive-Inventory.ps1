<#
.SYNOPSIS
    VMware Infrastructure Deep Dive Inventory and Analysis Report

.DESCRIPTION
    This script performs a comprehensive inventory of VMware infrastructure including:
    - Virtual Machines (configuration, performance, tools status)
    - ESXi Hosts (hardware, performance, configuration)
    - Datastores (capacity, performance, usage)
    - Snapshots (age, size, orphaned)
    - Networks (port groups, VLANs, distributed switches)
    - Clusters (HA/DRS configuration, resource pools)
    - vCenter information and licensing
    - Performance metrics and health status

.PARAMETER vCenterServer
    The vCenter Server to connect to

.PARAMETER Credential
    PSCredential object for authentication (optional - will prompt if not provided)

.PARAMETER OutputPath
    Path where reports will be saved (default: current directory)

.PARAMETER IncludePerformanceMetrics
    Include performance counter data collection (may take longer)

.PARAMETER ExportFormat
    Export format: CSV, JSON, HTML, or All (default: All)

.PARAMETER DaysBack
    Number of days back to collect performance and event data (default: 7)

.EXAMPLE
    .\VMware-DeepDive-Inventory.ps1 -vCenterServer "vcenter.company.com"

.EXAMPLE
    .\VMware-DeepDive-Inventory.ps1 -vCenterServer "vcenter.company.com" -IncludePerformanceMetrics -DaysBack 30 -ExportFormat "HTML,CSV"

.NOTES
    Author: System Administrator
    Version: 2.1
    Requires: VMware PowerCLI module
    
    This script requires appropriate permissions in vCenter to read all inventory data.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$vCenterServer,
    
    [Parameter(Mandatory = $false)]
    [PSCredential]$Credential,
    
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = ".",
    
    [Parameter(Mandatory = $false)]
    [switch]$IncludePerformanceMetrics,
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("CSV", "JSON", "HTML", "All")]
    [string]$ExportFormat = "All",
    
    [Parameter(Mandatory = $false)]
    [int]$DaysBack = 7
)

#region Initialize Script
$startTime = Get-Date
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host "VMware Infrastructure Deep Dive Inventory Report" -ForegroundColor Cyan
Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host "Started at: $startTime" -ForegroundColor Green

# Check for PowerCLI module
if (-not (Get-Module -ListAvailable -Name VMware.PowerCLI)) {
    Write-Error "VMware PowerCLI module is not installed. Please install it using: Install-Module -Name VMware.PowerCLI"
    exit 1
}

# Import PowerCLI modules
try {
    Import-Module VMware.PowerCLI -ErrorAction Stop
    Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -ParticipateInCEIP $false -Scope Session -Confirm:$false | Out-Null
    Write-Host "PowerCLI modules loaded successfully" -ForegroundColor Green
}
catch {
    Write-Error "Failed to import PowerCLI modules: $($_.Exception.Message)"
    exit 1
}

# Import data collection functions from the module
try {
    $modulePath = Join-Path $PSScriptRoot "VMware-DataCollection-Modules.ps1"
    Import-Module $modulePath -Force
    Write-Host "Successfully imported data collection modules." -ForegroundColor Green
}
catch {
    Write-Error "Failed to import VMware-DataCollection-Modules.ps1. Make sure it's in the same directory as the main script. Error: $($_.Exception.Message)"
    exit 1
}


# Create output directory with timestamp
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$reportDir = Join-Path $OutputPath "VMware_Inventory_$timestamp"
New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
Write-Host "Reports will be saved to: $reportDir" -ForegroundColor Yellow

# Initialize collections with a defined order
$inventoryData = [ordered]@{
    vCenterInfo = @()
    Licensing = @()
    Clusters = @()
    Hosts = @()
    VMs = @()
    Datastores = @()
    Networks = @()
    ResourcePools = @()
    Snapshots = @()
    PerformanceMetrics = [System.Collections.Generic.List[psobject]]::new()
    Events = @()
}
#endregion

#region Helper Functions
function Write-Progress-Custom {
    param($Activity, $Status, $PercentComplete)
    Write-Progress -Activity $Activity -Status $Status -PercentComplete $PercentComplete
    Write-Host "[$PercentComplete%] $Status" -ForegroundColor Cyan
}

function Get-VMwareEvents {
    param($DaysBack)
    try {
        $startTime = (Get-Date).AddDays(-$DaysBack)
        Write-Host "Collecting events from the last $DaysBack days..." -ForegroundColor Yellow
        
        $events = Get-VIEvent -Start $startTime | Where-Object {
            $_.GetType().Name -match "VmPoweredOnEvent|VmPoweredOffEvent|VmSuspendedEvent|VmMigratedEvent|VmCreatedEvent|VmRemovedEvent|HostConnectionLostEvent|HostReconnectedEvent"
        } | Select-Object -First 1000

        if (-not $events) {
            Write-Host "No relevant events found in the last $DaysBack days." -ForegroundColor Green
            return @()
        }

        return $events | ForEach-Object {
            [PSCustomObject]@{
                CreatedTime = $_.CreatedTime
                EventType = $_.GetType().Name
                ObjectName = if ($_.Vm) { $_.Vm.Name } elseif ($_.Host) { $_.Host.Name } else { "N/A" }
                ObjectType = if ($_.Vm) { "VirtualMachine" } elseif ($_.Host) { "Host" } else { "N/A" }
                UserName = $_.UserName
                FullFormattedMessage = $_.FullFormattedMessage
                Datacenter = if ($_.Datacenter) { $_.Datacenter.Name } else { "N/A" }
                ComputeResource = if ($_.ComputeResource) { $_.ComputeResource.Name } else { "N/A" }
            }
        }
    }
    catch {
        Write-Warning "Failed to collect events: $($_.Exception.Message)"
        return @()
    }
}

function Get-PerformanceData {
    param($Entity, $MetricName, $DaysBack)
    try {
        $startTime = (Get-Date).AddDays(-$DaysBack)
        # Get data for the last 24 hours for a more relevant average
        $stats = Get-Stat -Entity $Entity -Stat $MetricName -Start $startTime.AddHours(-24) -ErrorAction SilentlyContinue
        if ($stats) {
            $avg = ($stats | Measure-Object -Property Value -Average).Average
            return [math]::Round($avg, 2)
        }
    }
    catch {
        Write-Verbose "Failed to get performance data for $($Entity.Name): $($_.Exception.Message)"
    }
    return "N/A"
}

function Generate-HtmlReport {
    param($inventoryData, $reportDir, $vCenterServer)

    $htmlPath = Join-Path $reportDir "VMware_Inventory_Summary.html"
    $styles = @"
<style>
    body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 20px; }
    h1, h2 { color: #004a87; }
    h1 { font-size: 24px; }
    h2 { font-size: 20px; border-bottom: 2px solid #ccc; padding-bottom: 5px; margin-top: 30px; }
    table { border-collapse: collapse; width: 95%; margin-top: 15px; box-shadow: 0 2px 5px rgba(0,0,0,0.1); }
    th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
    th { background-color: #0078d4; color: white; font-weight: bold; }
    tr:nth-child(even) { background-color: #f2f2f2; }
    .summary { background-color: #eef; padding: 15px; border-left: 5px solid #0078d4; margin-bottom: 20px; }
</style>
"@
    
    $header = "<html><head><title>VMware Inventory Report - $vCenterServer</title>$styles</head><body>"
    $header += "<h1>VMware Inventory Report</h1>"
    $header += "<div class='summary'><strong>vCenter:</strong> $vCenterServer<br><strong>Report Date:</strong> $(Get-Date)</div>"
    
    $body = ""
    $inventoryData.GetEnumerator() | ForEach-Object {
        if ($_.Value -and $_.Value.Count -gt 0) {
            $body += "<h2>$($_.Key)</h2>"
            $body += $_.Value | ConvertTo-Html -Fragment
        }
    }

    $footer = "</body></html>"
    $header + $body + $footer | Out-File -FilePath $htmlPath -Encoding UTF8
}
#endregion

#region Connect to vCenter
Write-Progress-Custom -Activity "VMware Inventory" -Status "Connecting to vCenter Server: $vCenterServer" -PercentComplete 5

try {
    if ($Credential) {
        $connection = Connect-VIServer -Server $vCenterServer -Credential $Credential -ErrorAction Stop
    } else {
        $connection = Connect-VIServer -Server $vCenterServer -ErrorAction Stop
    }
    Write-Host "Successfully connected to vCenter: $($connection.Name)" -ForegroundColor Green
}
catch {
    Write-Error "Failed to connect to vCenter Server '$vCenterServer': $($_.Exception.Message)"
    exit 1
}
#endregion

#region Collect vCenter Information
Write-Progress-Custom -Activity "VMware Inventory" -Status "Collecting vCenter Information" -PercentComplete 10

try {
    $vCenterInfo = Get-View ServiceInstance
    $inventoryData.vCenterInfo = @([PSCustomObject]@{
        Name = $connection.Name
        Version = $vCenterInfo.Content.About.Version
        Build = $vCenterInfo.Content.About.Build
        FullName = $vCenterInfo.Content.About.FullName
        InstanceUuid = $vCenterInfo.Content.About.InstanceUuid
        ApiVersion = $vCenterInfo.Content.About.ApiVersion
        ProductLineId = $vCenterInfo.Content.About.ProductLineId
        CollectionTime = Get-Date
    })
    Write-Host "vCenter information collected" -ForegroundColor Green
}
catch {
    Write-Warning "Failed to collect vCenter information: $($_.Exception.Message)"
}
#endregion

#region Collect Licensing Information
Write-Progress-Custom -Activity "VMware Inventory" -Status "Collecting Licensing Information" -PercentComplete 15

try {
    $licenseManager = Get-View $vCenterInfo.Content.LicenseManager
    $inventoryData.Licensing = $licenseManager.Licenses | ForEach-Object {
        [PSCustomObject]@{
            Name = $_.Name
            LicenseKey = $_.LicenseKey
            EditionKey = $_.EditionKey
            Total = $_.Total
            Used = $_.Used
            CostUnit = $_.CostUnit
            Labels = ($_.Labels | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join "; "
        }
    }
    Write-Host "Licensing information collected" -ForegroundColor Green
}
catch {
    Write-Warning "Failed to collect licensing information: $($_.Exception.Message)"
}
#endregion

#region Collect Cluster Information
Write-Progress-Custom -Activity "VMware Inventory" -Status "Collecting Cluster Information" -PercentComplete 20

try {
    $clusters = Get-Cluster
    if ($clusters) {
        $inventoryData.Clusters = $clusters | ForEach-Object {
            $cluster = $_
            $clusterView = $cluster | Get-View
            
            [PSCustomObject]@{
                Name = $cluster.Name
                HAEnabled = $cluster.HAEnabled
                HAFailoverLevel = $cluster.HAFailoverLevel
                HAAdmissionControlEnabled = $cluster.HAAdmissionControlEnabled
                DrsEnabled = $cluster.DrsEnabled
                DrsAutomationLevel = $cluster.DrsAutomationLevel
                EVCMode = $cluster.EVCMode
                TotalCpuMhz = $clusterView.Summary.TotalCpu
                TotalMemoryGB = [math]::Round($clusterView.Summary.TotalMemory / 1GB, 2)
                NumCpuCores = $clusterView.Summary.NumCpuCores
                NumCpuThreads = $clusterView.Summary.NumCpuThreads
                NumHosts = $clusterView.Summary.NumHosts
                NumEffectiveHosts = $clusterView.Summary.NumEffectiveHosts
                OverallStatus = $clusterView.Summary.OverallStatus
                CurrentFailoverLevel = $clusterView.Summary.CurrentFailoverLevel
            }
        }
        Write-Host "Cluster information collected for $($clusters.Count) clusters" -ForegroundColor Green
    } else {
        Write-Host "No clusters found." -ForegroundColor Green
    }
}
catch {
    Write-Warning "Failed to collect cluster information: $($_.Exception.Message)"
}
#endregion

#region Collect Inventory Data using Modules
Write-Progress-Custom -Activity "VMware Inventory" -Status "Collecting Host Information" -PercentComplete 30
Collect-HostInformation -inventoryData $inventoryData

Write-Progress-Custom -Activity "VMware Inventory" -Status "Collecting Virtual Machine Information" -PercentComplete 40
Collect-VMInformation -inventoryData $inventoryData

Write-Progress-Custom -Activity "VMware Inventory" -Status "Collecting Datastore Information" -PercentComplete 50
Collect-DatastoreInformation -inventoryData $inventoryData

Write-Progress-Custom -Activity "VMware Inventory" -Status "Collecting Snapshot Information" -PercentComplete 60
Collect-SnapshotInformation -inventoryData $inventoryData

Write-Progress-Custom -Activity "VMware Inventory" -Status "Collecting Network Information" -PercentComplete 70
Collect-NetworkInformation -inventoryData $inventoryData

Write-Progress-Custom -Activity "VMware Inventory" -Status "Collecting Resource Pool Information" -PercentComplete 75
Collect-ResourcePoolInformation -inventoryData $inventoryData
#endregion

#region Collect Events
Write-Progress-Custom -Activity "VMware Inventory" -Status "Collecting Events" -PercentComplete 80
$inventoryData.Events = Get-VMwareEvents -DaysBack $DaysBack
#endregion

#region Collect Performance Metrics
if ($IncludePerformanceMetrics) {
    Write-Progress-Custom -Activity "VMware Inventory" -Status "Collecting Performance Metrics (this may take a while...)" -PercentComplete 85
    
    # Host Performance
    foreach ($host in $inventoryData.Hosts) {
        $hostEntity = Get-VMHost -Name $host.Name
        $inventoryData.PerformanceMetrics.Add([PSCustomObject]@{
            EntityName = $host.Name
            EntityType = "Host"
            MetricName = "cpu.usage.average"
            Value = Get-PerformanceData -Entity $hostEntity -MetricName "cpu.usage.average" -DaysBack $DaysBack
        })
        $inventoryData.PerformanceMetrics.Add([PSCustomObject]@{
            EntityName = $host.Name
            EntityType = "Host"
            MetricName = "mem.usage.average"
            Value = Get-PerformanceData -Entity $hostEntity -MetricName "mem.usage.average" -DaysBack $DaysBack
        })
    }

    # VM Performance
    foreach ($vm in $inventoryData.VMs) {
        $vmEntity = Get-VM -Name $vm.Name
        $inventoryData.PerformanceMetrics.Add([PSCustomObject]@{
            EntityName = $vm.Name
            EntityType = "VM"
            MetricName = "cpu.usage.average"
            Value = Get-PerformanceData -Entity $vmEntity -MetricName "cpu.usage.average" -DaysBack $DaysBack
        })
        $inventoryData.PerformanceMetrics.Add([PSCustomObject]@{
            EntityName = $vm.Name
            EntityType = "VM"
            MetricName = "mem.usage.average"
            Value = Get-PerformanceData -Entity $vmEntity -MetricName "mem.usage.average" -DaysBack $DaysBack
        })
    }
    Write-Host "Performance metrics collected for $($inventoryData.Hosts.Count) hosts and $($inventoryData.VMs.Count) VMs" -ForegroundColor Green
}
#endregion

#region Generate Reports and Complete Script
Write-Progress-Custom -Activity "VMware Inventory" -Status "Generating Reports" -PercentComplete 95

# Export data based on format selection
if ($ExportFormat -eq "CSV" -or $ExportFormat -eq "All") {
    Write-Host "Generating CSV reports..." -ForegroundColor Yellow
    
    $inventoryData.GetEnumerator() | ForEach-Object {
        if ($_.Value -and $_.Value.Count -gt 0) {
            $csvPath = Join-Path $reportDir "$($_.Key).csv"
            $_.Value | Export-Csv -Path $csvPath -NoTypeInformation -UseCulture
            Write-Host "  - $($_.Key).csv created" -ForegroundColor Green
        }
    }
}

if ($ExportFormat -eq "JSON" -or $ExportFormat -eq "All") {
    Write-Host "Generating JSON report..." -ForegroundColor Yellow
    $jsonPath = Join-Path $reportDir "VMware_Inventory_Complete.json"
    $inventoryData | ConvertTo-Json -Depth 10 | Out-File -FilePath $jsonPath -Encoding UTF8
    Write-Host "  - VMware_Inventory_Complete.json created" -ForegroundColor Green
}

if ($ExportFormat -eq "HTML" -or $ExportFormat -eq "All") {
    Write-Host "Generating HTML report..." -ForegroundColor Yellow
    Generate-HtmlReport -inventoryData $inventoryData -reportDir $reportDir -vCenterServer $vCenterServer
    Write-Host "  - VMware_Inventory_Summary.html created" -ForegroundColor Green
}

$endTime = Get-Date
$duration = New-TimeSpan -Start $startTime -End $endTime

Write-Host "=" * 80 -ForegroundColor Cyan
Write-Host "VMware Infrastructure Inventory Complete!" -ForegroundColor Green
Write-Host "Reports saved to: $reportDir" -ForegroundColor Yellow
Write-Host "Completed at: $endTime" -ForegroundColor Green
Write-Host "Total execution time: $($duration.Hours)h $($duration.Minutes)m $($duration.Seconds)s" -ForegroundColor Green
Write-Host "=" * 80 -ForegroundColor Cyan

# Disconnect from vCenter
try {
    Disconnect-VIServer -Server * -Force -Confirm:$false
    Write-Host "Disconnected from vCenter" -ForegroundColor Green
}
catch {
    Write-Warning "Failed to disconnect from vCenter: $($_.Exception.Message)"
}
#endregion

<#
.SYNOPSIS
    VMware Data Collection Modules - Comprehensive inventory functions

.DESCRIPTION
    This module contains specialized data collection functions for VMware infrastructure inventory.
    Functions are optimized for performance and modularity.

    Available Functions:
    - Collect-HostInformation: Gathers detailed ESXi host information
    - Collect-VMInformation: Collects comprehensive VM data
    - Collect-DatastoreInformation: Retrieves datastore capacity and usage
    - Collect-SnapshotInformation: Identifies and reports on VM snapshots
    - Collect-NetworkInformation: Collects network configuration data
    - Collect-ResourcePoolInformation: Gathers resource pool settings

.EXAMPLE
    Import-Module .\VMware-DataCollection-Modules.ps1
    $inventoryData = @{}
    Collect-HostInformation -inventoryData $inventoryData

.EXAMPLE
    # Collect all inventory data
    $inventoryData = [ordered]@{
        Hosts = @()
        VMs = @()
        Datastores = @()
    }
    Collect-HostInformation -inventoryData $inventoryData
    Collect-VMInformation -inventoryData $inventoryData
    Collect-DatastoreInformation -inventoryData $inventoryData

.NOTES
    Author: System Administrator
    Date: 2025-10-28
    Requires: VMware PowerCLI module
    Version: 2.1

    This module is designed to be imported by VMware-DeepDive-Inventory.ps1
#>

#region Collect Host Information
function Collect-HostInformation {
    param(
        [Parameter(Mandatory=$true)]
        $inventoryData
    )
    
    try {
        # Get all hosts and their views once to reduce API calls
        $vmHosts = Get-VMHost
        $inventoryData.Hosts = $vmHosts | ForEach-Object {
            $vmHost = $_
            $hostView = $vmHost | Get-View
            $hardware = $hostView.Hardware
            
            # Get network information
            $nics = $vmHost | Get-VMHostNetworkAdapter | Where-Object { $_.Name -like "vmnic*" }
            
            # Get storage information
            $datastores = $vmHost | Get-Datastore
            $hbas = $vmHost | Get-VMHostHba
            
            [PSCustomObject]@{
                Name = $vmHost.Name
                ConnectionState = $vmHost.ConnectionState
                PowerState = $vmHost.PowerState
                Version = $vmHost.Version
                Build = $vmHost.Build
                Manufacturer = $hardware.SystemInfo.Vendor
                Model = $hardware.SystemInfo.Model
                ProcessorType = $hardware.CpuPkg[0].Description
                NumCpuPackages = $hardware.CpuInfo.NumCpuPackages
                NumCpuCores = $hardware.CpuInfo.NumCpuCores
                NumCpuThreads = $hardware.CpuInfo.NumCpuThreads
                CpuTotalMhz = [math]::Round($hardware.CpuInfo.Hz / 1MB, 0)
                CpuUsageMhz = $vmHost.CpuUsageMhz
                MemoryTotalGB = [math]::Round($vmHost.MemoryTotalGB, 2)
                MemoryUsageGB = [math]::Round($vmHost.MemoryUsageGB, 2)
                MemoryUsagePercent = if ($vmHost.MemoryTotalGB -gt 0) { [math]::Round(($vmHost.MemoryUsageGB / $vmHost.MemoryTotalGB) * 100, 1) } else { 0 }
                NumNics = $nics.Count
                NumHBAs = $hbas.Count
                NumDatastores = $datastores.Count
                Cluster = if ($vmHost.Parent) { $vmHost.Parent.Name } else { "N/A" }
                Datacenter = (Get-Datacenter -VMHost $vmHost).Name
                MaintenanceMode = $vmHost.ExtensionData.Runtime.InMaintenanceMode
                BootTime = $vmHost.ExtensionData.Runtime.BootTime
                Uptime = if ($vmHost.ExtensionData.Runtime.BootTime) { 
                    [math]::Round((New-TimeSpan -Start $vmHost.ExtensionData.Runtime.BootTime -End (Get-Date)).TotalDays, 1) 
                } else { "Unknown" }
                LicenseKey = $vmHost.LicenseKey
                MaxEVCMode = $vmHost.MaxEVCMode
                HyperthreadingActive = $hostView.Config.HyperThread.Active
                NumVMs = ($vmHost | Get-VM).Count
            }
        }
        Write-Host "Host information collected for $($vmHosts.Count) hosts" -ForegroundColor Green
    }
    catch {
        Write-Warning "Failed to collect host information: $($_.Exception.Message)"
    }
}
#endregion

#region Collect VM Information
function Collect-VMInformation {
    param(
        [Parameter(Mandatory=$true)]
        $inventoryData
    )
    
    try {
        $vms = Get-VM
        $inventoryData.VMs = $vms | ForEach-Object {
            $vm = $_
            
            # Get VMware Tools information
            $toolsStatus = $vm.ExtensionData.Guest.ToolsStatus
            $toolsVersion = $vm.ExtensionData.Guest.ToolsVersion
            $toolsRunningStatus = $vm.ExtensionData.Guest.ToolsRunningStatus
            
            # Get network information
            $networkAdapters = $vm | Get-NetworkAdapter
            $ipAddresses = $vm.Guest.IPAddress | Where-Object { $_ -and $_ -ne "127.0.0.1" -and $_ -notlike "fe80:*" }
            
            # Get storage information
            $hardDisks = $vm | Get-HardDisk
            $totalDiskGB = ($hardDisks | Measure-Object -Property CapacityGB -Sum).Sum
            
            # Get snapshot information
            $snapshots = $vm | Get-Snapshot
            
            [PSCustomObject]@{
                Name = $vm.Name
                PowerState = $vm.PowerState
                GuestOS = $vm.Guest.OSFullName
                ConfiguredOS = $vm.ExtensionData.Config.GuestFullName
                NumCpu = $vm.NumCpu
                CoresPerSocket = $vm.CoresPerSocket
                MemoryGB = [math]::Round($vm.MemoryGB, 2)
                ProvisionedSpaceGB = [math]::Round($vm.ProvisionedSpaceGB, 2)
                UsedSpaceGB = [math]::Round($vm.UsedSpaceGB, 2)
                TotalDiskGB = [math]::Round($totalDiskGB, 2)
                NumHardDisks = $hardDisks.Count
                NumNetworkAdapters = $networkAdapters.Count
                IPAddresses = ($ipAddresses -join "; ")
                MacAddresses = (($networkAdapters | ForEach-Object { $_.MacAddress }) -join "; ")
                NetworkNames = (($networkAdapters | ForEach-Object { $_.NetworkName }) -join "; ")
                VMHost = if ($vm.VMHost) { $vm.VMHost.Name } else { "N/A" }
                Cluster = if ($vm.VMHost.Parent) { $vm.VMHost.Parent.Name } else { "N/A" }
                Datacenter = (Get-Datacenter -VM $vm).Name
                Datastore = (($vm | Get-Datastore) | ForEach-Object { $_.Name }) -join "; "
                Folder = if ($vm.Folder) { $vm.Folder.Name } else { "N/A" }
                ResourcePool = if ($vm.ResourcePool) { $vm.ResourcePool.Name } else { "N/A" }
                VMwareToolsStatus = $toolsStatus
                VMwareToolsVersion = $toolsVersion
                VMwareToolsRunningStatus = $toolsRunningStatus
                VMwareToolsUpgradePolicy = $vm.ExtensionData.Config.Tools.ToolsUpgradePolicy
                HardwareVersion = $vm.HardwareVersion
                CreateDate = $vm.CreateDate
                SnapshotCount = $snapshots.Count
                OldestSnapshotDate = if ($snapshots) { ($snapshots | Sort-Object Created)[0].Created } else { $null }
                NewestSnapshotDate = if ($snapshots) { ($snapshots | Sort-Object Created -Descending)[0].Created } else { $null }
                CBTEnabled = $vm.ExtensionData.Config.ChangeTrackingEnabled
                FaultToleranceState = $vm.ExtensionData.Runtime.FaultToleranceState
                Template = $vm.ExtensionData.Config.Template
                Annotation = $vm.Notes
                CpuReservation = $vm.ExtensionData.Config.CpuAllocation.Reservation
                MemoryReservation = $vm.ExtensionData.Config.MemoryAllocation.Reservation
                CpuLimit = $vm.ExtensionData.Config.CpuAllocation.Limit
                MemoryLimit = $vm.ExtensionData.Config.MemoryAllocation.Limit
            }
        }
        Write-Host "VM information collected for $($vms.Count) virtual machines" -ForegroundColor Green
    }
    catch {
        Write-Warning "Failed to collect VM information: $($_.Exception.Message)"
    }
}
#endregion

#region Collect Datastore Information
function Collect-DatastoreInformation {
    param(
        [Parameter(Mandatory=$true)]
        $inventoryData
    )
    
    try {
        $datastores = Get-Datastore
        $inventoryData.Datastores = $datastores | ForEach-Object {
            $datastore = $_
            $dsView = $datastore | Get-View
            
            # Calculate usage percentages
            $freeSpacePercent = if ($datastore.CapacityGB -gt 0) { [math]::Round(($datastore.FreeSpaceGB / $datastore.CapacityGB) * 100, 1) } else { 0 }
            $usedSpacePercent = 100 - $freeSpacePercent
            
            # Get connected hosts
            $connectedHosts = $datastore | Get-VMHost
            
            # Get VMs on this datastore
            $vmsOnDatastore = Get-VM -Datastore $datastore
            
            [PSCustomObject]@{
                Name = $datastore.Name
                Type = $datastore.Type
                FileSystemVersion = $datastore.FileSystemVersion
                CapacityGB = [math]::Round($datastore.CapacityGB, 2)
                FreeSpaceGB = [math]::Round($datastore.FreeSpaceGB, 2)
                UsedSpaceGB = [math]::Round(($datastore.CapacityGB - $datastore.FreeSpaceGB), 2)
                FreeSpacePercent = $freeSpacePercent
                UsedSpacePercent = $usedSpacePercent
                Accessible = $datastore.Accessible
                State = $datastore.State
                ConnectedHosts = $connectedHosts.Count
                HostNames = ($connectedHosts.Name -join "; ")
                NumVMs = $vmsOnDatastore.Count
                VMNames = ($vmsOnDatastore.Name | Sort-Object | Select-Object -First 10) -join "; "
                Datacenter = (Get-Datacenter -Datastore $datastore).Name
                StorageIOControlEnabled = $dsView.IormConfiguration.Enabled
                CongestionThreshold = $dsView.IormConfiguration.CongestionThreshold
                Url = $datastore.ExtensionData.Info.Url
                Uuid = if ($datastore.ExtensionData.Info.Vmfs) { $datastore.ExtensionData.Info.Vmfs.Uuid } else { "N/A" }
                BlockSizeMB = if ($datastore.ExtensionData.Info.Vmfs) { $datastore.ExtensionData.Info.Vmfs.BlockSizeMB } else { "N/A" }
                MaxFileSize = if ($datastore.ExtensionData.Info.Vmfs) { $datastore.ExtensionData.Info.Vmfs.MaxFileSize } else { "N/A" }
            }
        }
        Write-Host "Datastore information collected for $($datastores.Count) datastores" -ForegroundColor Green
    }
    catch {
        Write-Warning "Failed to collect datastore information: $($_.Exception.Message)"
    }
}
#endregion

#region Collect Snapshot Information
function Collect-SnapshotInformation {
    param(
        [Parameter(Mandatory=$true)]
        $inventoryData
    )
    
    try {
        $allSnapshots = Get-VM | Get-Snapshot
        if ($allSnapshots) {
            $inventoryData.Snapshots = $allSnapshots | ForEach-Object {
                $snapshot = $_
                $ageInDays = [math]::Round((New-TimeSpan -Start $snapshot.Created -End (Get-Date)).TotalDays, 1)
                
                [PSCustomObject]@{
                    VMName = $snapshot.VM.Name
                    SnapshotName = $snapshot.Name
                    Description = $snapshot.Description
                    Created = $snapshot.Created
                    AgeInDays = $ageInDays
                    SizeGB = [math]::Round($snapshot.SizeGB, 2)
                    IsCurrent = $snapshot.IsCurrent
                    ParentSnapshot = $snapshot.ParentSnapshot
                    ChildSnapshots = ($snapshot.ChildSnapshots.Name -join "; ")
                    PowerState = $snapshot.PowerState
                    VMHost = $snapshot.VM.VMHost.Name
                    Cluster = $snapshot.VM.VMHost.Parent.Name
                    Datacenter = (Get-Datacenter -VM $snapshot.VM).Name
                    Datastore = (($snapshot.VM | Get-Datastore).Name -join "; ")
                }
            }
            Write-Host "Snapshot information collected for $($allSnapshots.Count) snapshots" -ForegroundColor Green
        } else {
            Write-Host "No snapshots found." -ForegroundColor Green
            $inventoryData.Snapshots = @()
        }
    }
    catch {
        Write-Warning "Failed to collect snapshot information: $($_.Exception.Message)"
    }
}
#endregion

#region Collect Network Information
function Collect-NetworkInformation {
    param(
        [Parameter(Mandatory=$true)]
        $inventoryData
    )
    
    try {
        # Performance Improvement: Get all VM network adapters once and group them for efficient lookup.
        $vmAdaptersByNetwork = Get-VM | Get-NetworkAdapter | Group-Object -Property NetworkName -AsHashTable -AsString

        # Standard Port Groups
        $portGroups = Get-VirtualPortGroup
        # Distributed Port Groups
        $dvPortGroups = Get-VDPortgroup -ErrorAction SilentlyContinue
        
        $networkData = [System.Collections.Generic.List[psobject]]::new()
        
        # Process Standard Port Groups
        $portGroups | ForEach-Object {
            $pg = $_
            $networkData.Add([PSCustomObject]@{
                Name = $pg.Name
                Type = "Standard Port Group"
                VLanId = $pg.VLanId
                VirtualSwitch = $pg.VirtualSwitch.Name
                ActiveNics = ($pg.VirtualSwitch.Nic -join "; ")
                NumPorts = if ($pg.Port) { $pg.Port.Count } else { 0 }
                ConnectedVMs = if ($vmAdaptersByNetwork.ContainsKey($pg.Name)) { $vmAdaptersByNetwork[$pg.Name].Count } else { 0 }
                VMHost = $pg.VMHost.Name
                Cluster = $pg.VMHost.Parent.Name
            })
        }
        
        # Process Distributed Port Groups
        if ($dvPortGroups) {
            $dvPortGroups | ForEach-Object {
                $dvpg = $_
                $networkData.Add([PSCustomObject]@{
                    Name = $dvpg.Name
                    Type = "Distributed Port Group"
                    VLanId = $dvpg.VlanConfiguration.VlanId
                    VirtualSwitch = $dvpg.VDSwitch.Name
                    ActiveNics = "Distributed"
                    NumPorts = $dvpg.NumPorts
                    ConnectedVMs = if ($vmAdaptersByNetwork.ContainsKey($dvpg.Name)) { $vmAdaptersByNetwork[$dvpg.Name].Count } else { 0 }
                    VMHost = "Multiple"
                    Cluster = "Multiple"
                })
            }
        }
        
        $inventoryData.Networks = $networkData
        Write-Host "Network information collected for $($networkData.Count) networks" -ForegroundColor Green
    }
    catch {
        Write-Warning "Failed to collect network information: $($_.Exception.Message)"
    }
}
#endregion

#region Collect Resource Pool Information
function Collect-ResourcePoolInformation {
    param(
        [Parameter(Mandatory=$true)]
        $inventoryData
    )
    
    try {
        $resourcePools = Get-ResourcePool
        $inventoryData.ResourcePools = $resourcePools | ForEach-Object {
            $rp = $_
            $rpView = $rp | Get-View
            
            [PSCustomObject]@{
                Name = $rp.Name
                Parent = if ($rp.Parent) { $rp.Parent.Name } else { "N/A" }
                CpuReservationMhz = $rpView.Config.CpuAllocation.Reservation
                CpuLimitMhz = $rpView.Config.CpuAllocation.Limit
                CpuExpandableReservation = $rpView.Config.CpuAllocation.ExpandableReservation
                CpuShares = $rpView.Config.CpuAllocation.Shares.Shares
                CpuSharesLevel = $rpView.Config.CpuAllocation.Shares.Level
                MemoryReservationMB = $rpView.Config.MemoryAllocation.Reservation
                MemoryLimitMB = $rpView.Config.MemoryAllocation.Limit
                MemoryExpandableReservation = $rpView.Config.MemoryAllocation.ExpandableReservation
                MemoryShares = $rpView.Config.MemoryAllocation.Shares.Shares
                MemorySharesLevel = $rpView.Config.MemoryAllocation.Shares.Level
                NumVMs = ($rp | Get-VM).Count
                NumChildResourcePools = if ($rpView.ResourcePool) { $rpView.ResourcePool.Count } else { 0 }
                OverallStatus = $rpView.OverallStatus
            }
        }
        Write-Host "Resource pool information collected for $($resourcePools.Count) resource pools" -ForegroundColor Green
    }
    catch {
        Write-Warning "Failed to collect resource pool information: $($_.Exception.Message)"
    }
}
#endregion

# Export functions for use in main script
Export-ModuleMember -Function Collect-HostInformation, Collect-VMInformation, Collect-DatastoreInformation, Collect-SnapshotInformation, Collect-NetworkInformation, Collect-ResourcePoolInformation

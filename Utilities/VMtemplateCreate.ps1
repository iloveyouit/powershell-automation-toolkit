<#
.SYNOPSIS
    Creates a new VMware VM template from an ISO image.

.DESCRIPTION
    This script automates the creation of VMware VM templates by:
    - Creating a new VM with specified hardware configuration
    - Mounting an ISO for OS installation
    - Installing VMware Tools
    - Converting the VM to a template

    The script requires an active connection to vCenter/ESXi (use Connect-VIServer first).

.PARAMETER TemplateName
    Name for the new template (must be unique)

.PARAMETER Datastore
    Datastore where the template will be stored

.PARAMETER VMHost
    ESXi host where the template will be created

.PARAMETER GuestCredential
    Credentials for the guest OS (required for VMware Tools installation)

.PARAMETER Network
    Network to connect to (default: "VM Network")

.PARAMETER ISOFileName
    Name of the ISO file in the datastore (default: "en_windows_server_2019.iso")

.PARAMETER ISOFolderName
    Folder name in datastore containing ISOs (default: "ISOs")

.PARAMETER VMGuestOS
    Guest OS identifier for VMware (default: "windows9Server64Guest")

.PARAMETER NumCPU
    Number of virtual CPUs (default: 2)

.PARAMETER MemoryGB
    Memory in GB (default: 4)

.PARAMETER BootWaitTime
    Time to wait for boot and VMware Tools (default: 180 seconds)

.EXAMPLE
    Connect-VIServer -Server "192.168.0.171"
    $guestCred = Get-Credential -Message "Enter guest OS credentials"
    .\VMtemplateCreate.ps1 -TemplateName "Win2019-Template" -Datastore "datastore1" -VMHost "esxi01.company.com" -GuestCredential $guestCred

    Creates a Windows Server 2019 template with default settings.

.EXAMPLE
    $guestCred = Get-Credential
    .\VMtemplateCreate.ps1 -TemplateName "Ubuntu-20.04-Template" -Datastore "SSD-Datastore" -VMHost "192.168.0.171" -GuestCredential $guestCred -ISOFileName "ubuntu-20.04-server.iso" -VMGuestOS "ubuntu64Guest" -NumCPU 4 -MemoryGB 8

    Creates an Ubuntu template with custom CPU/memory configuration.

.EXAMPLE
    .\VMtemplateCreate.ps1 -TemplateName "Win2022-Template" -Datastore "datastore1" -VMHost "esxi01" -GuestCredential $cred -Network "Production-VLAN10" -BootWaitTime 300

    Creates template on specific network with extended boot wait time.

.NOTES
    Author: System Administrator
    Date: 2025-10-28
    Requires: VMware PowerCLI module and active vCenter connection
    Version: 2.0

    Prerequisites:
    - ISO file must be uploaded to specified datastore folder
    - Sufficient datastore space for VM creation
    - Valid guest OS credentials for VMware Tools installation
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$TemplateName,

    [Parameter(Mandatory = $true)]
    [string]$Datastore,

    [Parameter(Mandatory = $true)]
    [string]$VMHost,

    [Parameter(Mandatory = $true)]
    [PSCredential]$GuestCredential,

    [Parameter(Mandatory = $false)]
    [string]$Network = "VM Network",

    [Parameter(Mandatory = $false)]
    [string]$ISOFileName = "en_windows_server_2019.iso",

    [Parameter(Mandatory = $false)]
    [string]$ISOFolderName = "ISOs",

    [Parameter(Mandatory = $false)]
    [string]$VMGuestOS = "windows9Server64Guest",

    [Parameter(Mandatory = $false)]
    [int]$NumCPU = 2,

    [Parameter(Mandatory = $false)]
    [int]$MemoryGB = 4,

    [Parameter(Mandatory = $false)]
    [int]$BootWaitTime = 180
)

# Error handling preference
$ErrorActionPreference = "Stop"

try {
    # Verify VMware PowerCLI is available
    if (!(Get-Module -Name VMware.PowerCLI -ListAvailable)) {
        throw "VMware PowerCLI module is not installed. Please install it using: Install-Module -Name VMware.PowerCLI -Scope CurrentUser"
    }

    # Verify connection to vCenter/ESXi
    if (!(Get-View ServiceInstance)) {
        throw "Not connected to vCenter/ESXi. Please connect using Connect-VIServer before running this script."
    }

    Write-Verbose "Checking for ISO file..."
    # Get the ISO file path from the datastore folder
    $WindowsISOPath = Get-Datastore $Datastore | 
        Get-DatastoreFolder -Name $ISOFolderName -ErrorAction SilentlyContinue | 
        Get-DatastoreFile -Name $ISOFileName -ErrorAction SilentlyContinue

    if (-not $WindowsISOPath) {
        throw "ISO file '$ISOFileName' not found in '$ISOFolderName' folder in '$Datastore'."
    }

    Write-Verbose "Creating new VM..."
    # Create a new VM with splatting
    $VMParams = @{
        Name = $TemplateName
        Datastore = $Datastore
        NumCpu = $NumCPU
        MemoryGB = $MemoryGB
        NetworkName = $Network
        CD = $true
        ISOPath = $WindowsISOPath.DatastoreFullPath
        VMHost = $VMHost
        GuestId = $VMGuestOS
        Notes = "Template created on $(Get-Date -Format 'yyyy-MM-dd') by $env:USERNAME"
        DiskGB = 60  # Added default disk size
    }

    # Check if VM name already exists
    if (Get-VM -Name $TemplateName -ErrorAction SilentlyContinue) {
        throw "VM or template with name '$TemplateName' already exists."
    }

    $NewVM = New-VM @VMParams

    # Configure additional hardware settings
    Write-Verbose "Configuring VM hardware..."
    Get-VM -Name $TemplateName | Get-NetworkAdapter | Set-NetworkAdapter -Type Vmxnet3 -Confirm:$false
    Get-VM -Name $TemplateName | Get-HardDisk | Set-HardDisk -StorageFormat Thin -Confirm:$false

    Write-Verbose "Starting VM..."
    # Power on the VM
    Start-VM -VM $NewVM

    Write-Verbose "Waiting for VM to boot... ($BootWaitTime seconds)"
    # Wait for VMware Tools to be running
    $timeout = (Get-Date).AddSeconds($BootWaitTime)
    do {
        $toolsStatus = (Get-VM -Name $TemplateName).ExtensionData.Guest.ToolsStatus
        if ((Get-Date) -gt $timeout) {
            throw "Timeout waiting for VMware Tools to start"
        }
        Start-Sleep -Seconds 10
    } while ($toolsStatus -ne 'toolsOk')

    Write-Verbose "Installing VMware Tools..."
    # Install VMware Tools
    $Script = 'D:\setup.exe /S /v"/qn reboot=r"'
    $ScriptParams = @{
        VM = $NewVM
        GuestCredential = $GuestCredential
        ScriptType = "Bat"
        ScriptText = $Script
    }
    
    Invoke-VMScript @ScriptParams

    Write-Verbose "Waiting for VMware Tools installation to complete..."
    Start-Sleep -Seconds 60

    Write-Verbose "Shutting down VM..."
    # Shutdown the VM gracefully
    Shutdown-VMGuest -VM $NewVM -Confirm:$false
    
    # Wait for VM to power off
    Wait-VMPowerState -VM $NewVM -State PoweredOff -Timeout 300

    Write-Verbose "Converting VM to template..."
    # Convert to template
    Set-VM -VM $NewVM -ToTemplate -Confirm:$false

    Write-Host "Template creation completed successfully!" -ForegroundColor Green
}
catch {
    Write-Error "Error creating template: $_"
    # Cleanup if VM exists but failed during creation
    if ($NewVM) {
        Write-Verbose "Cleaning up failed template creation..."
        if (Get-VM -Name $NewVM.Name -ErrorAction SilentlyContinue) {
            Stop-VM -VM $NewVM -Confirm:$false -ErrorAction SilentlyContinue
            Remove-VM -VM $NewVM -Confirm:$false -ErrorAction SilentlyContinue
        }
    }
    throw
} 
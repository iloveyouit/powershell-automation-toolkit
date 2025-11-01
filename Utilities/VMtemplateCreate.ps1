# Script parameters
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
    
    [string]$Network = "VM Network",
    [string]$ISOFileName = "en_windows_server_2019.iso",
    [string]$ISOFolderName = "ISOs",
    [string]$VMGuestOS = "windows9Server64Guest",
    [int]$NumCPU = 2,
    [int]$MemoryGB = 4,
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
#Connect-VIServer -Server "192.168.0.171" -User "root" -Password "#*"

$cred = Get-Credential
Connect-VIServer -Server "192.168.0.171" -Credential $cred

Get-VMHost "192.168.0.171"

Set-VMHost -VMHost "192.168.0.171" -State Maintenance
Set-VMHost -VMHost "192.168.0.171" -State Connected

Get-VMHost -Name "192.168.0.171" | Select-Object Name, ConnectionState

Get-VMHost -Name "192.168.0.171" | Select-Object Name, ConnectionState, @{Name="MaintenanceMode";Expression={$_.ConnectionState -eq "Maintenance"}}

Get-VMHost -Name "192.168.0.171" | Select-Object Name, ConnectionState

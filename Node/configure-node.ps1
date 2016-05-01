﻿<#
.Synopsis
   Short description
.DESCRIPTION
   labbuildr is a Self Installing Windows/Networker/NMM Environemnt Supporting Exchange 2013 and NMM 3.0
.LINK
   https://community.emc.com/blogs/bottk/2015/03/30/labbuildrbeta
#>
#requires -version 3
[CmdletBinding()]
param(
    $nodeIP,
    $nodename,
    $IPv4Subnet = "192.168.2",
    $IPv6Subnet,
    [ValidateSet('24')]$IPv4PrefixLength = '24',
    $IPv6Prefix = "",
    [ValidateSet('8','24','32','48','64')]$IPv6PrefixLength = '8',
    [Validateset('IPv4','IPv6','IPv4IPv6')]$AddressFamily,
    $AddonFeatures,
    [ipaddress]$DefaultGateway,
    $Domain="labbuildr",
    $domainsuffix = ".local",
    $Scriptdir = "\\vmware-host\Shared Folders\Scripts",
    $SourcePath = "\\vmware-host\Shared Folders\Sources",
    $logpath = "c:\Scripts"
)
$Nodescriptdir = "$Scriptdir\Node"
$ScriptName = $MyInvocation.MyCommand.Name
$Host.UI.RawUI.WindowTitle = "$ScriptName"
$Builddir = $PSScriptRoot
$Logtime = Get-Date -Format "MM-dd-yyyy_hh-mm-ss"
if (!(Test-Path $logpath))
    {
    New-Item -ItemType Directory -Path $logpath -Force
    }
$Logfile = New-Item -ItemType file  "$logpath\$ScriptName$Logtime.log"
Set-Content -Path $Logfile -Value "$($MyInvocation.BoundParameters)"
$Addonfeatures = $Addonfeatures.Replace(" ","")
$Features = $AddonFeatures.split(",")
$IPv6subnet = "$IPv6Prefix$IPv4Subnet"
$IPv6Address = "$IPv6Prefix$nodeIP"
Set-Content -Path $Logfile -Value "$nodeIP, $IPv4Subnet, $nodename"
Write-Verbose $IPv6PrefixLength
Write-Verbose $IPv6Address
Write-Verbose $IPv6subnet
Write-Verbose $AddonFeatures

<# checking uefi or Normal Machine dirty hack
if ($eth0 = Get-NetAdapter -Name "Ethernet0" -ErrorAction SilentlyContinue) {
[switch]$uefi = $True
}
else
{
$eth0 = Get-NetAdapter -Name "Ethernet" -ErrorAction SilentlyContinue
}
#>
$nics = @()
$Nics = Get-NetAdapter | Sort-Object -Property Name
if ($nics.Count -gt 1)
    { $eth1 = Get-NetIPAddress -PrefixOrigin Dhcp | Get-NetAdapter 
    Rename-NetAdapter $eth1.Name -NewName "External DHCP"
    }

$eth0 = Get-NetIPAddress -AddressFamily IPv4 -PrefixOrigin WellKnown -PrefixLength 16 | Get-NetAdapter

Rename-NetAdapter $eth0.Name -NewName $Domain
 
<#
elseif  ($eth1 = Get-NetAdapter -Name "Ethernet1" -ErrorAction SilentlyContinue ) 
    {
    Rename-NetAdapter $eth0.Name -NewName "External DHCP"
    Rename-NetAdapter $eth1.Name -NewName "Ethernet"
    }

#>

If ($AddressFamily -match 'IPv4')
{

    if ($DefaultGateway)
        {
        New-NetIPAddress -InterfaceAlias "$Domain" -AddressFamily IPv4 –IPAddress "$nodeIP" –PrefixLength $IPv4PrefixLength -DefaultGateway "$DefaultGateway"
        }
    else
        {
        New-NetIPAddress -InterfaceAlias "$Domain"  -AddressFamily IPv4 –IPAddress "$nodeIP" –PrefixLength $IPv4PrefixLength
        }
}
If ($AddressFamily -match 'IPv6')
    {
    if ($DefaultGateway)
        {
        New-NetIPAddress -InterfaceAlias "$Domain" -AddressFamily IPv6 –IPAddress $IPv6Address –PrefixLength $IPv6PrefixLength -DefaultGateway "$IPv6subnet.$(([System.Version]$DefaultGateway.ToString()).revision)"
        }
        else
        {
        New-NetIPAddress -InterfaceAlias "$Domain" -AddressFamily IPv6 –IPAddress $IPv6Address –PrefixLength $IPv6PrefixLength
        }
}

Set-DnsClientServerAddress -InterfaceAlias "$Domain" -ServerAddresses "$IPv4Subnet.10"
if ( $AddressFamily -notmatch 'IPv4')
    {
    $eth0 | Disable-NetAdapterBinding -ComponentID ms_tcpip
    $eth1 | Disable-NetAdapterBinding -ComponentID ms_tcpip
    Set-DnsClientServerAddress -InterfaceAlias "$Domain" -ServerAddresses "$IPv6subnet.10"
    }

Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' -Name fDenyTSConnections -Value 0
Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name UserAuthentication -Value 1
Set-NetFirewallRule -DisplayGroup 'Remote Desktop' -Enabled True
Write-Host "Running Feature Installer"
Get-WindowsFeature $Features | Add-WindowsFeature –IncludeManagementTools
if ($PSCmdlet.MyInvocation.BoundParameters["verbose"].IsPresent)
    {
    Pause
    }
Write-Verbose "trying tools update"
try {
    $CDDrive = Get-Volume -FileSystemLabel "VMware Tools"  -ErrorAction SilentlyContinue
    }
catch [Microsoft.PowerShell.Cmdletization.Cim.CimJobException]
    {
    
    }


if ($CDDrive)
    {
    Write-Warning "Starting Tools Update from $($CDDrive.DriveLetter)" 
    Start-Process "$($CDDrive.DriveLetter):\setup.exe" -ArgumentList "/S /v `"/qn REBOOT=R ADDLOCAL=ALL" -Wait
    }
# Rename-Computer -NewName $nodename
# New-Item -ItemType File -Path c:\scripts\2.pass
# restart-computer
######Newtwork Sanity Check #######
If ($AddressFamily -match "IPv6")
    {
    $subnet = "$IPv6Subnet$IPv4Subnet"
    }
else 
    {
    $subnet = "$IPv4Subnet"
    }

Do {
    $Ping = Test-Connection "$Subnet.10" -ErrorAction SilentlyContinue
    If (!$Ping)
        {
        Write-Warning "Can Not reach Domain Controller with $subnet.10
                        This is most Likely a VMnet Configuration Issue
                        please Fix Network Assignments ( vmnet ) and specify correct Addressfamily"
        Pause
        }
    }
Until ($Ping)    
$Mydomain = "$Domain$domainsuffix"
$PlainPassword = "Password123!" 
$password = $PlainPassword | ConvertTo-SecureString -asPlainText -Force
$username = "$domain\Administrator" 
$credential = New-Object System.Management.Automation.PSCredential($username,$password)
Do {
    $Domain_OK = Add-Computer -DomainName $Mydomain -Credential $credential -PassThru -NewName $Nodename
    If (!$Domain_OK.HasSucceeded)
        {
        Write-Warning "Can Not Join Domain $Domain, please verify and retry
                    Most likely this Computer has not been removed from Domain or Domain needs to refresh
                    Please Check Active Directory Users and Computers on the DC"
        Pause
        }
    }
Until ($Domain_OK.HasSucceeded)
$vmwarehost = "vmware-host"
Write-Host -ForegroundColor Magenta "Setting $vmwarehost as local intranet"
$Zonemaps = ("HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap")
 Foreach ($Zonemap in $Zonemaps)
    {
    Write-Host "Setting $Zonemap for $Host"
    $Ranges = "$Zonemap\Ranges"
    $Range1 = New-Item -Path $Ranges -Name "Range1" -Force
    Set-ItemProperty $ZoneMap -Name "UNCAsIntranet" -Value "1" 
    Set-ItemProperty $ZoneMap -Name "AutoDetect" -Value "1" 
    $Range1 | New-ItemProperty -Name ":Range" -Value $vmwarehost
    $Range1 | New-ItemProperty -Name "file" -PropertyType DWORD -Value  "1"
   }
Set-ExecutionPolicy -ExecutionPolicy Bypass -Confirm:$false -Force
New-ItemProperty HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce -Name "Pass3" -Value "$PSHOME\powershell.exe -Command `"New-Item -ItemType File -Path c:\scripts\3.pass`""
."$Nodescriptdir\set-autologon.ps1" -domain $Domain -user "Administrator" -Password $PlainPassword
Restart-Computer


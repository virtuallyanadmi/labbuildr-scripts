﻿<#
.Synopsis
   Short description
.DESCRIPTION
   labbuildr builds your on-demand labs
.LINK
   https://github.com/bottkars/labbuildr/wiki
#>
#requires -version 3
[CmdletBinding()]
param (
$logpath = "c:\Scripts",
$Scriptdir = "\\vmware-host\Shared Folders\Scripts",
$SourcePath = "\\vmware-host\Shared Folders\Sources"
)
$ScriptName = $MyInvocation.MyCommand.Name
$Host.UI.RawUI.WindowTitle = "$ScriptName"
$Builddir = $PSScriptRoot
$Logtime = Get-Date -Format "MM-dd-yyyy_hh-mm-ss"
if (!(Test-Path $logpath))
    {
    New-Item -ItemType Directory -Path $logpath -Force
    }
$Logfile = New-Item -ItemType file  "$logpath\$ScriptName$Logtime.log"
Set-Content -Path $Logfile $MyInvocation.BoundParameters
if ((Get-WmiObject -Class Win32_ComputerSystem).Manufacturer -match "VMware")    
    {
    New-Item -ItemType file -Path "$Scriptdir\DCNode\domain.txt" -Force
    Set-Content -Value $env:USERDOMAIN -Path "$Scriptdir\DCNode\domain.txt"
    New-Item -ItemType file -Path "$Scriptdir\DCNode\ip.txt" -Force
    Set-Content -Value (Get-NetIPAddress -AddressFamily IPv4 | where IPAddress -ne "127.0.0.1").ipaddress -Path "$Scriptdir\DCNode\ip.txt"
    New-Item -ItemType file -Path "$Scriptdir\DCNode\gateway.txt" -Force
    Set-Content -Value (Get-NetIPConfiguration).ipv4DefaultGateway.NextHop -Path "$Scriptdir\DCNode\Gateway.txt"
    }
if ((Get-WmiObject -Class Win32_ComputerSystem).Manufacturer -match "Microsoft")    
    {
    .$ScriptDir\Node\set-vmguesttask.ps1 -Task Domain -Status $env:USERDOMAIN
    .$ScriptDir\Node\set-vmguesttask.ps1 -Task IPAddress -Status (Get-NetIPAddress -AddressFamily IPv4 | where IPAddress -ne "127.0.0.1").ipaddress
    try
        {
        .$ScriptDir\Node\set-vmguesttask.ps1 -Task Gateway -Status (Get-NetIPConfiguration).ipv4DefaultGateway.NextHop
        }
    catch
        {
        }
    .$ScriptDir\Node\set-vmguesttask.ps1 -Task DCNODE -Status finished
    }


    




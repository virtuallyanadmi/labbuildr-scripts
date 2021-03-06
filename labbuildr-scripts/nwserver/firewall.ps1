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
param(
    $Scriptdir = "\\vmware-host\Shared Folders\Scripts",
    $SourcePath = "\\vmware-host\Shared Folders\Sources",
    $logpath = "c:\Scripts",
    $Prereq ="Prereq"
     
)
$Nodescriptdir = "$Scriptdir\Node"
$NWScriptDir = "$Scriptdir\nwserver"
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
############
Set-Content -Path $Logfile "$nodeIP, $subnet, $nodename"

Write-Host "Opening firewall on Public for Networker Management Console" 
New-NetFirewallRule -DisplayName "Networker Server RPC 9001" -Direction Inbound -Protocol TCP -LocalPort 9001 -Profile Public -Enabled True
New-NetFirewallRule -DisplayName "Networker Server 9000" -Direction Inbound -Protocol TCP -LocalPort 9000 -Profile Public -Enabled True
New-NetFirewallRule -DisplayName "Networker Server DBquery" -Direction Inbound -Protocol TCP -LocalPort 2638 -Profile Public -Enabled True
New-NetFirewallRule -DisplayName "Networker Management" -Direction Inbound -Protocol TCP -LocalPort 53000-53999 -Profile Public -Enabled True

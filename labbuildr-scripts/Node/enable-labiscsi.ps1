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
	$Target_IP,
    $Scriptdir = "\\vmware-host\Shared Folders\Scripts",
    $SourcePath = "\\vmware-host\Shared Folders\Sources",
    $logpath = "c:\Scripts"

    )
$Nodescriptdir = "$Scriptdir\NODE"
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
######################################################################
Add-WindowsFeature -Name Multipath-IO -IncludeManagementTools -IncludeAllSubfeature
Enable-MSDSMAutomaticClaim -BusType iSCSI
Write-Host -ForegroundColor Gray " ==>Enabling iSCSI"
Set-Service -Name MSiSCSI -StartupType Automatic
Start-Service MSiSCSI
Write-Host -ForegroundColor Magenta " ==>Connecting to iSCSI Portal $Target_IP"
$Portal = New-IscsiTargetPortal –TargetPortalAddress $Target_IP
Get-IscsiTargetPortal -TargetPortalAddress $Target_IP | Get-IscsiTarget | Connect-IscsiTarget  -IsPersistent $True –IsMultipathEnabled $True
if ($PSCmdlet.MyInvocation.BoundParameters["verbose"].IsPresent)
    {
    Pause
    }
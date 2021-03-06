################################
# VM Setup Script v0.4         #
# Server 2016 VM Setup         #
# By AJ v1.0                   #
# 8/1/2019                     #
################################

# Functions
function Set-CentralStandardTime {
    Write-Host "Setting Time Zone to Central Standard Time"
    Set-TimeZone -Name "Central Standard Time"
}

function Install-Netxus {
    Write-Host "Downloading Netxus Client"
    (New-Object System.Net.WebClient).DownloadFile("https://concord.centrastage.net/csm/profile/downloadAgent/fa2411cc-b990-4146-9d49-3bf2e865ed33", "C:\Users\Public\Downloads\Netxus.exe")
    Write-Host "Netxus Download Complete, Installing Netxus"
    Start-Process -FilePath "C:\Users\Public\Downloads\Netxus.exe"
}

function Check-ActivationStatus {
    $Global:LicenseStatus = (Get-CimInstance -ClassName SoftwareLicensingProduct -Filter "Name Like 'Windows%'" | where PartialProductKey).licensestatus   
}

function Activate-Windows {
    Write-Host "Activating Windows"
    $ComputerName = gc env:computername
    $Key = Read-Host -Prompt 'Enter Product Key: AAAAA-BBBBB-CCCCC-DDDDD-EEEEE'
    $ActivationService = Get-WmiObject -Query "select * from SoftwareLicensingService" -ComputerName $ComputerName
    $ActivationService.InstallProductKey($Key)
    $ActivationService.RefreshLicenseStatus()
    Do {
        Check-ActivationStatus
        If ($Global:LicenseStatus -ne 1) {
            $RecheckStatus = Read-Host "Windows Activation Unsuccessful. Recheck status? (y/n)"
        } else {
            $RecheckStatus = "n"
        }
        If ($RecheckStatus -eq 'y') {
            Write-Host "Rechecking Status"
        }
    } until ($RecheckStatus -eq 'n')
    If ($Global:LicenseStatus -ne 1) {
        Write-Host "Windows Activation Unsuccessful. Continuing..." -ForegroundColor Red
    } else {
        Write-Host "Windows Activation Successful" -ForegroundColor Green
    } 
}

function Rename-Server {
    Write-Host "Rename the Server"
    $NewServerName = Read-Host 'Enter new server name'   
    Rename-Computer -NewName $NewServerName
}

function Join-Domain {
    Write-Host "Joining to Domain"
    $DomainName = Read-Host -Prompt 'Enter Domain Name'
    Add-Computer -DomainName $DomainName -Restart
    exit
}

function Disable-IEESC {
    Write-Host "Disabling IE Enhanced Security Configuration (ESC)"
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}" -Name "IsInstalled" -Value 0
    Stop-Process -Name Explorer
}

function Enable-RDP {
    Write-Host "Enabling RDP and Firewall Rules"
    Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\' -Name "fDenyTSConnections" -Value 0
    Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
}

function Disable-WindowsDefender {
    Write-Host "Disabling Windows Defender"
    Set-MpPreference -DisableRealtimeMonitoring $true
    Set-MpPreference -MAPSReporting 0
    Set-MpPreference -SubmitSamplesConsent 0
}

function Disable-WindowsFirewallAll {
    Write-Host "Disabling Windows Firewall"
    Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False
}

function InstallWindowsUpdates {
    If (Get-Module *PSWindowsUpdate* -ListAvailable)
    {
        Get-WUInstall –MicrosoftUpdate –AcceptAll –AutoReboot -Install
    }
    else 
    {
        Install-Module PSWindowsUpdate -Force > $null
        Add-WUServiceManager -ServiceID 7971f918-a847-4430-9279-4a52d1efe18d -confirm:$false > $null
        $global:updates = 2
        $global:updates | Out-File -Filepath .\updates.txt
        Get-WUInstall –MicrosoftUpdate –AcceptAll –AutoReboot -Install
    }
}
 
 function InstallStorageCraftSPX {
 Write-Host "Downloading ShadowProtect Client"
    (New-Object System.Net.WebClient).DownloadFile("https://downloads.storagecraft.com/SP_Files/ShadowProtect_SPX-6.8.4-5_x64.msi", "C:\Temp\ShadowProtect.msi")
    Write-Host "Download Complete, Installing ShadowProtect Client"
    Start-Process -FilePath "C:\Temp\ShadowProtect.msi"
}

# Script Start

# Run As Administrator
If (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
Start-Process PowerShell -Verb RunAs "-NoProfile -ExecutionPolicy Bypass -Command `"cd '$pwd'; & '$PSCommandPath';`"";
exit;
}

# Create Temp folder
If (!(Test-Path "C:\Temp")) {
    New-Item -Path "C:\" -Name "Temp" -ItemType "directory"
    Write-Host "Temp Folder Created" -ForegroundColor Green
} else {
    Write-Host "Temp Folder Already Exists" -ForegroundColor Green
}

#Set DVD drive to the letter E:
If  ((Get-WmiObject -Class Win32_volume -Filter 'DriveType=5' | Select-Object -First 1).DriveLetter -ne "E:") {
    Get-WmiObject -Class Win32_volume -Filter 'DriveType=5' | Select-Object -First 1 | Set-WmiInstance -Arguments @{DriveLetter='E:'} > $null
    $DVDDrive = ((Get-WmiObject -Class Win32_volume -Filter 'DriveType=5' | Select-Object -First 1).DriveLetter -eq "E:")
    Write-Host "DVD drive is now set to E:" -ForegroundColor Green
} else {
    Write-Host "DVD drive already set to E:" -ForegroundColor Green
    $DVDDrive = ((Get-WmiObject -Class Win32_volume -Filter 'DriveType=5' | Select-Object -First 1).DriveLetter -eq "E:")
}

#Disable ServerManager
Get-ScheduledTask -TaskName ServerManager | Disable-ScheduledTask -Verbose > $null
Write-Host "Disabled Server Manager from running on startup" -ForegroundColor Green

#Rename Server
If ($env:computername -like '*WIN-*'){
    Rename-Server
} else {
    Write-Host "Server Name has already been changed from the default" -ForegroundColor Green
 }

# Set Timezone
$TimeZone = [System.TimeZoneInfo]::local.StandardName
If (!($TimeZone -like 'Central Standard Time')) {
    Set-CentralStandardTime
    $TimeZone = [System.TimeZoneInfo]::local.StandardName
    If ($TimeZone -like 'Central Standard Time') {
        $TimeZone = 1
        Write-Host "Time Zone set to Central Standard Time" -ForegroundColor Green
    } else {
        Write-Host "Failed to Set Time Zone to Central Standard Time" -ForegroundColor Red
    } 
} else {
    Write-Host "Time Zone Already Set to Central Standard Time" -ForegroundColor Green
    $TimeZone = 1
}

# Install Netxus
If (!(Test-Path "C:\Program Files (x86)\CentraStage\CagService.exe")) {
    Install-Netxus
    Read-Host -Prompt "Netxus Agent Installed. Connect to this server via Splashtop and press enter to continue"
    $dattoAgent = Test-Path "C:\Program Files (x86)\CentraStage\CagService.exe"
} else {
    Write-Host "Netxus Already Installed." -ForegroundColor Green
    $dattoAgent = Test-Path "C:\Program Files (x86)\CentraStage\CagService.exe"
    # Need an unsuccessful install If here
}

#Install updates
If (Test-path .\updates.txt)
{
    $global:updates = (Get-Content .\updates.txt)
    $global:updates--
    If ($global:updates -gt 0)
    {
        Write-Host "Installing Windows Updates"
        InstallWindowsUpdates
    }
    else
    {
        write-host "Updates are installed" -ForegroundColor Green
    }
}
Write-Host "Installing Windows Updates"
InstallWindowsUpdates
# Activate Windows
Check-ActivationStatus
If ($Global:LicenseStatus -ne 1) {
    Activate-Windows
} else {
    Write-Host "Windows Already Activated" -ForegroundColor Green
}
# Join to Domin
$DomainJoined = (Get-WmiObject -Class Win32_ComputerSystem).PartOfDomain
If ($DomainJoined -like 'False') {
    Join-Domain
} else {
    Write-Host "Already Joined to Domain" -ForegroundColor Green
}

# Disable Local Administrator
$global:LocalAdminEnabled = (get-localuser | where {$_.Description -eq 'Built-in account for administering the computer/domain'})
If ($global:LocalAdminEnabled.Enabled -like '*True*') {
    Write-Host "Disabling Local Administrator"
    Disable-LocalUser ($global:LocalAdminEnabled.Name)
    $global:LocalAdminEnabled = (get-localuser | where {$_.Description -eq 'Built-in account for administering the computer/domain'} |fl enabled | out-string)
} else {
    Write-Host "Local Admin Already Disabled" -ForegroundColor Green
    $global:LocalAdminEnabled = (get-localuser | where {$_.Description -eq 'Built-in account for administering the computer/domain'} |fl enabled | out-string)
}

# Disable IE Enhanced Security Configuration
$IEESCEnabled = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}' -Name IsInstalled).IsInstalled
If ($IEESCEnabled -eq 1) {
    Disable-IEESC
    $IEESCEnabled = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}' -Name IsInstalled).IsInstalled
    Write-Host "IE Enhanced Security Configuration Disabled" -ForegroundColor Green
    #Need If Logic Here
} else {
    Write-Host "IE Enhanced Security Configuration Already Disabled" -ForegroundColor Green
}

# Enable RDP
$RDPDisabled = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\' -Name fDenyTSConnections).fDenyTSConnections
If ($RDPDisabled -eq 1) {
    Enable-RDP
    $RDPDisabled = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\' -Name fDenyTSConnections).fDenyTSConnections
    Write-Host "RDP Enabled" -ForegroundColor Green
    #Need If Logic Here
} else {
    Write-Host "RDP Already Enabled" -ForegroundColor Green
}

# Install StorageCraft SPX
If (!(Test-Path "C:\Program Files\StorageCraft\spx\spx_service.exe")) {
    InstallStorageCraftSPX
    $SPX = Test-Path "C:\Program Files\StorageCraft\spx\spx_service.exe"
} else {
    Write-Host "StorageCraft SPX Already Installed" -ForegroundColor Green
    $SPX = Test-Path "C:\Program Files\StorageCraft\spx\spx_service.exe"
}

# Disable Windows Defender
$WDDRM = (Get-MpPreference).DisableRealtimeMonitoring
$WDMR = (Get-MpPreference).MAPSReporting
$WDSSC = (Get-MpPreference).SubmitSamplesConsent
If ($WDDRM -like 'False' -Or $WDMR -ne 0 -Or $WDSSC -ne 0) {
    Disable-WindowsDefender
    $WDDRM = (Get-MpPreference).DisableRealtimeMonitoring
    $WDMR = (Get-MpPreference).MAPSReporting
    $WDSSC = (Get-MpPreference).SubmitSamplesConsent
    Write-Host "Windows Defender Disabled" -ForegroundColor Green
} else {
    Write-Host "Windows Defender Already Disabled" -ForegroundColor Green
}

# Disable Windows Firewall
$FWDomainEnabled = (get-netfirewallprofile -profile Domain).Enabled
$FWPublicEnabled = (get-netfirewallprofile -profile Public).Enabled
$FWPrivateEnabled = (get-netfirewallprofile -profile Private).Enabled
If ($FWDomainEnabled -like 'True' -Or $FWPublicEnabled -like 'True' -Or $FWPrivateEnabled -like 'True') {
    Disable-WindowsFirewallAll
    $FWDomainEnabled = (get-netfirewallprofile -profile Domain).Enabled
    $FWPublicEnabled = (get-netfirewallprofile -profile Public).Enabled
    $FWPrivateEnabled = (get-netfirewallprofile -profile Private).Enabled
    Write-Host "Windows Firewall Disabled" -ForegroundColor Green
} else {
    Write-Host "Windows Firewall Already Disabled" -ForegroundColor Green
}

# Check All Scripts & Cleanup
If($TimeZone -eq 1 -And ($dattoAgent -like 'True') -And ($Global:LicenseStatus -eq 1) -And 
    ($DomainJoined -like 'True') -And ($global:LocalAdminEnabled -like 'False') -And ($IEESCEnabled -eq 0) -And ($RDPDisabled -eq 0) -And 
    ($SPX -like 'True') -And ($WDDRM -like 'True') -And ($WDMR -eq 0) -And ($WDSSC -eq 0) -And 
    ($FWDomainEnabled -like 'False') -And ($FWPublicEnabled -like 'False') -And ($FWPrivateEnabled -like 'False') -And ($DVDDrive -like 'True')){

    Write-Host "Final Checks Complete" -ForegroundColor Green
    Remove-Item -path .\updates.txt
} else {
    Write-Host "Failed Final Checks" -ForegroundColor Red
}

Read-Host -Prompt "Press Enter to continue"


# Thanks DSU
# The script must be run as an Admin in order for it to work properly

# Logging path
$logPath = "C:\SecurityConfigLog.txt"

#Creating the log file can be accessed with Get-Content -Path "C:\SecurityConfigLog.txt"
if (!(Test-Path $logPath)) {
    New-Item -Path $logPath -ItemType File | Out-Null
}

# Function to write to the log file
function Write-Log {
    param($message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "$timestamp - $message"
    Add-Content -Path $logPath -Value $logMessage
}

Add-Type -AssemblyName System.Windows.Forms

$form = New-Object System.Windows.Forms.Form
$form.Text = "Security Configuration Options"
$form.Width = 500
$form.Height = 700

# Adds Check box's to the GUI
function Add-Checkbox {
    param(
        [string]$Text,
        [int]$Top,
        [bool]$DefaultChecked
    )
    $checkbox = New-Object System.Windows.Forms.CheckBox
    $checkbox.Text = $Text
    $checkbox.Top = $Top
    $checkbox.Left = 20
    $checkbox.Width = 450
    $checkbox.Checked = $DefaultChecked
    $form.Controls.Add($checkbox)
    return $checkbox
}

$disableSMBv1Checkbox = Add-Checkbox -Text "Disable SMBv1 (EternalBlue mitigation)" -Top 20 -DefaultChecked $true
$enforcePasswordPolicyCheckbox = Add-Checkbox -Text "Enforce password and account policies" -Top 50 -DefaultChecked $true
$enableDefenderCheckbox = Add-Checkbox -Text "Enable Windows Defender Real-time Protection" -Top 80 -DefaultChecked $true
$configureAuditPolicyCheckbox = Add-Checkbox -Text "Configure audit policy for logon/logoff" -Top 110 -DefaultChecked $true
$disableSMBv2v3Checkbox = Add-Checkbox -Text "Disable SMBv2 and SMBv3" -Top 140 -DefaultChecked $true
$disableRDPCheckbox = Add-Checkbox -Text "Disable Remote Desktop Protocol (RDP)" -Top 170 -DefaultChecked $true
$disablePrintSpoolerCheckbox = Add-Checkbox -Text "Disable Print Spooler (PrintNightmare mitigation)" -Top 200 -DefaultChecked $true
$enableFirewallCheckbox = Add-Checkbox -Text "Enable Windows Firewall" -Top 230 -DefaultChecked $true
$disableGuestAccountCheckbox = Add-Checkbox -Text "Disable Guest Account" -Top 260 -DefaultChecked $true
$enableBitLockerCheckbox = Add-Checkbox -Text "Enable BitLocker" -Top 290 -DefaultChecked $true
$enableSecureBootCheckbox = Add-Checkbox -Text "Enable Secure Boot" -Top 320 -DefaultChecked $true
$disableWinRMCheckbox = Add-Checkbox -Text "Disable Windows Remote Management (WinRM)" -Top 350 -DefaultChecked $true

# Add OK and Cancel
$okButton = New-Object System.Windows.Forms.Button
$okButton.Text = "OK"
$okButton.Top = 380
$okButton.Left = 150
$okButton.Width = 100
$okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
$form.Controls.Add($okButton)

$cancelButton = New-Object System.Windows.Forms.Button
$cancelButton.Text = "Cancel"
$cancelButton.Top = 380
$cancelButton.Left = 260
$cancelButton.Width = 100
$cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
$form.Controls.Add($cancelButton)

$form.AcceptButton = $okButton
$form.CancelButton = $cancelButton
$result = $form.ShowDialog()

if ($result -ne [System.Windows.Forms.DialogResult]::OK) {
    Write-Host "canceled Exiting..."
    Write-Log "User canceled the script."
    exit
}

Write-Host "Applying configurations..."
Write-Log "Applying configurations based on choices..."

# Confirmation
$confirmation = Read-Host "Are you sure you want to apply these changes? (y/n)"
if ($confirmation -ne "y") {
    Write-Host "Changes not applied. Exiting..."
    Write-Log "Changes not applied due to user confirmation."
    exit
}

Write-Log "User confirmed applying changes."

# Functions for all hardening options
function Disable-SMBv1 {
    Write-Host "Disabling SMBv1..."
    Write-Log "Disabling SMBv1..."
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" -Name "SMB1" -Value 0
    Write-Host "SMBv1 has been disabled."
    Write-Log "SMBv1 disabled successfully."
}

function Set-PasswordPolicy {
    Write-Host "Enforcing password and account policies..."
    Write-Log "Enforcing password and account policies..."
    Import-Module ActiveDirectory
    $account = Get-ADUser -Identity "Administrator"
    if ($account.SID -like "S-1-5-*-500") {
        Write-Host "Cannot modify built-in accounts like Administrator."
        Write-Log "Cannot modify built-in Administrator account."
    } else {
        Set-ADUser -Identity "Administrator" -PasswordNeverExpires $false
        Write-Host "Password policy updated for the account."
        Write-Log "Password policy updated for Administrator account."
    }
    Write-Host "Password policies applied."
    Write-Log "Password policies applied."
}

function Enable-WindowsDefender {
    Write-Host "Enabling Windows Defender Real-time Protection..."
    Write-Log "Enabling Windows Defender Real-time Protection..."
    Set-MpPreference -DisableRealtimeMonitoring $false
    Write-Host "Windows Defender Real-time Protection enabled."
    Write-Log "Windows Defender Real-time Protection enabled."
}

function Set-AuditPolicy {
    Write-Host "Configuring audit policy for logon/logoff..."
    Write-Log "Configuring audit policy for logon/logoff..."
    auditpol /set /category:"Logon/Logoff" /success:enable /failure:enable
    Write-Host "Audit policy configured."
    Write-Log "Audit policy configured."
}

function Disable-SMBv2v3 {
    Write-Host "Disabling SMBv2 and SMBv3..."
    Write-Log "Disabling SMBv2 and SMBv3..."
    Set-SmbServerConfiguration -EnableSMB2Protocol $false
    Write-Host "SMBv2 and SMBv3 disabled."
    Write-Log "SMBv2 and SMBv3 disabled."
}

function Disable-RDP {
    Write-Host "Disabling Remote Desktop Protocol (RDP)..."
    Write-Log "Disabling Remote Desktop Protocol (RDP)..."
    Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name 'fDenyTSConnections' -Value 1
    Write-Host "RDP has been disabled."
    Write-Log "RDP disabled."
}

function Disable-PrintSpooler {
    Write-Host "Disabling Print Spooler service..."
    Write-Log "Disabling Print Spooler service..."
    Stop-Service -Name "Spooler" -Force
    Write-Host "Print Spooler service stopped."
    Write-Log "Print Spooler service stopped."
}

function Enable-WindowsFirewall {
    Write-Host "Enabling Windows Firewall..."
    Write-Log "Enabling Windows Firewall..."
    Set-NetFirewallProfile -All -Enabled True
    Write-Host "Windows Firewall enabled."
    Write-Log "Windows Firewall enabled."
}

function Disable-GuestAccount {
    Write-Host "Disabling Guest account..."
    Write-Log "Disabling Guest account..."
    Disable-LocalUser -Name "Guest"
    Write-Host "Guest account disabled."
    Write-Log "Guest account disabled."
}

function Enable-BitLocker {
    Write-Host "Enabling BitLocker..."
    Write-Log "Enabling BitLocker..."

    $tpm = Get-WmiObject -Class Win32_Tpm
    if ($tpm) {
        if ($tpm.SpecVersion -contains "2.0" -or $tpm.SpecVersion -contains "1.2") {
            Write-Host "TPM is available, proceeding with BitLocker encryption."
            Write-Log "TPM is available, proceeding with BitLocker encryption."
        } else {
            Write-Host "TPM is not properly configured or supported. BitLocker cannot proceed without TPM."
            Write-Log "TPM is not properly configured or supported. BitLocker cannot proceed without TPM."
            return
        }
    } else {
        Write-Host "No TPM found. BitLocker requires TPM or a compatible configuration."
        Write-Log "No TPM found. BitLocker requires TPM or a compatible configuration."
        return
    }

    $osDrive = Get-WmiObject -Class Win32_OperatingSystem
    if ($osDrive) {
        $osDriveLetter = $osDrive.WindowsDirectory.Substring(0, 2) # e.g., C:
        Write-Host "Encrypting the OS drive $osDriveLetter."
        Write-Log "Encrypting the OS drive $osDriveLetter."
        
        Enable-BitLocker -MountPoint $osDriveLetter -EncryptionMethod Aes256 -UsedSpaceOnly -TPMAndPIN
        Write-Host "BitLocker enabled on $osDriveLetter."
        Write-Log "BitLocker enabled on $osDriveLetter."
    } else {
        Write-Host "Operating system drive not found. Cannot enable BitLocker."
        Write-Log "Operating system drive not found. Cannot enable BitLocker."
    }
}

function Enable-SecureBoot {
    Write-Host "Enabling Secure Boot..."
    Write-Log "Enabling Secure Boot..."
    $secureBoot = Get-WmiObject -Class Win32_ComputerSystem
    if ($secureBoot.SecureBoot) {
        Write-Host "Secure Boot is already enabled."
        Write-Log "Secure Boot is already enabled."
    } else {
        Write-Host "Secure Boot is not enabled. Please enable it in BIOS."
        Write-Log "Secure Boot is not enabled. Please enable it in BIOS."
    }
}

function Disable-WinRM {
    Write-Host "Disabling Windows Remote Management (WinRM)..."
    Write-Log "Disabling Windows Remote Management (WinRM)..."
    Disable-PSRemoting -Force
    Write-Host "WinRM disabled."
    Write-Log "WinRM disabled."
}

# Execute configurations based on checkbox selections
if ($disableSMBv1Checkbox.Checked) { Disable-SMBv1 }
if ($enforcePasswordPolicyCheckbox.Checked) { Set-PasswordPolicy }
if ($enableDefenderCheckbox.Checked) { Enable-WindowsDefender }
if ($configureAuditPolicyCheckbox.Checked) { Set-AuditPolicy }
if ($disableSMBv2v3Checkbox.Checked) { Disable-SMBv2v3 }
if ($disableRDPCheckbox.Checked) { Disable-RDP }
if ($disablePrintSpoolerCheckbox.Checked) { Disable-PrintSpooler }
if ($enableFirewallCheckbox.Checked) { Enable-WindowsFirewall }
if ($disableGuestAccountCheckbox.Checked) { Disable-GuestAccount }
if ($enableBitLockerCheckbox.Checked) { Enable-BitLocker }
if ($enableSecureBootCheckbox.Checked) { Enable-SecureBoot }
if ($disableWinRMCheckbox.Checked) { Disable-WinRM }

Write-Host "Configurations have been applied successfully."
Write-Log "All configurations applied successfully."

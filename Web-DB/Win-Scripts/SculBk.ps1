#$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
#$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "user")
param(
    [string]$MySQLUser,
    [string]$DestinationPath,
    [string]$FilePrefixName
)

# Prompt for MySQL password
$MySQLPassword = Read-Host -AsSecureString "Enter MySQL password"

# Convert SecureString to plain text
$MySQLPasswordPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($MySQLPassword)
)

# Get current date
$CurrentDate = Get-Date -Format "yyyy-MM-dd"
$BackupFileName = "${FilePrefixName}_SCUL_${CurrentDate}.sql"
$BackupFilePath = Join-Path -Path $DestinationPath -ChildPath $BackupFileName

# Dump all databases
$DumpArgs = "--user=$MySQLUser --password=$MySQLPasswordPlain --host=localhost --all-databases"
Start-Process -NoNewWindow -FilePath "mysqldump" -ArgumentList $DumpArgs -RedirectStandardOutput $BackupFilePath -Wait

Write-Host "All MySQL databases backed up to: $BackupFilePath"

# --- 7-Zip Handling ---
function Check-If7ZipInstalled {
    return (Get-Command 7z -ErrorAction SilentlyContinue) -ne $null
}

function Install-7Zip {
    $url = "https://www.7-zip.org/a/7z1900-x64.exe"
    $installerPath = "$env:TEMP\7z1900-x64.exe"
    
    Write-Host "📦 Downloading 7-Zip..."
    Invoke-WebRequest -Uri $url -OutFile $installerPath
    Write-Host "🔧 Installing 7-Zip..."
    Start-Process -FilePath $installerPath -ArgumentList "/S" -Wait
    Write-Host "7-Zip installed."
}

if ($IsWindows) {
    if (-not (Check-If7ZipInstalled)) {
        Write-Host "7-Zip not found. Installing..."
        Install-7Zip
    }
    $env:Path += ";C:\Program Files\7-Zip"
}

# --- Encrypt the file ---
function Encrypt-FileWith7Zip {
    param(
        [string]$FilePath,
        [string]$Password
    )
    $EncryptedFilePath = "$FilePath.7z"
    $SevenZipCmd = "a -p$Password -mhe `"$EncryptedFilePath`" `"$FilePath`""
    Start-Process -NoNewWindow -FilePath "C:\Program Files\7-Zip\7z.exe" -ArgumentList $SevenZipCmd -Wait
    Write-Host "Encrypted file created: $EncryptedFilePath."
}

# Prompt for encryption password
$ZipPassword = Read-Host -AsSecureString "Enter password to encrypt the backup"
$ZipPasswordPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($ZipPassword)
)

# Encrypt and clean up
Encrypt-FileWith7Zip -FilePath $BackupFilePath -Password $ZipPasswordPlain
Remove-Item -Path $BackupFilePath -Force

Write-Host "Encrypted backup complete. Unencrypted file removed."


#.\MySQLBackup_All.ps1 -MySQLUser "root" -DestinationPath "C:\Backups" -FilePrefixName "MySQLBackup"

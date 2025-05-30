param(
    [string]$MySQLUser,
    [string]$DestinationPath,
    [string]$EncryptedBackupFile
)

# Prompt for MySQL password
$MySQLPassword = Read-Host -AsSecureString "Enter MySQL password"

# Convert MySQL password to plain text
$MySQLPasswordPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($MySQLPassword)
)

# Prompt for 7-Zip decryption password
$ZipPassword = Read-Host -AsSecureString "Enter password to decrypt the backup"
$ZipPasswordPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($ZipPassword)
)

# Function to check if 7-Zip is installed
function Check-If7ZipInstalled {
    return (Get-Command 7z -ErrorAction SilentlyContinue) -ne $null
}

# Function to install 7-Zip if not installed
function Install-7Zip {
    $url = "https://www.7-zip.org/a/7z1900-x64.exe"
    $installerPath = "$env:TEMP\7z1900-x64.exe"

    Write-Host "Downloading 7-Zip..."
    Invoke-WebRequest -Uri $url -OutFile $installerPath

    Write-Host "Installing 7-Zip..."
    Start-Process -FilePath $installerPath -ArgumentList "/S" -Wait
    Write-Host "7-Zip installed."
}

# Ensure 7-Zip is installed
if (-not (Check-If7ZipInstalled)) {
    Write-Host "7-Zip not found. Installing..."
    Install-7Zip
}
$SevenZipExe = "${env:ProgramFiles}\7-Zip\7z.exe"
if (-not (Test-Path $SevenZipExe)) {
    throw "7-Zip not found at expected path: $SevenZipExe"
}

# Function to decrypt the backup with 7-Zip
function Decrypt-FileWith7Zip {
    param(
        [string]$EncryptedFilePath,
        [string]$Password,
        [string]$OutputFolder
    )

    $SevenZipCmd = "x -p$Password `"$EncryptedFilePath`" -o`"$OutputFolder`" -y"
    Start-Process -NoNewWindow -FilePath $SevenZipExe -ArgumentList $SevenZipCmd -Wait

    Write-Host "Backup decrypted to: $OutputFolder"
}

# Decrypt the file to the destination path
$DecryptionOutputPath = $DestinationPath
Decrypt-FileWith7Zip -EncryptedFilePath $EncryptedBackupFile -Password $ZipPasswordPlain -OutputFolder $DecryptionOutputPath

# Find the decrypted .sql file
$DecryptedSQLFile = Get-ChildItem -Path $DecryptionOutputPath -Filter *.sql | Sort-Object LastWriteTime -Descending | Select-Object -First 1

if (-not $DecryptedSQLFile) {
    throw "No .sql file found after decryption."
}

# Restore MySQL from decrypted file
Write-Host "Restoring MySQL databases from $($DecryptedSQLFile.FullName)..."
Start-Process "mysql" -ArgumentList "--user=$MySQLUser --password=$MySQLPasswordPlain --execute=`"source $($DecryptedSQLFile.FullName)`"" -Wait

Write-Host "MySQL backup restored successfully."

# Clean up decrypted file
Remove-Item -Path $DecryptedSQLFile.FullName -Force
Write-Host "Decrypted SQL file removed after restore."

#.\RestoreMySQLBackup.ps1 -MySQLUser "root" -DestinationPath "C:\Backups\Temp" -EncryptedBackupFile "C:\Backups\MiesculBK_SCUL_2025-04-11.sql.7z"

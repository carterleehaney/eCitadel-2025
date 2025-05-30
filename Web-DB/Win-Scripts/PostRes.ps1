param(
    [string]$PostgresUser,
    [string]$DestinationPath,
    [string]$EncryptedBackupFile
)

# Prompt for PostgreSQL password
$Password = Read-Host -AsSecureString "Enter PostgreSQL password"

# Convert SecureString to plain text for use in pg_restore command
$PasswordBSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
$PasswordPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($PasswordBSTR)

# Prompt for the 7-Zip password to decrypt the backup file
$ZipPassword = Read-Host -AsSecureString "Enter password to decrypt the backup"

# Convert SecureString to plain text for 7-Zip (needed for passing it to 7z)
$ZipPasswordBSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($ZipPassword)
$ZipPasswordPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($ZipPasswordBSTR)

# Function to check if 7-Zip is installed
function Check-If7ZipInstalled {
    $7zipPath = Get-Command 7z -ErrorAction SilentlyContinue
    if (-not $7zipPath) {
        return $false
    }
    return $true
}

# Function to download and install 7-Zip if not installed
function Install-7Zip {
    $url = "https://www.7-zip.org/a/7z1900-x64.exe"
    $installerPath = "$env:TEMP\7z1900-x64.exe"
    
    Write-Host "Downloading 7-Zip installer..."
    Invoke-WebRequest -Uri $url -OutFile $installerPath

    Write-Host "Installing 7-Zip..."
    Start-Process -FilePath $installerPath -ArgumentList "/S" -Wait
    Write-Host "7-Zip installed successfully."
}

# Check if 7-Zip is installed, and install if needed
if (-not (Check-If7ZipInstalled)) {
    Write-Host "7-Zip not found. Installing 7-Zip..."
    Install-7Zip
}

# Add 7-Zip installation path to the system PATH variable
$SevenZipPath = "C:\Program Files\7-Zip"
$env:Path += ";$SevenZipPath"

# Function to decrypt the backup file with 7-Zip using a password
function Decrypt-FileWith7Zip {
    param(
        [string]$EncryptedFilePath,
        [string]$Password,
        [string]$DecryptedFilePath
    )

    # Decrypt using 7-Zip
    $SevenZipCmd = "7z x -p$Password $EncryptedFilePath -o$DecryptedFilePath"

    # Run the 7-Zip decryption command
    Invoke-Expression $SevenZipCmd

    Write-Host "Backup decrypted and saved as: $DecryptedFilePath"
}

# Define the decrypted backup file path
$DecryptedBackupFilePath = Join-Path -Path $DestinationPath -ChildPath "decrypted_backup.sql"

# Decrypt the backup file
Decrypt-FileWith7Zip -EncryptedFilePath $EncryptedBackupFile -Password $ZipPasswordPlain -DecryptedFilePath $DecryptedBackupFilePath

# Restore the decrypted backup to PostgreSQL
Write-Host "Restoring all databases from the decrypted backup..."

# Create the restore command
$PgRestoreCmd = "psql --username=$PostgresUser --port=5432 --password --file=$DecryptedBackupFilePath"
$env:PGPASSWORD = $PasswordPlain
Invoke-Expression $PgRestoreCmd

# Clear the password environment variable after the operation
Remove-Item Env:PGPASSWORD

# Remove the decrypted backup file after restoration
Remove-Item -Path $DecryptedBackupFilePath -Force

Write-Host "Backup restored and decrypted file deleted."

#.\PostRes.ps1 -PostgresUser "postgres" -DestinationPath "C:\..."  -EncytptedBackupFile "C:\Backups\_POST_2025-04-11.sql.7z"
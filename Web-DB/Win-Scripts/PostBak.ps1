#$env:PATH += ";C:\Program Files\PostgresSQL\17\bin\"
param(
    [string]$PostgresUser,
    [string]$DestinationPath,
    [string]$FilePrefixName
)

# Prompt for PostgreSQL password
$Password = Read-Host -AsSecureString "Enter PostgreSQL password"

# Convert SecureString to plain text (for use in pg_dump command)
$PasswordBSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
$PasswordPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($PasswordBSTR)

# Get current date in YYYY-MM-DD format
$CurrentDate = Get-Date -Format "yyyy-MM-dd"

# Create backup file name with prefix and date
$BackupFileName = "${FilePrefixName}_POST_${CurrentDate}.sql"

# Set the full path for the backup file
$BackupFilePath = Join-Path -Path $DestinationPath -ChildPath $BackupFileName

# Create a backup command string
$PgDumpCmd = "pg_dump --username=$PostgresUser --host=localhost --port=5432 --format=c --blobs --verbose --file=$BackupFilePath"

# Handle password passing securely for PostgreSQL (using PGPASSWORD for Windows PowerShell or other means in PowerShell Core)
if ($IsWindows) {
    $env:PGPASSWORD = $PasswordPlain
    Start-Process -NoNewWindow -FilePath "pg_dump" -ArgumentList $PgDumpCmd
    # Clear the password environment variable after the operation
    Remove-Item Env:PGPASSWORD
} else {
    # On non-Windows systems, it's better to use a pgpass.conf file or pass the password securely
    # Since we're using PowerShell Core, we'll directly pass the password with the command
    $PgDumpCmdWithPass = "$PgDumpCmd --password=$PasswordPlain"
    Start-Process -NoNewWindow -FilePath "pg_dump" -ArgumentList $PgDumpCmdWithPass
}

Write-Host "Backup completed: $BackupFilePath"

# Function to check if 7-Zip is installed (Windows only)
function Check-If7ZipInstalled {
    $7zipPath = Get-Command 7z -ErrorAction SilentlyContinue
    return $7zipPath -ne $null
}

# Function to download and install 7-Zip for Windows
function Install-7Zip {
    $url = "https://www.7-zip.org/a/7z1900-x64.exe"
    $installerPath = "$env:TEMP\7z1900-x64.exe"
    
    Write-Host "Downloading 7-Zip installer..."
    Invoke-WebRequest -Uri $url -OutFile $installerPath

    Write-Host "Installing 7-Zip..."
    Start-Process -FilePath $installerPath -ArgumentList "/S" -Wait
    Write-Host "7-Zip installed successfully."
}

# Only install 7-Zip if on Windows
if ($IsWindows) {
    # Check if 7-Zip is installed
    if (-not (Check-If7ZipInstalled)) {
        Write-Host "7-Zip not found. Installing 7-Zip..."
        Install-7Zip
    }
    
    # Add 7-Zip installation path to the system PATH variable
    $SevenZipPath = "C:\Program Files\7-Zip"
    $env:Path += ";$SevenZipPath"
}

# Function to encrypt the file with 7-Zip using a password
function Encrypt-FileWith7Zip {
    param(
        [string]$FilePath,
        [string]$Password
    )

    # Define the output encrypted file path
    $EncryptedFilePath = "$FilePath.7z"

    # Create the 7-Zip encryption command
    $SevenZipCmd = "7z a -p$Password -mhe $EncryptedFilePath $FilePath"

    # Run the 7-Zip encryption command
    Start-Process -NoNewWindow -FilePath "7z" -ArgumentList $SevenZipCmd -Wait

    Write-Host "Backup encrypted and saved as: $EncryptedFilePath"
}

# Prompt for the 7-Zip password
$ZipPassword = Read-Host -AsSecureString "Enter password to encrypt the backup"

# Convert SecureString to plain text for 7-Zip (needed for passing it to 7z)
$ZipPasswordBSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($ZipPassword)
$ZipPasswordPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($ZipPasswordBSTR)

# Encrypt the backup file using 7-Zip
Encrypt-FileWith7Zip -FilePath $BackupFilePath -Password $ZipPasswordPlain

# Remove the unencrypted backup file after encryption
Remove-Item -Path $BackupFilePath -Force

Write-Host "Backup completed, encrypted, and unencrypted file deleted."

#.\PostBak.ps1 -PostgresUser "postgres" -DestinationPath "C:\DBBackups" -FilePrefixName "mydb_backup"

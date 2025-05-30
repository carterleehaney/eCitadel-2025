param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("mysql")]
    [string]$dbType,

    [Parameter(Mandatory = $true)]
    [string]$username
)

$dbHost = "localhost"

$password = Read-Host -AsSecureString "Enter database password"
$unsecurePassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($password)
)

function Install-MySQLConnector {
    Write-Host "MySQL .NET connector not found. Installing MySQL Connector/NET..." -ForegroundColor Yellow
    try {
        Install-PackageProvider -Name NuGet -Force -Scope CurrentUser
        Register-PackageSource -Name "nuget.org" -Location "https://api.nuget.org/v3/index.json" -ProviderName "NuGet" -Force
        Install-Package -Name MySql.Data -Source nuget.org -Force
    } catch {
        Write-Error "Failed to install required MySQL packages: $_"
        exit 1
    }
}

function Check-MySQLConnector {
    try {
        if (-not ([System.Reflection.Assembly]::LoadWithPartialName("MySql.Data"))) {
            Install-MySQLConnector
        }
    } catch {
        Write-Error "MySQL .NET connector not found. Please install MySQL Connector/NET manually."
        exit 1
    }
}

# Load MySQL connector
try {
    if ($dbType -eq "mysql") {
        Check-MySQLConnector
    }
} catch {
    Write-Error $_.Exception.Message
    exit 1
}

function Get-MySQLDatabases {
    $connectionString = "server=$dbHost;uid=$username;pwd=$unsecurePassword"
    $connection = New-Object MySql.Data.MySqlClient.MySqlConnection($connectionString)
    $connection.Open()

    $query = "SHOW DATABASES"
    $command = New-Object MySql.Data.MySqlClient.MySqlCommand($query, $connection)
    $reader = $command.ExecuteReader()

    $databases = @()
    while ($reader.Read()) {
        $dbName = $reader.GetString(0)
        if ($dbName -notin @("information_schema", "mysql", "performance_schema", "sys")) {
            $databases += $dbName
        }
    }

    $connection.Close()
    return $databases
}

function Search-PII {
    param(
        [string]$dbType,
        [string]$database
    )

    $patterns = @(
        @{ Type = "SSN"; Pattern = '\b\d{3}-\d{2}-\d{4}\b' },  # SSN
        @{ Type = "Phone"; Pattern = '\b(?:\+?1[-.\s]?)*\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}\b' },  # Phone numbers
        @{ Type = "Email"; Pattern = '\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b' },  # Emails
        @{ Type = "Date"; Pattern = '\b\d{1,2}/\d{1,2}/\d{4}\b' },  # Birthdate format
        @{ Type = "Address"; Pattern = '\b\d{1,5}[\s-][A-Za-z0-9\s]+(?:[,\s][A-Za-z\s]+(?:,\s[A-Za-z]{2})?)?\b' }  # Address pattern
    )

    $connectionString = "server=$dbHost;uid=$username;pwd=$unsecurePassword;database=$database"
    $connection = New-Object MySql.Data.MySqlClient.MySqlConnection($connectionString)
    $commandType = "MySql.Data.MySqlClient.MySqlCommand"
    $schema = $database

    $piiFound = $false

    try {
        $connection.Open()

        $query = "SELECT table_name, column_name FROM information_schema.columns WHERE table_schema = '$schema'"
        $command = New-Object $commandType $query, $connection
        $reader = $command.ExecuteReader()

        $columns = @()
        while ($reader.Read()) {
            $columns += [PSCustomObject]@{
                Table  = $reader["table_name"].ToString()
                Column = $reader["column_name"].ToString()
            }
        }
        $reader.Close()

        if ($columns.Count -gt 0) {
            Write-Host "Scanning tables and columns for PII in database: $database" -ForegroundColor Cyan
        }

        foreach ($col in $columns) {
            $dataQuery = "SELECT $($col.Column) FROM $($col.Table) LIMIT 100"
            $dataCommand = New-Object $commandType $dataQuery, $connection

            try {
                $dataReader = $dataCommand.ExecuteReader()
                while ($dataReader.Read()) {
                    $val = $dataReader[0]
                    if ($val -ne $null) {
                        $valStr = $val.ToString().Trim()
                        Write-Host "` Checking value: $valStr" -ForegroundColor DarkGray

                        foreach ($p in $patterns) {
                            if ($valStr -match $p.Pattern) {
                                Write-Host "` FOUND $($p.Type) in DB: $database | Table: $($col.Table) | Column: $($col.Column)" -ForegroundColor Yellow
                                Write-Host "     → Value: $valStr" -ForegroundColor Yellow
                                $piiFound = $true
                            } 
                        }
                    }
                }
                $dataReader.Close()
            } catch {
                Write-Warning "Could not read from $($col.Table).$($col.Column): $_"
            }
        }
  
    } catch {
        Write-Error ("Failed to connect or query " + $database + ": " + $_.Exception.Message)
    } finally {
        $connection.Close()
    }

    if (-not $piiFound) {
        Write-Host "No PII found in $database" -ForegroundColor Green
    }
}

# Get databases and run scan
if ($dbType -eq "mysql") {
    $databases = Get-MySQLDatabases
}

if ($databases.Count -eq 0) {
    Write-Host "No databases found." -ForegroundColor Red
} else {
    Write-Host "Scanning the following databases for PII:" -ForegroundColor Green
    $databases | ForEach-Object { Write-Host $_ }

    foreach ($db in $databases) {
        Write-Host "`nScanning database: $db" -ForegroundColor Cyan
        Search-PII -dbType $dbType -database $db
    }
}

#https://dev.mysql.com/downloads/connector/net/

param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("postgres")]
    [string]$dbType,

    [Parameter(Mandatory = $true)]
    [string]$username
)

$dbHost = "localhost"

$password = Read-Host -AsSecureString "Enter database password"
$unsecurePassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($password)
)

# Load Npgsql.dll from current directory
$npgsqlPath = Join-Path $PSScriptRoot "Npgsql.dll"
if (Test-Path $npgsqlPath) {
    try {
        Add-Type -Path $npgsqlPath
        Write-Host "Loaded Npgsql.dll from $npgsqlPath" -ForegroundColor Green
    } catch {
        Write-Error "Failed to load Npgsql.dll from script directory: $_"
        exit 1
    }
} else {
    Write-Error "Npgsql.dll not found in script directory: $PSScriptRoot"
    exit 1
}

function Get-PostgresDatabases {
    $connectionString = "Host=$dbHost;Username=$username;Password=$unsecurePassword"
    $connection = New-Object Npgsql.NpgsqlConnection($connectionString)
    $connection.Open()

    $query = "SELECT datname FROM pg_database WHERE datistemplate = false AND datname NOT IN ('postgres')"
    $command = New-Object Npgsql.NpgsqlCommand($query, $connection)
    $reader = $command.ExecuteReader()

    $databases = @()
    while ($reader.Read()) {
        $databases += $reader.GetString(0)
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
        @{ Type = "SSN"; Pattern = '\b\d{3}-\d{2}-\d{4}\b' },
        @{ Type = "Phone"; Pattern = '\b(?:\+?1[-.\s]?)*\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}\b' },
        @{ Type = "Email"; Pattern = '\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b' },
        @{ Type = "Date"; Pattern = '\b\d{1,2}/\d{1,2}/\d{4}\b' },
        @{ Type = "Address"; Pattern = '\b\d{1,5}[\s-][A-Za-z0-9\s]+(?:[,\s][A-Za-z\s]+(?:,\s[A-Za-z]{2})?)?\b' }
    )

    $connectionString = "Host=$dbHost;Username=$username;Password=$unsecurePassword;Database=$database"
    $connection = New-Object Npgsql.NpgsqlConnection($connectionString)
    $commandType = "Npgsql.NpgsqlCommand"
    $schema = "public"

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
            $dataQuery = "SELECT $($col.Column) FROM $($col.Table)"  # Removed LIMIT 100 to scan all rows
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
$databases = Get-PostgresDatabases

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

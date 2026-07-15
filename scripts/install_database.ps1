# install_database.ps1
# First-time SQL Server Database Package installer for BloodBankDB (voice-project).
# Windows/PowerShell equivalent of install_database.sh — for validating the
# package locally (e.g. against a dev SQL Server on this Build Workstation)
# before it's consumed by the Docker "db-init" service.
#
# Required environment variables (never hardcode these):
#   DB_SERVER, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD, DB_SA_PASSWORD
#
# DB_SA_PASSWORD authenticates as "sa" for 001_create_database.sql only — a
# fresh SQL Server has no DB_USER login yet, so nothing else can create one.
# Every script after 001 runs as sa too; node-backend itself at runtime uses
# DB_USER/DB_PASSWORD exclusively. DB_SA_PASSWORD is never read by the app.
#
# Requires sqlcmd on PATH (ships with SQL Server / SSMS / the "sqlcmd" tools
# package). Safe to re-run: every install script is idempotent.

$ErrorActionPreference = "Stop"

foreach ($name in @("DB_SERVER","DB_NAME","DB_USER","DB_PASSWORD","DB_SA_PASSWORD")) {
    if (-not (Test-Path "env:$name") -or [string]::IsNullOrEmpty((Get-Item "env:$name").Value)) {
        throw "$name environment variable is required."
    }
}
if (-not (Test-Path "env:DB_PORT") -or [string]::IsNullOrEmpty($env:DB_PORT)) {
    $env:DB_PORT = "1433"
}

$RepoRoot    = Split-Path -Parent $PSScriptRoot
$InstallDir  = Join-Path $RepoRoot "database\sqlserver\install"
$ServerArg   = "$($env:DB_SERVER),$($env:DB_PORT)"

function Invoke-SaSqlCmd {
    param([string]$Database, [string]$File, [string[]]$ExtraArgs = @())
    $args = @("-S", $ServerArg, "-U", "sa", "-P", $env:DB_SA_PASSWORD, "-C", "-b")
    if ($Database) { $args += @("-d", $Database) }
    $args += $ExtraArgs
    $args += @("-i", $File)
    & sqlcmd @args
    if ($LASTEXITCODE -ne 0) { throw "sqlcmd failed on $File (exit $LASTEXITCODE)" }
}

Write-Host "==> Waiting for SQL Server at $ServerArg..."
$connected = $false
for ($i = 0; $i -lt 30; $i++) {
    & sqlcmd -S $ServerArg -U sa -P $env:DB_SA_PASSWORD -C -Q "SELECT 1" *> $null
    if ($LASTEXITCODE -eq 0) { $connected = $true; break }
    Start-Sleep -Seconds 2
}
if (-not $connected) { throw "SQL Server did not become reachable in time." }
Write-Host "==> SQL Server is reachable."

Write-Host "==> 001_create_database.sql (as sa — creates $($env:DB_NAME) and the $($env:DB_USER) login if needed)"
Invoke-SaSqlCmd -Database $null -File (Join-Path $InstallDir "001_create_database.sql") `
    -ExtraArgs @("-v", "DB_NAME=$($env:DB_NAME)", "-v", "APP_USER=$($env:DB_USER)", "-v", "APP_PASSWORD=$($env:DB_PASSWORD)")

$installFiles = @(
    "002_create_schema.sql", "003_create_indexes.sql", "004_create_constraints.sql",
    "005_create_views.sql", "006_create_stored_procedures.sql", "007_create_triggers.sql",
    "008_seed_lookup_data.sql", "009_seed_configuration.sql", "010_seed_users_roles.sql",
    "011_record_database_version.sql"
)
foreach ($f in $installFiles) {
    Write-Host "==> $f (against $($env:DB_NAME), as sa)"
    Invoke-SaSqlCmd -Database $env:DB_NAME -File (Join-Path $InstallDir $f)
}

Write-Host "==> Verifying installation"
Push-Location (Join-Path $RepoRoot "scripts")
try {
    Invoke-SaSqlCmd -Database $env:DB_NAME -File "verify_database.sql" -ExtraArgs @("-v", "DB_NAME=$($env:DB_NAME)")
} finally {
    Pop-Location
}

Write-Host "==> Database installation complete."

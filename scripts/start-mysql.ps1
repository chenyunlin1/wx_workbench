# Starts the local MySQL 8.4 instance used by LifeOS.
# On the first run the data directory is created and initialized, then the root
# password from backend/.env and the application database are ensured.
#
# NOTE: the data directory lives outside this repository, so the sandboxed shell
# needs full file access the first time it initializes/starts MySQL.
[CmdletBinding()]
param(
  [string]$Base = 'C:\Users\71511\AppData\Local\Programs\MySQL\8.4.9\SourceDir\PFiles64\MySQL\MySQL Server 8.4',
  [string]$DataDir = 'C:\Users\71511\AppData\Local\MySQL\data',
  [string]$LogDir = 'C:\Users\71511\AppData\Local\MySQL\logs',
  [int]$Port = 3306,
  [string]$Password = 'root',
  [string]$Database = 'life_workbench'
)

$ErrorActionPreference = 'Stop'
# The mysql client prints informational warnings on stderr; do not treat those as failures.
$PSNativeCommandUseErrorActionPreference = $false
# Avoid the "password on the command line" warning altogether.
$env:MYSQL_PWD = $Password

$mysqld = Join-Path $Base 'bin\mysqld.exe'
$mysql = Join-Path $Base 'bin\mysql.exe'
if (-not (Test-Path $mysqld)) { throw "mysqld.exe not found under $Base" }

New-Item -ItemType Directory -Force -Path $DataDir, $LogDir | Out-Null

function Test-MySqlPort {
  param([int]$P)
  [bool](Get-NetTCPConnection -State Listen -LocalPort $P -ErrorAction SilentlyContinue)
}

if (Test-MySqlPort -P $Port) {
  Write-Output "MySQL is already running on port $Port."
}
else {
  if (-not (Test-Path (Join-Path $DataDir 'mysql'))) {
    Write-Output 'Data directory is not initialized; creating a fresh MySQL instance.'
    Get-ChildItem -Path $DataDir -Force | Remove-Item -Recurse -Force
    & $mysqld --no-defaults --initialize-insecure --basedir="$Base" --datadir="$DataDir" --console
    if ($LASTEXITCODE -ne 0) { throw 'MySQL data directory initialization failed.' }
    Write-Output 'Data directory initialized.'
  }

  $arguments = "--no-defaults --basedir=`"$Base`" --datadir=`"$DataDir`" --port=$Port --bind-address=127.0.0.1 --mysqlx=0 --log-error=`"$LogDir\server.log`" --pid-file=`"$LogDir\mysql.pid`""
  $process = Start-Process -FilePath $mysqld -ArgumentList $arguments -WindowStyle Hidden -PassThru

  $ready = $false
  for ($i = 0; $i -lt 60; $i++) {
    Start-Sleep -Seconds 1
    if (Test-MySqlPort -P $Port) { $ready = $true; break }
  }
  if (-not $ready) { throw "MySQL failed to start within 60 seconds. See $LogDir\server.log" }
  Write-Output "MySQL started. PID=$($process.Id)"
}

# Right after initialization root has a temporary empty password.
function Invoke-MySqlClient {
  param([string[]]$ClientArgs)
  # Windows PowerShell 5.1 turns native stderr into a terminating error under
  # ErrorActionPreference = 'Stop', so relax it for the client call.
  $previous = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    $text = (& $mysql @ClientArgs 2>&1 | Out-String).Trim()
    return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $text }
  }
  finally { $ErrorActionPreference = $previous }
}

$connection = @('--protocol=TCP', '-h', '127.0.0.1', '-P', $Port, '-u', 'root')

$env:MYSQL_PWD = $Password
$probe = Invoke-MySqlClient -ClientArgs ($connection + @('-e', 'SELECT 1'))
if ($probe.ExitCode -ne 0) {
  Write-Output 'Bootstrapping the root password and the application database.'
  $bootstrap = @"
ALTER USER 'root'@'localhost' IDENTIFIED BY '$Password';
CREATE USER IF NOT EXISTS 'root'@'127.0.0.1' IDENTIFIED BY '$Password';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'127.0.0.1' WITH GRANT OPTION;
CREATE DATABASE IF NOT EXISTS ``$Database`` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
FLUSH PRIVILEGES;
"@
  $env:MYSQL_PWD = ''
  $init = Invoke-MySqlClient -ClientArgs ($connection + @('--skip-password', '-e', $bootstrap))
  $env:MYSQL_PWD = $Password
  if ($init.ExitCode -ne 0) { throw "Failed to bootstrap the root password / application database: $($init.Output)" }
}

$check = Invoke-MySqlClient -ClientArgs ($connection + @('-e', "SHOW DATABASES LIKE '$Database';"))
if ($check.ExitCode -ne 0 -or -not $check.Output) {
  throw "MySQL is running but the application database is not reachable with the configured credentials: $($check.Output)"
}
Write-Output "MySQL is ready on 127.0.0.1:$Port (database: $Database)."

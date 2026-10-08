$ErrorActionPreference = 'Continue'
$log = 'C:\Users\71511\Desktop\code\work\install-tools.log'
Start-Transcript -Path $log -Force | Out-Null

function Write-Step([string]$message) {
  Write-Host "`n===== $message =====" -ForegroundColor Cyan
}

try {
  Write-Step 'Updating winget sources'
  winget source update --accept-source-agreements --disable-interactivity

  Write-Step 'Installing WSL2'
  wsl --install --no-distribution --accept-license

  Write-Step 'Installing MySQL 8.4'
  winget install --exact --id Oracle.MySQL --silent --accept-package-agreements --accept-source-agreements --disable-interactivity

  Write-Step 'Installing Docker Desktop'
  winget install --exact --id Docker.DockerDesktop --silent --accept-package-agreements --accept-source-agreements --disable-interactivity

  Write-Step 'Installation finished'
  winget list --accept-source-agreements | Select-String -Pattern 'MySQL|Docker'
}
catch {
  Write-Host "INSTALL_ERROR: $($_.Exception.Message)" -ForegroundColor Red
}
finally {
  Stop-Transcript | Out-Null
}
$ErrorActionPreference = 'Continue'
$log = 'C:\Users\71511\Desktop\code\work\install-docker.log'
Start-Transcript -Path $log -Force | Out-Null

try {
  Write-Host '===== Installing WSL2 =====' -ForegroundColor Cyan
  wsl --install --no-distribution --accept-license

  Write-Host '===== Installing Docker Desktop =====' -ForegroundColor Cyan
  winget install --exact --id Docker.DockerDesktop --silent --accept-package-agreements --accept-source-agreements --disable-interactivity

  Write-Host '===== Docker installation finished =====' -ForegroundColor Green
  winget list --accept-source-agreements | Select-String -Pattern 'Docker'
}
catch {
  Write-Host "INSTALL_ERROR: $($_.Exception.Message)" -ForegroundColor Red
}
finally {
  Stop-Transcript | Out-Null
  Write-Host 'Press Enter to close...'
  Read-Host
}
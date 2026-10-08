$mysqladmin = 'C:\Users\71511\AppData\Local\Programs\MySQL\8.4.9\SourceDir\PFiles64\MySQL\MySQL Server 8.4\bin\mysqladmin.exe'
if (Get-NetTCPConnection -State Listen -LocalPort 3306 -ErrorAction SilentlyContinue) {
  & $mysqladmin '--protocol=tcp' '--host=127.0.0.1' '--port=3306' '--user=root' '--password=root' shutdown
  Write-Output 'MySQL shutdown requested.'
} else {
  Write-Output 'MySQL is not running.'
}
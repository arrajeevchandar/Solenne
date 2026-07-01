$ErrorActionPreference = "Continue"

$ports = @(5257, 5258, 5260, 5261, 5262, 5263, 5264)

foreach ($port in $ports) {
  Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue |
    Select-Object -ExpandProperty OwningProcess -Unique |
    Where-Object { $_ -and $_ -ne 0 } |
    ForEach-Object {
      Write-Host "Stopping process on port $port: $_"
      Stop-Process -Id $_ -Force -ErrorAction SilentlyContinue
    }
}

Get-Process dart,flutter -ErrorAction SilentlyContinue | ForEach-Object {
  Write-Host "Stopping $($_.ProcessName) $($_.Id)"
  Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
}

Write-Host "Flutter dev processes cleared. Do not run flutter clean unless a build cache is corrupted."

# ==============================================================================
# UTErSpace - CONG CU DONG LINK CLOUDFLARE TUNNEL (TAT PHAT SONG PUBLIC)
# Cu phap:
#   .\stop-cloudflare-tunnel.ps1
#   .\stop-cloudflare-tunnel.ps1 -StopTomcat   (Tat ca Tomcat de nghi ngoi)
# ==============================================================================

param(
    [switch]$StopTomcat = $false
)

$ErrorActionPreference = "Continue"

Write-Host "Dang dung tien trinh Cloudflare Tunnel..." -ForegroundColor Yellow
$cfProcs = Get-Process -Name "cloudflared" -ErrorAction SilentlyContinue
if ($cfProcs) {
    $cfProcs | ForEach-Object {
        Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
    }
    Write-Host "[OK] Da tat Cloudflare Tunnel! Duong link public khong con truy cap duoc nua." -ForegroundColor Green
} else {
    Write-Host "[THONG BAO] Cloudflare Tunnel hien khong chay." -ForegroundColor Cyan
}

if ($StopTomcat) {
    Write-Host "Dang tat Tomcat 9 tren cong 8080 va 8005..." -ForegroundColor Yellow
    Get-NetTCPConnection -LocalPort 8080, 8005 -ErrorAction SilentlyContinue | ForEach-Object {
        Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue
    }
    Write-Host "[OK] Da tat server Tomcat." -ForegroundColor Green
}

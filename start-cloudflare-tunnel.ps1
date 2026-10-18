# ==============================================================================
# UTErSpace - KHOI DONG NHANH CLOUDFLARE TUNNEL (PUBLIC HTTPS DEMO)
# Danh cho repo: D:\UTE\Web Programming\Web_git\uterspace\uterspace
# ==============================================================================

param(
    [int]$Port = 8080
)

$ErrorActionPreference = "Continue"
$ProjectRoot = $PSScriptRoot
$cloudflared = Join-Path $ProjectRoot "tools\cloudflared.exe"
$MysqlBin = Join-Path $ProjectRoot "tools\mysql-8.4.9-winx64\bin"
$MyIni = Join-Path $ProjectRoot "tools\my.ini"

if (-not (Test-Path $cloudflared)) {
    Write-Host "[LOI] Khong tim thay $cloudflared!" -ForegroundColor Red
    exit 1
}

# Dam bao MySQL 8.4 Local luon dang chay truoc khi mo Tunnel
if ((Test-Path "$MysqlBin\mysqld.exe") -and (-not (Get-Process -Name "mysqld" -ErrorAction SilentlyContinue))) {
    Write-Host "[AUTO] Dang khoi dong MySQL 8.4 Local Server (Port 3306)..." -ForegroundColor Yellow
    $cmdLine = "`"$MysqlBin\mysqld.exe`" --defaults-file=`"$MyIni`""
    Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{ CommandLine = $cmdLine } | Out-Null
    Start-Sleep -Seconds 3
}

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "   UTErSpace - CLOUDFLARE TUNNEL PUBLIC HTTPS" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan

# Kiem tra xem Tomcat da chay tren cong 8080 chua
$portCheck = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
if (-not $portCheck) {
    Write-Host "[CANH BAO] Hien tai Tomcat chua chay tren cong $Port!" -ForegroundColor Yellow
    Write-Host " -> Hay dam bao ban da chuot phai vao target/uterspace.war -> Run on Server trong VS Code." -ForegroundColor Yellow
} else {
    Write-Host "[OK] Phat hien Tomcat dang chay tren http://localhost:$Port" -ForegroundColor Green
}

Write-Host "`nDang ket noi toi Cloudflare Edge PoP tai Viet Nam..." -ForegroundColor Cyan
Write-Host " -> Khi thay dong link https://xxxx-xxxx.trycloudflare.com hien ra ben duoi," -ForegroundColor Green
Write-Host "    hay them '/uterspace/' vao cuoi link de gui cho giang vien & nhom test!" -ForegroundColor Green
Write-Host "    Vi du: https://xxxx-xxxx.trycloudflare.com/uterspace/" -ForegroundColor Yellow
Write-Host " -> Nhan Ctrl + C de tat Tunnel khi ket thuc bao cao.`n" -ForegroundColor Gray

& $cloudflared tunnel --url "http://localhost:$Port"

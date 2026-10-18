# ==============================================================================
# UTErSpace - KICH BAN TU DONG CAU HINH MAY CHU (HOST SERVER)
# Danh cho repo: D:\UTE\Web Programming\Web_git\uterspace\uterspace
# Thuc hien:
#   1. Khoi dong MySQL 8.4 Local (0.0.0.0:3306), nap mui gio Asia/Ho_Chi_Minh & quyen tu xa avnadmin@'%'
#   2. Kiem tra Tailscale VPN & lay IP Tailscale (100.x.y.z)
#   3. Mo Windows Firewall cho Port 3306 (MySQL) & Port 8080 (Tomcat)
#   4. Thong nhat IP Tailscale vao persistence.xml + CLAUDE.md + Kiem tra ket noi
# ==============================================================================

param(
    [switch]$ReSyncFromAiven = $false
)

$ErrorActionPreference = "Continue"
$ProjectRoot = $PSScriptRoot
$MysqlDir = Join-Path $ProjectRoot "tools\mysql-8.4.9-winx64"
$MysqlBin = Join-Path $MysqlDir "bin"
$MyIni = Join-Path $ProjectRoot "tools\my.ini"
$BackupSql = Join-Path $ProjectRoot "db\aiven_live_backup.sql"

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "   UTErSpace - TU DONG THIET LAP MAY CHU (LOCAL MYSQL + TAILSCALE)" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan

# --- BUOC 1: KHOI DONG LOCAL MYSQL 8.4, NAP MUI GIO & QUYEN TU XA ---
Write-Host "`n[1/4] Kiem tra MySQL 8.4 Local Server (Port 3306) & Quyen truy cap tu xa..." -ForegroundColor Yellow

if (-not (Get-Process -Name "mysqld" -ErrorAction SilentlyContinue)) {
    Write-Host " -> Dang khoi dong MySQL 8.4 Server tren 0.0.0.0:3306..." -ForegroundColor Cyan
    $cmdLine = "`"$MysqlBin\mysqld.exe`" --defaults-file=`"$MyIni`""
    Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{ CommandLine = $cmdLine } | Out-Null
    Start-Sleep -Seconds 3
}

$dbPass = ""
$tomcatProp = "d:\Tomcat9\apache-tomcat-9.0.121\conf\uterspace-cloud.properties"
if (Test-Path $tomcatProp) {
    Get-Content $tomcatProp | ForEach-Object {
        if ($_ -match '^\s*db\.password\s*=\s*(.+)$') { $dbPass = $Matches[1].Trim() }
    }
}

$setupSql = @"
USE mysql;
DELETE FROM time_zone_name WHERE Name IN ('Asia/Ho_Chi_Minh', 'Asia/Saigon', 'UTC');
DELETE FROM time_zone WHERE Time_zone_id IN (1, 2, 3);
DELETE FROM time_zone_transition_type WHERE Time_zone_id IN (1, 2, 3);
INSERT INTO time_zone (Time_zone_id, Use_leap_seconds) VALUES (1, 'N'), (2, 'N'), (3, 'N');
INSERT INTO time_zone_name (Name, Time_zone_id) VALUES ('Asia/Ho_Chi_Minh', 1), ('Asia/Saigon', 2), ('UTC', 3);
INSERT INTO time_zone_transition_type (Time_zone_id, Transition_type_id, Offset, Is_dst, Abbreviation) VALUES
  (1, 0, 25200, 0, '+07'), (2, 0, 25200, 0, '+07'), (3, 0, 0, 0, 'UTC');
SET GLOBAL time_zone = 'Asia/Ho_Chi_Minh';

CREATE DATABASE IF NOT EXISTS defaultdb CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
CREATE USER IF NOT EXISTS 'avnadmin'@'%' IDENTIFIED BY '$dbPass';
ALTER USER 'avnadmin'@'%' IDENTIFIED BY '$dbPass';
GRANT ALL PRIVILEGES ON *.* TO 'avnadmin'@'%' WITH GRANT OPTION;
CREATE USER IF NOT EXISTS 'avnadmin'@'localhost' IDENTIFIED BY '$dbPass';
ALTER USER 'avnadmin'@'localhost' IDENTIFIED BY '$dbPass';
GRANT ALL PRIVILEGES ON *.* TO 'avnadmin'@'localhost' WITH GRANT OPTION;
FLUSH PRIVILEGES;
"@
$setupSql | & "$MysqlBin\mysql.exe" -h 127.0.0.1 -P 3306 -u root 2>$null

if ($ReSyncFromAiven -or (-not (Test-Path $BackupSql))) {
    Write-Host " -> Dang keo du lieu moi nhat tu Aiven Cloud MySQL ve may..." -ForegroundColor Cyan
    & "$MysqlBin\mysqldump.exe" -h uterspace-uterspace.b.aivencloud.com -P 23135 -u avnadmin "-p$dbPass" --ssl-mode=REQUIRED --single-transaction --routines --triggers --set-gtid-purged=OFF --no-tablespaces --default-character-set=utf8mb4 --result-file="$BackupSql" defaultdb
    cmd.exe /c "`"$MysqlBin\mysql.exe`" -h 127.0.0.1 -P 3306 -u root --default-character-set=utf8mb4 defaultdb < `"$BackupSql`""
}

Write-Host " -> [OK] MySQL 8.4 (0.0.0.0:3306, Timezone Asia/Ho_Chi_Minh, User avnadmin@'%') da san sang!" -ForegroundColor Green

# --- BUOC 2: KIEM TRA TAILSCALE & LAY IP 100.x.y.z ---
Write-Host "`n[2/4] Kiem tra Tailscale VPN..." -ForegroundColor Yellow
$tailscaleExe = "C:\Program Files\Tailscale\tailscale.exe"
$targetDbIp = "127.0.0.1"

if (Test-Path $tailscaleExe) {
    $tsIpRaw = & $tailscaleExe ip -4 2>$null
    if ($LASTEXITCODE -eq 0 -and $tsIpRaw) {
        $targetDbIp = ($tsIpRaw | Select-Object -First 1).Trim()
        Write-Host " -> [OK] Da phat hien IP Tailscale cua may ban: $targetDbIp" -ForegroundColor Green
    } else {
        Write-Host " -> [CHU Y] Tailscale chua dang nhap (NeedsLogin). Tam thoi dung 127.0.0.1 cho may Chu." -ForegroundColor Magenta
        $tsGui = "C:\Program Files\Tailscale\tailscale-ipn.exe"
        if (Test-Path $tsGui) { Start-Process $tsGui }
        Write-Host " -> Sau khi dang nhap Tailscale xong, chay lai .\setup-server-host.ps1 de tu dong dien IP 100.x.y.z vao persistence.xml!" -ForegroundColor Yellow
    }
}

# --- BUOC 3: MO WINDOWS FIREWALL CHO PORT 3306 & 8080 ---
Write-Host "`n[3/4] Kiem tra Windows Firewall cho Port 3306 (MySQL) va 8080 (Tomcat)..." -ForegroundColor Yellow
$rule3306 = netsh advfirewall firewall show rule name="UTErSpace_MySQL_3306" 2>$null
if ($rule3306 -match "UTErSpace_MySQL_3306") {
    Write-Host " -> [OK] Firewall Port 3306 (MySQL) va Port 8080 (Tomcat) da duoc mo san!" -ForegroundColor Green
} else {
    $firewallCmd = "netsh advfirewall firewall add rule name=`"UTErSpace_MySQL_3306`" dir=in action=allow protocol=TCP localport=3306 & netsh advfirewall firewall add rule name=`"UTErSpace_Tomcat_8080`" dir=in action=allow protocol=TCP localport=8080"
    Start-Process "cmd.exe" -ArgumentList "/c $firewallCmd" -Verb RunAs -WindowStyle Hidden -Wait
    Write-Host " -> [OK] Da mo Firewall cho Port 3306 va Port 8080!" -ForegroundColor Green
}

# --- BUOC 4: DONG BO IP VAO persistence.xml & CLAUDE.md ---
Write-Host "`n[4/4] Dong bo dia chi Database ($targetDbIp) vao persistence.xml, Tomcat va CLAUDE.md..." -ForegroundColor Yellow
& (Join-Path $ProjectRoot "set-tailscale-db-ip.ps1") -TailscaleIP $targetDbIp

Write-Host "`n================================================================" -ForegroundColor Cyan
Write-Host "   HOAN TAT THIET LAP MAY CHU (HOST SERVER)!" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Cyan

# ==============================================================================
# UTErSpace - CAP NHAT DU LIEU THAT (62 BAI DANG + AVATAR) VAO MYSQL TREN MAY CHU
# Chay file db\seed\101_real_content.sql (sinh boi db\seed\gen-real-content.js):
#   - Xoa bai demo cu, them 62 bai that (21 video, 31 anh, 10 chu) + binh luan, luot thich, thong bao
#   - Avatar moi cho 24 tai khoan, ten / bio tieng Viet co dau
#   - Anh / video da nam san tren Cloudinary (thu muc uterspace_seed/), KHONG can copy media
# Tu dong SAO LUU database truoc khi chay (db\backup_truoc_seed_<thoi gian>.sql).
#
# Cu phap:
#   .\apply-real-content.ps1
#   .\apply-real-content.ps1 -SkipBackup
#   .\apply-real-content.ps1 -User avnadmin -Password <mat khau>
# Khoi phuc neu can:
#   .\import-database.ps1 -File "db\backup_truoc_seed_<thoi gian>.sql"
# ==============================================================================

param(
    [string]$File = "",
    [string]$Database = "defaultdb",
    [string]$User = "root",
    [string]$Password = "",
    [int]$Port = 3306,
    [string]$MysqlBin = "",
    [switch]$SkipBackup
)

$ErrorActionPreference = "Stop"
$ProjectRoot = $PSScriptRoot

# 1. Tim file SQL: db\seed\101_real_content.sql, hoac nam canh script
if ([string]::IsNullOrWhiteSpace($File)) {
    $File = @((Join-Path $ProjectRoot "db\seed\101_real_content.sql"), (Join-Path $ProjectRoot "101_real_content.sql")) |
        Where-Object { Test-Path $_ } | Select-Object -First 1
} elseif (-not [System.IO.Path]::IsPathRooted($File)) {
    $File = Join-Path $ProjectRoot $File
}
if (-not $File -or -not (Test-Path $File)) {
    Write-Host "[LOI] Khong tim thay db\seed\101_real_content.sql. Giai nen goi cap nhat vao thu muc goc du an uterspace." -ForegroundColor Red
    exit 1
}

# 2. Tim mysql.exe: tools\mysql-8.4.9-winx64\bin (giong import-database.ps1) hoac MySQL trong PATH
if ([string]::IsNullOrWhiteSpace($MysqlBin)) { $MysqlBin = Join-Path $ProjectRoot "tools\mysql-8.4.9-winx64\bin" }
$mysqlExe = Join-Path $MysqlBin "mysql.exe"
$mysqldumpExe = Join-Path $MysqlBin "mysqldump.exe"
if (-not (Test-Path $mysqlExe)) {
    $cmd = Get-Command mysql.exe -ErrorAction SilentlyContinue
    if (-not $cmd) {
        Write-Host "[LOI] Khong tim thay mysql.exe (tools\mysql-8.4.9-winx64\bin hoac PATH). Dung -MysqlBin <thu muc bin>." -ForegroundColor Red
        exit 1
    }
    $mysqlExe = $cmd.Source
    $mysqldumpExe = Join-Path (Split-Path $mysqlExe) "mysqldump.exe"
}

# 3. Dam bao MySQL Local dang bat (giong import-database.ps1)
if (-not (Get-Process -Name "mysqld" -ErrorAction SilentlyContinue)) {
    $myIni = Join-Path $ProjectRoot "tools\my.ini"
    $mysqldExe = Join-Path (Split-Path $mysqlExe) "mysqld.exe"
    if ((Test-Path $myIni) -and (Test-Path $mysqldExe)) {
        Write-Host "MySQL chua chay, dang bat..." -ForegroundColor Cyan
        $cmdLine = "`"$mysqldExe`" --defaults-file=`"$myIni`""
        Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{ CommandLine = $cmdLine } | Out-Null
        Start-Sleep -Seconds 5
    }
}

# 4. Mat khau: neu khong dung root thi doc db.password tu Tomcat conf (giong export-database.ps1)
if ($User -ne "root" -and [string]::IsNullOrWhiteSpace($Password)) {
    $candidateProps = @("d:\Tomcat9\apache-tomcat-9.0.121\conf\uterspace-cloud.properties", "C:\apache-tomcat-9.0.98\conf\uterspace-cloud.properties", "C:\ApacheTomcat\conf\uterspace-cloud.properties")
    foreach ($propPath in $candidateProps) {
        if (Test-Path $propPath) {
            Get-Content $propPath | ForEach-Object { if ($_ -match '^\s*db\.password\s*=\s*(.+)$') { $Password = $Matches[1].Trim() } }
            if ($Password) { break }
        }
    }
}
$conn = @("-h", "127.0.0.1", "-P", "$Port", "-u", $User, "--default-character-set=utf8mb4")
if ($Password) { $conn += "-p$Password" }

# Kiem tra ket noi + dung database truoc khi dong vao du lieu
$check = & $mysqlExe @conn -N -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = '$Database' AND table_name IN ('users','posts','comments','likes','notifications','groups_tbl','group_members','saved_posts','reports','stories');" 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "[LOI] Khong ket noi duoc MySQL ($User@127.0.0.1:$Port): $check" -ForegroundColor Red
    Write-Host "      Thu lai voi: .\apply-real-content.ps1 -User avnadmin -Password <mat khau>" -ForegroundColor Yellow
    exit 1
}
if ("$check".Trim() -ne "10") {
    Write-Host "[LOI] Database '$Database' khong co du cac bang can thiet (tim thay $check/10). Sai ten database?" -ForegroundColor Red
    exit 1
}

# 5. Sao luu
if (-not $SkipBackup) {
    if (-not (Test-Path $mysqldumpExe)) {
        Write-Host "[LOI] Khong tim thay mysqldump.exe de sao luu. Tu sao luu roi chay lai voi -SkipBackup." -ForegroundColor Red
        exit 1
    }
    $backup = Join-Path $ProjectRoot ("db\backup_truoc_seed_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".sql")
    Write-Host "Dang sao luu database '$Database' ..." -ForegroundColor Cyan
    & $mysqldumpExe @conn --routines --triggers --single-transaction "--result-file=$backup" $Database
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $backup) -or (Get-Item $backup).Length -lt 10KB) {
        Write-Host "[LOI] Sao luu that bai, DUNG LAI (chua thay doi gi)." -ForegroundColor Red
        exit 1
    }
    Write-Host "  -> $backup ($([math]::Round((Get-Item $backup).Length / 1KB)) KB)" -ForegroundColor Yellow
}

# 6. Chay SQL (qua cmd.exe de giu nguyen UTF-8, giong import-database.ps1). Script chay trong 1 transaction.
Write-Host "Dang cap nhat du lieu tu $File ..." -ForegroundColor Cyan
$pwArg = if ($Password) { "-p$Password" } else { "" }
cmd.exe /c "`"$mysqlExe`" -h 127.0.0.1 -P $Port -u $User $pwArg --default-character-set=utf8mb4 $Database < `"$File`""
if ($LASTEXITCODE -ne 0) {
    Write-Host "[THAT BAI] MySQL bao loi o tren. Script chay trong transaction nen du lieu chua bi thay doi." -ForegroundColor Red
    Write-Host "Gui nguyen van thong bao loi cho nhom." -ForegroundColor Yellow
    exit 1
}

# 7. Kiem tra ket qua
Write-Host "`n[THANH CONG] Thong ke sau khi cap nhat:" -ForegroundColor Green
& $mysqlExe @conn -t $Database -e @"
SELECT
  (SELECT COUNT(*) FROM posts WHERE post_id BETWEEN 101 AND 162)                         AS bai_moi,
  (SELECT COUNT(*) FROM posts WHERE post_id BETWEEN 101 AND 162 AND media_type = 'VIDEO') AS video,
  (SELECT COUNT(*) FROM posts WHERE post_id BETWEEN 101 AND 162 AND media_type = 'IMAGE') AS anh,
  (SELECT COUNT(*) FROM posts WHERE post_id BETWEEN 101 AND 162 AND media_type IS NULL)   AS chu,
  (SELECT COUNT(*) FROM users WHERE avatar LIKE '%uterspace_seed/avatars%')               AS avatar_moi,
  (SELECT COUNT(*) FROM comments c JOIN posts p ON p.post_id = c.post_id WHERE p.post_id BETWEEN 101 AND 162) AS binh_luan,
  (SELECT COUNT(*) FROM likes l JOIN posts p ON p.post_id = l.post_id WHERE p.post_id BETWEEN 101 AND 162)    AS luot_thich;
"@
Write-Host "Ky vong: bai_moi 62, video 21, anh 31, chu 10, avatar_moi 24." -ForegroundColor Gray
Write-Host "Buoc tiep theo: .\restart-tomcat.ps1 (app tu phan tich cam xuc cho bai moi khi khoi dong)." -ForegroundColor Cyan

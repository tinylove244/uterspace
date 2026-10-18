# ==============================================================================
# UTErSpace - XUAT TOAN BO DU LIEU DATABASE RA FILE .SQL DE CHIA SE CHO BAN BE
# File xuat ra: db/uterspace_data_export.sql
# ==============================================================================

$ErrorActionPreference = "Stop"
$ProjectRoot = $PSScriptRoot
$MysqlBin = Join-Path $ProjectRoot "tools\mysql-8.4.9-winx64\bin"
$ExportFile = Join-Path $ProjectRoot "db\uterspace_data_export.sql"

# Doc mat khau tu Tomcat conf
$dbPass = ""
$candidateProps = @("d:\Tomcat9\apache-tomcat-9.0.121\conf\uterspace-cloud.properties", "C:\apache-tomcat-9.0.98\conf\uterspace-cloud.properties", "C:\ApacheTomcat\conf\uterspace-cloud.properties")
foreach ($propPath in $candidateProps) {
    if (Test-Path $propPath) {
        Get-Content $propPath | ForEach-Object {
            if ($_ -match '^\s*db\.password\s*=\s*(.+)$') { $dbPass = $Matches[1].Trim() }
        }
        if ($dbPass) { break }
    }
}

# Dam bao MySQL Local dang bat
if (-not (Get-Process -Name "mysqld" -ErrorAction SilentlyContinue)) {
    $myIni = Join-Path $ProjectRoot "tools\my.ini"
    $cmdLine = "`"$MysqlBin\mysqld.exe`" --defaults-file=`"$myIni`""
    Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{ CommandLine = $cmdLine } | Out-Null
    Start-Sleep -Seconds 3
}

Write-Host "Dang xuat toan bo 24 bang du lieu tu MySQL Local..." -ForegroundColor Cyan
& "$MysqlBin\mysqldump.exe" -h 127.0.0.1 -P 3306 -u avnadmin "-p$dbPass" --default-character-set=utf8mb4 --routines --triggers --single-transaction --result-file="$ExportFile" defaultdb

if (Test-Path $ExportFile) {
    $sizeKB = [math]::Round((Get-Item $ExportFile).Length / 1KB, 1)
    Write-Host "`n[THANH CONG] Da xuat toan bo Database ra file:" -ForegroundColor Green
    Write-Host "  -> $ExportFile ($sizeKB KB)" -ForegroundColor Yellow
    Write-Host "`nBan co the gui file nay qua Zalo / Drive / Messenger cho ban cua ban!" -ForegroundColor Cyan
    Write-Host "Cac link anh/video da luu san tren Cloudinary nen khi nap file nay se tu dong hien anh day du." -ForegroundColor Gray
} else {
    Write-Host "[THAT BAI] Khong the xuat file du lieu." -ForegroundColor Red
}

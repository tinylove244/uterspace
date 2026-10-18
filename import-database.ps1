# ==============================================================================
# UTErSpace - NAP DU LIEU DATABASE TU FILE .SQL VAO MYSQL LOCAL
# Cu phap:
#   .\import-database.ps1
#   .\import-database.ps1 -File "db\uterspace_data_export.sql"
# ==============================================================================

param(
    [string]$File = "db\uterspace_data_export.sql"
)

$ErrorActionPreference = "Stop"
$ProjectRoot = $PSScriptRoot
$MysqlBin = Join-Path $ProjectRoot "tools\mysql-8.4.9-winx64\bin"
$ImportFile = if ([System.IO.Path]::IsPathRooted($File)) { $File } else { Join-Path $ProjectRoot $File }

if (-not (Test-Path $ImportFile)) {
    Write-Host "[LOI] Khong tim thay file: $ImportFile" -ForegroundColor Red
    exit 1
}

# Dam bao MySQL Local dang bat
if (-not (Get-Process -Name "mysqld" -ErrorAction SilentlyContinue)) {
    $myIni = Join-Path $ProjectRoot "tools\my.ini"
    $cmdLine = "`"$MysqlBin\mysqld.exe`" --defaults-file=`"$myIni`""
    Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{ CommandLine = $cmdLine } | Out-Null
    Start-Sleep -Seconds 3
}

Write-Host "Dang nap du lieu tu $ImportFile vao MySQL Local (defaultdb)..." -ForegroundColor Cyan
cmd.exe /c "`"$MysqlBin\mysql.exe`" -h 127.0.0.1 -P 3306 -u root --default-character-set=utf8mb4 defaultdb < `"$ImportFile`""

Write-Host "`n[THANH CONG] Da nap xong du lieu! Thong ke hien tai:" -ForegroundColor Green
& "$MysqlBin\mysql.exe" -h 127.0.0.1 -P 3306 -u root -e "SELECT 'Users' AS TableName, COUNT(*) AS RowsCount FROM defaultdb.users UNION ALL SELECT 'Posts', COUNT(*) FROM defaultdb.posts UNION ALL SELECT 'Comments', COUNT(*) FROM defaultdb.comments UNION ALL SELECT 'Groups', COUNT(*) FROM defaultdb.groups_tbl;"

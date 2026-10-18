# ==============================================================================
# UTErSpace - CONG CU DONG BO IP TAILSCALE TRONG persistence.xml & CLAUDE.md
# Thong nhat 1 dia chi Database chung cho ca May Chu va May ban cung nhom (Claude)
#
# Cu phap:
#   .\set-tailscale-db-ip.ps1 -TailscaleIP 100.x.y.z
#   .\set-tailscale-db-ip.ps1 -TailscaleIP 127.0.0.1
#   .\set-tailscale-db-ip.ps1 -TailscaleIP aiven
# ==============================================================================

param(
    [Parameter(Mandatory=$true, HelpMessage="Nhap IP Tailscale cua May Chu (vd: 100.85.12.34) hoac '127.0.0.1' hoac 'aiven'")]
    [string]$TailscaleIP
)

$ErrorActionPreference = "Stop"
$ProjectRoot = $PSScriptRoot

if ($TailscaleIP -eq "aiven") {
    $newJdbcUrl = "jdbc:mysql://uterspace-uterspace.b.aivencloud.com:23135/defaultdb?sslMode=REQUIRED&characterEncoding=UTF-8&connectionTimeZone=Asia/Ho_Chi_Minh&forceConnectionTimeZoneToSession=true&useLocalSessionState=true"
    $poolSize = "10"
    $modeDesc = "Aiven Cloud MySQL (uterspace-uterspace.b.aivencloud.com:23135)"
} else {
    $newJdbcUrl = "jdbc:mysql://${TailscaleIP}:3306/defaultdb?useSSL=false&allowPublicKeyRetrieval=true&characterEncoding=UTF-8&connectionTimeZone=Asia/Ho_Chi_Minh&forceConnectionTimeZoneToSession=true&useLocalSessionState=true"
    $poolSize = "20"
    $modeDesc = "MySQL 8.4 tren May Chu (${TailscaleIP}:3306/defaultdb)"
}

# 1. Cap nhat src/main/resources/META-INF/persistence.xml (va cac ban da build trong target / Tomcat webapps)
$persistenceFiles = @(
    (Join-Path $ProjectRoot "src\main\resources\META-INF\persistence.xml"),
    (Join-Path $ProjectRoot "target\classes\META-INF\persistence.xml"),
    (Join-Path $ProjectRoot "target\uterspace\WEB-INF\classes\META-INF\persistence.xml"),
    "d:\Tomcat9\apache-tomcat-9.0.121\webapps\uterspace\WEB-INF\classes\META-INF\persistence.xml"
)

foreach ($pFile in $persistenceFiles) {
    if (Test-Path $pFile) {
        [xml]$xmlDoc = Get-Content -Path $pFile -Encoding UTF8
        $props = $xmlDoc.persistence.'persistence-unit'.properties.property
        foreach ($prop in $props) {
            if ($prop.name -eq "javax.persistence.jdbc.url") {
                $prop.value = $newJdbcUrl
            }
            if ($prop.name -eq "hibernate.hikari.maximumPoolSize") {
                $prop.value = $poolSize
            }
        }
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        $sw = New-Object System.IO.StreamWriter($pFile, $false, $utf8NoBom)
        $xmlDoc.Save($sw)
        $sw.Close()
        Write-Host "[OK] Da cap nhat persistence.xml: $pFile" -ForegroundColor Green
    }
}

# 2. Dam bao uterspace-cloud.properties trong Tomcat KHONG ghi de db.url (de dung chung persistence.xml)
$candidateProps = @(
    "d:\Tomcat9\apache-tomcat-9.0.121\conf\uterspace-cloud.properties",
    "C:\apache-tomcat-9.0.98\conf\uterspace-cloud.properties",
    "C:\ApacheTomcat\conf\uterspace-cloud.properties"
)
$rspServersDir = "$env:USERPROFILE\.rsp\redhat-community-server-connector\servers"
if (Test-Path $rspServersDir) {
    Get-ChildItem -Path $rspServersDir -File | ForEach-Object {
        $json = Get-Content $_.FullName -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
        if ($json -and $json.'server.base.dir') {
            $p = Join-Path $json.'server.base.dir' "conf\uterspace-cloud.properties"
            if ($candidateProps -notcontains $p) { $candidateProps += $p }
        }
    }
}

foreach ($propPath in $candidateProps) {
    if (Test-Path $propPath) {
        $lines = Get-Content $propPath -Encoding UTF8 | Where-Object { $_ -notmatch '^\s*db\.url\s*=' -and $_ -notmatch '^\s*db\.poolSize\s*=' }
        $lines += "db.poolSize=$poolSize"
        [System.IO.File]::WriteAllLines($propPath, $lines, (New-Object System.Text.UTF8Encoding($false)))
        Write-Host "[OK] Da dong bo Tomcat config: $propPath" -ForegroundColor Green
    }
}

# 3. Cap nhat IP Tailscale trong CLAUDE.md neu co
$claudeMd = Join-Path $ProjectRoot "CLAUDE.md"
if ((Test-Path $claudeMd) -and ($TailscaleIP -ne "aiven")) {
    $mdText = Get-Content -Path $claudeMd -Raw -Encoding UTF8
    $mdText = $mdText -replace '(?<=Host IP Tailscale[^`]*`)[0-9\.]+(?=`)', $TailscaleIP
    [System.IO.File]::WriteAllText($claudeMd, $mdText, (New-Object System.Text.UTF8Encoding($false)))
    Write-Host "[OK] Da cap nhat IP ($TailscaleIP) trong CLAUDE.md" -ForegroundColor Green
}

Write-Host "`n -> Che do Database hien tai: $modeDesc" -ForegroundColor Cyan
Write-Host " -> Kiem tra ket noi ngay bang run-sql.ps1..." -ForegroundColor Yellow
& (Join-Path $ProjectRoot "run-sql.ps1") -Query "SELECT 'Ket noi DB thanh cong!' AS Status, @@hostname AS ServerHost, @@time_zone AS TimeZone, (SELECT COUNT(*) FROM users) AS TotalUsers, (SELECT COUNT(*) FROM posts) AS TotalPosts;"

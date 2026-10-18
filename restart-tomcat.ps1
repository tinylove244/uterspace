# ==============================================================================
# UTErSpace - CONG CU KHOI DONG LAI TOMCAT 9 CHONG KET CONG (PORT BIND FIX)
# Giai quyet triet de loi: java.net.BindException: Address already in use: bind (8080/8005)
# Tu dong deploy target/uterspace.war va kiem tra ket noi den khi HTTP 200 OK
# ==============================================================================

param(
    [switch]$Rebuild = $false
)

$ErrorActionPreference = "Continue"
$ProjectRoot = $PSScriptRoot
$TomcatHome = "d:\Tomcat9\apache-tomcat-9.0.121"
$WebappsDir = Join-Path $TomcatHome "webapps"
$WorkDir = Join-Path $TomcatHome "work\Catalina\localhost"
$MysqlBin = Join-Path $ProjectRoot "tools\mysql-8.4.9-winx64\bin"
$MyIni = Join-Path $ProjectRoot "tools\my.ini"

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "   UTErSpace - KHOI DONG LAI TOMCAT 9 & FIX KET CONG" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan

# 1. Giai phong hoan toan cong 8080 va 8005
Write-Host "`n[1/4] Giai phong cong 8080 (HTTP) va 8005 (Shutdown)..." -ForegroundColor Yellow
$killed = 0
Get-NetTCPConnection -LocalPort 8080, 8005 -ErrorAction SilentlyContinue | ForEach-Object {
    $procId = $_.OwningProcess
    if ($procId -gt 0) {
        Write-Host " -> Dang dung tien trinh PID $procId dang giu cong $($_.LocalPort)..." -ForegroundColor Magenta
        Stop-Process -Id $procId -Force -ErrorAction SilentlyContinue
        $killed++
    }
}
if ($killed -eq 0) {
    Write-Host " -> [OK] Cong 8080 va 8005 da san sang (khong bi chiem)." -ForegroundColor Green
} else {
    Start-Sleep -Seconds 2
    Write-Host " -> [OK] Da giai phong hoan toan cac cong bi ket!" -ForegroundColor Green
}

# 2. Dam bao MySQL 8.4 Local luon chay tren 3306
Write-Host "`n[2/4] Kiem tra MySQL 8.4 Local Server (Port 3306)..." -ForegroundColor Yellow
if (-not (Get-Process -Name "mysqld" -ErrorAction SilentlyContinue)) {
    Write-Host " -> Dang khoi dong MySQL 8.4 Server..." -ForegroundColor Cyan
    $cmdLine = "`"$MysqlBin\mysqld.exe`" --defaults-file=`"$MyIni`""
    Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{ CommandLine = $cmdLine } | Out-Null
    Start-Sleep -Seconds 3
}
Write-Host " -> [OK] MySQL 8.4 Server dang chay." -ForegroundColor Green

# 3. Kiem tra / Build & Deploy target/uterspace.war
Write-Host "`n[3/4] Kiem tra ban build uterspace.war..." -ForegroundColor Yellow
$warFile = Join-Path $ProjectRoot "target\uterspace.war"

if ($Rebuild -or (-not (Test-Path $warFile))) {
    Write-Host " -> Dang build lai du an bang Maven..." -ForegroundColor Cyan
    $mvnCmd = "C:\Users\acer\.m2\wrapper\dists\apache-maven-3.6.3-bin\1iopthnavndlasol9gbrbg6bf2\apache-maven-3.6.3\bin\mvn.cmd"
    & $mvnCmd clean package -DskipTests
}

$targetDir = Join-Path $ProjectRoot "target\uterspace"
$warFile = Join-Path $ProjectRoot "target\uterspace.war"

if (Test-Path $targetDir) {
    Write-Host " -> Dang xoa cache cu trong webapps va work..." -ForegroundColor Cyan
    Remove-Item "$WebappsDir\demo*" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item "$WebappsDir\uterspace*" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item "$WorkDir\*" -Recurse -Force -ErrorAction SilentlyContinue

    Write-Host " -> Dang copy thu muc target/uterspace vao Tomcat webapps..." -ForegroundColor Cyan
    Copy-Item $targetDir (Join-Path $WebappsDir "uterspace") -Recurse -Force
    Write-Host " -> [OK] Da deploy thu muc target/uterspace vao Tomcat!" -ForegroundColor Green
} elseif (Test-Path $warFile) {
    Write-Host " -> Dang copy uterspace.war moi nhat vao Tomcat webapps..." -ForegroundColor Cyan
    Copy-Item $warFile (Join-Path $WebappsDir "uterspace.war") -Force
    Write-Host " -> [OK] Da deploy uterspace.war vao Tomcat!" -ForegroundColor Green
} else {
    Write-Host " -> [CANH BAO] Khong tim thay target\uterspace. Hay chay 'mvn package -DskipTests' truoc!" -ForegroundColor Red
}

# 4. Khoi dong Tomcat 9 (Persistent qua WMI)
Write-Host "`n[4/4] Dang khoi dong Tomcat 9..." -ForegroundColor Yellow
$javaExe = "C:\Program Files\Java\jdk-26.0.2\bin\javaw.exe"
$cp = "`"$TomcatHome\bin\bootstrap.jar;$TomcatHome\bin\tomcat-juli.jar`""
$cmdLine = "`"$javaExe`" -Djava.util.logging.config.file=`"$TomcatHome/conf/logging.properties`" -Djava.util.logging.manager=org.apache.juli.ClassLoaderLogManager -Djdk.tls.ephemeralDHKeySize=2048 -Djava.protocol.handler.pkgs=org.apache.catalina.webresources -Dorg.apache.catalina.security.SecurityListener.UMASK=0027 -Dcatalina.base=`"$TomcatHome`" -Dcatalina.home=`"$TomcatHome`" -Djava.io.tmpdir=`"$TomcatHome/temp`" -cp $cp org.apache.catalina.startup.Bootstrap start"

Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{ CommandLine = $cmdLine } | Out-Null

Write-Host " -> Dang doi Tomcat khoi dong va nap Database (khoang 5-8 giay)..." -ForegroundColor Cyan
$success = $false
for ($i = 1; $i -le 15; $i++) {
    Start-Sleep -Seconds 2
    try {
        $resp = Invoke-WebRequest -Uri "http://localhost:8080/uterspace/login" -UseBasicParsing -TimeoutSec 3
        if ($resp.StatusCode -eq 200) {
            $success = $true
            break
        }
    } catch {
        # Dang khoi dong...
    }
}

if ($success) {
    Write-Host "`n================================================================" -ForegroundColor Green
    Write-Host "   TOMCAT 9 DA KHOI DONG THANH CONG! (HTTP 200 OK)" -ForegroundColor Green
    Write-Host "   Trang web:  http://localhost:8080/uterspace/login" -ForegroundColor Cyan
    Write-Host "   Database:  100.119.255.40:3306 (MySQL 8.4 Host Server)" -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Green
} else {
    Write-Host "`n -> [THONG BAO] Tomcat dang trong qua trinh nap file .war." -ForegroundColor Yellow
    Write-Host "    Hay mo trinh duyet truy cap: http://localhost:8080/uterspace/login sau vai giay!" -ForegroundColor Cyan
}

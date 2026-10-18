# ==============================================================================
# UTErSpace - CONG CU CHAY SQL TRUC TIEP CHO CLAUDE CODE & TEAM DEV (KHONG CAN CAI MYSQL CLI)
# Tu dong doc JDBC URL tu src/main/resources/META-INF/persistence.xml
# va su dung mysql-connector-j co san trong project de truy van Database tren May Chu qua Tailscale!
#
# Cu phap:
#   .\run-sql.ps1 -Query "SHOW TABLES;"
#   .\run-sql.ps1 -Query "SELECT * FROM users LIMIT 5;"
#   .\run-sql.ps1 -File "db\aiven_mysql_migration.sql"
# ==============================================================================

param(
    [string]$Query = "",
    [string]$File = ""
)

$ErrorActionPreference = "Stop"
$ProjectRoot = $PSScriptRoot

if ([string]::IsNullOrWhiteSpace($Query) -and [string]::IsNullOrWhiteSpace($File)) {
    Write-Host "Cu phap su dung:" -ForegroundColor Yellow
    Write-Host "  .\run-sql.ps1 -Query `"SELECT * FROM users LIMIT 5;`"" -ForegroundColor Cyan
    Write-Host "  .\run-sql.ps1 -File `"db\aiven_mysql_migration.sql`"" -ForegroundColor Cyan
    exit 1
}

if (-not [string]::IsNullOrWhiteSpace($File)) {
    $resolvedFile = if ([System.IO.Path]::IsPathRooted($File)) { $File } else { Join-Path $ProjectRoot $File }
    if (-not (Test-Path $resolvedFile)) {
        Write-Host "[LOI] Khong tim thay file SQL: $resolvedFile" -ForegroundColor Red
        exit 1
    }
    $Query = Get-Content -Path $resolvedFile -Raw -Encoding UTF8
}

# 1. Doc JDBC URL tu persistence.xml
$persistenceXml = Join-Path $ProjectRoot "src\main\resources\META-INF\persistence.xml"
[xml]$xmlDoc = Get-Content -Path $persistenceXml -Encoding UTF8
$urlProp = $xmlDoc.persistence.'persistence-unit'.properties.property | Where-Object { $_.name -eq "javax.persistence.jdbc.url" }
$jdbcUrl = $urlProp.value
if (-not $jdbcUrl.Contains("allowMultiQueries=")) {
    $jdbcUrl += "&allowMultiQueries=true"
}

# 2. Tim mysql-connector-j-*.jar trong target hoac .m2 repository
$mysqlJar = Get-ChildItem -Path (Join-Path $ProjectRoot "target") -Filter "mysql-connector-j-*.jar" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $mysqlJar) {
    $mysqlJar = Get-ChildItem -Path "$env:USERPROFILE\.m2\repository\com\mysql\mysql-connector-j" -Filter "mysql-connector-j-*.jar" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
}
if (-not $mysqlJar) {
    Write-Host "[LOI] Chua tim thay mysql-connector-j.jar. Hay chay 'mvn package -DskipTests' 1 lan truoc." -ForegroundColor Red
    exit 1
}

# 3. Tim java.exe
$javaExe = "java"
if (Test-Path "C:\Program Files\Java\jdk-26.0.2\bin\java.exe") {
    $javaExe = "C:\Program Files\Java\jdk-26.0.2\bin\java.exe"
}

# 4. Tao chuong trinh Java nho gon chay truc tiep qua JDBC
$tempJava = Join-Path $env:TEMP "UterSqlRunner_$([guid]::NewGuid().ToString('N')).java"
$tempSql = Join-Path $env:TEMP "UterSqlQuery_$([guid]::NewGuid().ToString('N')).sql"
[System.IO.File]::WriteAllText($tempSql, $Query, (New-Object System.Text.UTF8Encoding($false)))

$javaCode = @"
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.sql.*;

public class UterSqlRunner {
    public static void main(String[] args) throws Exception {
        String url = args[0];
        String user = args[1];
        String pass = args[2];
        String sql = new String(Files.readAllBytes(Paths.get(args[3])), StandardCharsets.UTF_8);

        try (Connection conn = DriverManager.getConnection(url, user, pass);
             Statement stmt = conn.createStatement()) {
            boolean hasResultSet = stmt.execute(sql);
            int updateCount = stmt.getUpdateCount();
            while (hasResultSet || updateCount != -1) {
                if (hasResultSet) {
                    try (ResultSet rs = stmt.getResultSet()) {
                        ResultSetMetaData meta = rs.getMetaData();
                        int cols = meta.getColumnCount();
                        StringBuilder header = new StringBuilder();
                        for (int i = 1; i <= cols; i++) {
                            if (i > 1) header.append("\t");
                            header.append(meta.getColumnLabel(i));
                        }
                        System.out.println(header);
                        System.out.println("-".repeat(Math.min(header.length() + cols * 4, 100)));
                        int rows = 0;
                        while (rs.next()) {
                            StringBuilder row = new StringBuilder();
                            for (int i = 1; i <= cols; i++) {
                                if (i > 1) row.append("\t");
                                Object val = rs.getObject(i);
                                row.append(val == null ? "NULL" : val.toString().replace("\r", " ").replace("\n", " "));
                            }
                            System.out.println(row);
                            rows++;
                        }
                        System.out.println("(" + rows + " rows)");
                    }
                } else {
                    System.out.println("(Query OK, " + updateCount + " rows affected)");
                }
                hasResultSet = stmt.getMoreResults();
                updateCount = stmt.getUpdateCount();
            }
        }
    }
}
"@
[System.IO.File]::WriteAllText($tempJava, $javaCode, (New-Object System.Text.UTF8Encoding($false)))

# 4. Doc db.user va db.password tu Tomcat conf/uterspace-cloud.properties
$dbUser = "avnadmin"
$dbPass = $env:UTERSPACE_DB_PASSWORD
$candidateProps = @("d:\Tomcat9\apache-tomcat-9.0.121\conf\uterspace-cloud.properties", "C:\apache-tomcat-9.0.98\conf\uterspace-cloud.properties", "C:\ApacheTomcat\conf\uterspace-cloud.properties")
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
        Get-Content $propPath | ForEach-Object {
            if ($_ -match '^\s*db\.user\s*=\s*(.+)$') { $dbUser = $Matches[1].Trim() }
            if ($_ -match '^\s*db\.password\s*=\s*(.+)$') { $dbPass = $Matches[1].Trim() }
        }
        if ($dbPass) { break }
    }
}

try {
    & $javaExe -cp $mysqlJar.FullName $tempJava $jdbcUrl $dbUser $dbPass $tempSql
} finally {
    Remove-Item $tempJava -Force -ErrorAction SilentlyContinue
    Remove-Item $tempSql -Force -ErrorAction SilentlyContinue
}

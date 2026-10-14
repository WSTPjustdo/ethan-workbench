$ErrorActionPreference = 'Stop'
$workspace = Split-Path $PSScriptRoot -Parent
$runtime = Join-Path $workspace '.local-runtime'
$source = Join-Path $workspace 'qihang-erp-local'
$repository = [uri]'https://repo.maven.apache.org'
$proxy = [System.Net.WebRequest]::DefaultWebProxy.GetProxy($repository)
$settings = '<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0"></settings>'
if ($proxy.Host -ne $repository.Host) {
    $settings = '<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0"><proxies><proxy><id>system-proxy</id><active>true</active><protocol>http</protocol><host>' + $proxy.Host + '</host><port>' + $proxy.Port + '</port><nonProxyHosts>localhost|127.0.0.1</nonProxyHosts></proxy></proxies></settings>'
}
$settings | Set-Content "$runtime\config\maven-settings.xml" -Encoding UTF8
Push-Location $source
try {
    & "$runtime\apache-maven-3.9.11\bin\mvn.cmd" -s "$runtime\config\maven-settings.xml" -B -ntp "-Dmaven.repo.local=$runtime\m2" package
    if ($LASTEXITCODE -ne 0) { throw 'Backend build failed.' }
    Set-Location "$source\vue3"
    & npm.cmd ci --no-audit --no-fund
    if ($LASTEXITCODE -ne 0) { throw 'Frontend dependency installation failed.' }
    & npm.cmd run build
    if ($LASTEXITCODE -ne 0) { throw 'Frontend build failed.' }
} finally { Pop-Location }

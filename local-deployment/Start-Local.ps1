param([switch]$OpenBrowser)
$ErrorActionPreference = 'Stop'
$workspace = Split-Path $PSScriptRoot -Parent
$runtime = Join-Path $workspace '.local-runtime'
$source = Join-Path $workspace 'qihang-erp-local'
$asciiRuntime = Join-Path $env:USERPROFILE '.codex\.tmp\qihang-erp-local-runtime'
if (-not (Test-Path -LiteralPath $asciiRuntime)) {
    New-Item -ItemType Junction -Path $asciiRuntime -Target $runtime | Out-Null
}
if (-not (Test-Path "$runtime\config\application-local.yml")) {
    throw 'Local configuration is missing. Do not reinitialize an existing database.'
}

function Get-Listener([int]$Port) {
    Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue | Select-Object -First 1
}
function Assert-LocalOwner([int]$Port) {
    $listener = Get-Listener $Port
    if (-not $listener) { return $false }
    $process = Get-CimInstance Win32_Process -Filter "ProcessId=$($listener.OwningProcess)"
    $owned = ($process.ExecutablePath -and (
        $process.ExecutablePath.StartsWith($runtime, [StringComparison]::OrdinalIgnoreCase) -or
        $process.ExecutablePath.StartsWith($asciiRuntime, [StringComparison]::OrdinalIgnoreCase))) -or
        ($process.CommandLine -and $process.CommandLine.Contains($source))
    if (-not $owned) { throw "Port $Port is occupied by another application (PID $($listener.OwningProcess))." }
    return $true
}
function Wait-Port([int]$Port, [int]$Seconds = 60) {
    $deadline = (Get-Date).AddSeconds($Seconds)
    while ((Get-Date) -lt $deadline) {
        if (Get-Listener $Port) { return }
        Start-Sleep -Seconds 1
    }
    throw "Port $Port did not start. Check $runtime\logs."
}
function Start-Hidden([string]$Name, [string]$Executable, [string]$Arguments, [string]$Directory) {
    $process = Start-Process -FilePath $Executable -ArgumentList $Arguments -WorkingDirectory $Directory `
        -WindowStyle Hidden -PassThru -RedirectStandardOutput "$runtime\logs\$Name.log" `
        -RedirectStandardError "$runtime\logs\$Name-error.log"
    $process.Id | Set-Content "$runtime\$Name.pid"
}

Write-Host '[1/4] Checking local database...'
if (-not (Assert-LocalOwner 13306)) {
    Start-Hidden 'mysql' "$asciiRuntime\mysql-8.4.9-winx64\bin\mysqld.exe" "--defaults-file=$asciiRuntime\config\my.ini" $asciiRuntime
    Wait-Port 13306
}
Write-Host '[2/4] Checking local cache...'
if (-not (Assert-LocalOwner 16379)) {
    Start-Hidden 'redis' "$asciiRuntime\redis\Redis-7.4.2-Windows-x64-msys2\redis-server.exe" `
        '--bind 127.0.0.1 --port 16379 --protected-mode yes --appendonly yes' "$runtime\data\redis"
    Wait-Port 16379
}
Write-Host '[3/4] Starting ERP backend (first start may take 1-2 minutes)...'
if (-not (Assert-LocalOwner 6149)) {
    $jar = Get-ChildItem "$source\erp-api\target\erp-api-*.jar" | Select-Object -First 1
    if (-not $jar) { throw 'Backend JAR missing. Run Build-Local.ps1 first.' }
    $java = (Get-Command java.exe).Source
    $configPath = $asciiRuntime.Replace('\', '/') + '/config/'
    Start-Hidden 'backend' $java "-Xms256m -Xmx1536m -jar `"$($jar.FullName)`" --spring.profiles.active=local --spring.config.additional-location=file:$configPath" $source
    Wait-Port 6149 180
}
Write-Host '[4/4] Checking workbench page...'
if (-not (Assert-LocalOwner 5188)) {
    $node = (Get-Command node.exe).Source
    Start-Hidden 'frontend' $node "`"$source\vue3\node_modules\vite\bin\vite.js`" --host 127.0.0.1 --port 5188 --strictPort" "$source\vue3"
    Wait-Port 5188
}
$response = Invoke-RestMethod 'http://127.0.0.1:5188/api/sys-api/captchaImage'
if ($response.code -ne 200) { throw 'Frontend-to-backend health check failed.' }
Write-Host 'Ethan workbench is ready: http://127.0.0.1:5188'
Write-Host 'Test database only. Scheduled jobs are disabled.'
if ($OpenBrowser) { Start-Process 'http://127.0.0.1:5188' }

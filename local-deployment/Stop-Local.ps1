$ErrorActionPreference = 'Stop'
$workspace = Split-Path $PSScriptRoot -Parent
$runtime = Join-Path $workspace '.local-runtime'
$source = Join-Path $workspace 'qihang-erp-local'
$asciiRuntime = Join-Path $env:USERPROFILE '.codex\.tmp\qihang-erp-local-runtime'
foreach ($port in @(5188, 6149, 16379, 13306)) {
    $listener = Get-NetTCPConnection -State Listen -LocalPort $port -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $listener) { continue }
    $process = Get-CimInstance Win32_Process -Filter "ProcessId=$($listener.OwningProcess)"
    $owned = ($process.ExecutablePath -and (
        $process.ExecutablePath.StartsWith($runtime, [StringComparison]::OrdinalIgnoreCase) -or
        $process.ExecutablePath.StartsWith($asciiRuntime, [StringComparison]::OrdinalIgnoreCase))) -or
        ($process.CommandLine -and $process.CommandLine.Contains($source))
    if (-not $owned) { throw "Port $port belongs to a different application; left running." }
    if ($port -eq 13306) {
        & "$asciiRuntime\mysql-8.4.9-winx64\bin\mysqladmin.exe" "--defaults-file=$asciiRuntime\config\mysql-admin.ini" shutdown
        if ($LASTEXITCODE -ne 0) { throw 'MySQL shutdown failed.' }
    } elseif ($port -eq 16379) {
        & "$asciiRuntime\redis\Redis-7.4.2-Windows-x64-msys2\redis-cli.exe" -p 16379 shutdown save
        if ($LASTEXITCODE -ne 0) { throw 'Redis shutdown failed.' }
    } else {
        Stop-Process -Id $listener.OwningProcess
    }
    Write-Host "Stopped local service on port $port."
}
Write-Host 'Database files have been preserved.'

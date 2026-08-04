# Poll for local changes and auto-push to GitHub
$ErrorActionPreference = 'Continue'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$pushScript = Join-Path $PSScriptRoot 'auto-push.ps1'
$pidFile = Join-Path $PSScriptRoot '.watch.pid'

$gitCmd = $null
$gitFromPath = Get-Command git -ErrorAction SilentlyContinue
if ($gitFromPath) {
    $gitCmd = $gitFromPath.Source
} elseif (Test-Path 'C:\Program Files\Git\cmd\git.exe') {
    $gitCmd = 'C:\Program Files\Git\cmd\git.exe'
} else {
    Write-Host 'git not found; watcher exiting'
    exit 1
}

if (Test-Path $pidFile) {
    $oldPid = Get-Content $pidFile -ErrorAction SilentlyContinue
    if ($oldPid) {
        $proc = Get-Process -Id $oldPid -ErrorAction SilentlyContinue
        if ($proc) {
            Write-Host "Auto-push watcher already running (PID $oldPid)"
            exit 0
        }
    }
}
Set-Content -Path $pidFile -Value $PID

Write-Host "Watching $repoRoot for changes (auto-push every few seconds when dirty)"

try {
    while ($true) {
        Start-Sleep -Seconds 5
        Set-Location -LiteralPath $repoRoot
        $status = & $gitCmd status --porcelain 2>$null
        if ($status) {
            & powershell -NoProfile -ExecutionPolicy Bypass -File $pushScript
        }
    }
}
finally {
    Remove-Item $pidFile -Force -ErrorAction SilentlyContinue
}

# Watch workspace files and auto-push shortly after saves
$ErrorActionPreference = 'Continue'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$pushScript = Join-Path $PSScriptRoot 'auto-push.ps1'
$pidFile = Join-Path $PSScriptRoot '.watch.pid'

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

$script:pending = $false
$script:pushScript = $pushScript
$script:repoRoot = $repoRoot

function Should-Skip([string]$path) {
    if ($path -match '\\.git\\') { return $true }
    if ($path -match '\\.cursor\\hooks\\\.auto-push\.lock$') { return $true }
    if ($path -match '\\.cursor\\hooks\\\.watch\.pid$') { return $true }
    return $false
}

function Queue-Push {
    $script:pending = $true
}

$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = $repoRoot
$watcher.IncludeSubdirectories = $true
$watcher.Filter = '*.*'
$watcher.NotifyFilter = [IO.NotifyFilters]::FileName -bor [IO.NotifyFilters]::LastWrite -bor [IO.NotifyFilters]::Size
$watcher.EnableRaisingEvents = $true

$null = Register-ObjectEvent -InputObject $watcher -EventName Changed -SourceIdentifier AutoPushChanged -Action {
    if (-not (Should-Skip $Event.SourceEventArgs.FullPath)) { Queue-Push }
}
$null = Register-ObjectEvent -InputObject $watcher -EventName Created -SourceIdentifier AutoPushCreated -Action {
    if (-not (Should-Skip $Event.SourceEventArgs.FullPath)) { Queue-Push }
}
$null = Register-ObjectEvent -InputObject $watcher -EventName Renamed -SourceIdentifier AutoPushRenamed -Action {
    if (-not (Should-Skip $Event.SourceEventArgs.FullPath)) { Queue-Push }
}
$null = Register-ObjectEvent -InputObject $watcher -EventName Deleted -SourceIdentifier AutoPushDeleted -Action {
    if (-not (Should-Skip $Event.SourceEventArgs.FullPath)) { Queue-Push }
}

Write-Host "Watching $repoRoot for changes (auto-push enabled)"

try {
    while ($true) {
        Start-Sleep -Seconds 3
        if ($script:pending) {
            $script:pending = $false
            & powershell -NoProfile -ExecutionPolicy Bypass -File $script:pushScript
        }
    }
}
finally {
    Unregister-Event -SourceIdentifier AutoPushChanged -ErrorAction SilentlyContinue
    Unregister-Event -SourceIdentifier AutoPushCreated -ErrorAction SilentlyContinue
    Unregister-Event -SourceIdentifier AutoPushRenamed -ErrorAction SilentlyContinue
    Unregister-Event -SourceIdentifier AutoPushDeleted -ErrorAction SilentlyContinue
    $watcher.EnableRaisingEvents = $false
    $watcher.Dispose()
    Remove-Item $pidFile -Force -ErrorAction SilentlyContinue
}

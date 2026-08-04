# Poll for index.html changes and auto-deploy to Cloudflare Pages
$ErrorActionPreference = 'Continue'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$pushScript = Join-Path $PSScriptRoot 'auto-push.ps1'
$pidFile = Join-Path $PSScriptRoot '.watch.pid'

if (Test-Path $pidFile) {
    $oldPid = Get-Content $pidFile -ErrorAction SilentlyContinue
    if ($oldPid) {
        $proc = Get-Process -Id $oldPid -ErrorAction SilentlyContinue
        if ($proc) {
            Write-Host "Auto-deploy watcher already running (PID $oldPid)"
            exit 0
        }
    }
}
Set-Content -Path $pidFile -Value $PID

$env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path', 'User')

Write-Host "Watching $repoRoot for changes (Cloudflare auto-deploy)"

try {
    $lastHash = $null
    $indexPath = Join-Path $repoRoot 'index.html'
    while ($true) {
        Start-Sleep -Seconds 5
        if (-not (Test-Path -LiteralPath $indexPath)) { continue }
        $hash = (Get-FileHash -LiteralPath $indexPath -Algorithm SHA256).Hash
        if ($lastHash -and ($hash -ne $lastHash)) {
            & powershell -NoProfile -ExecutionPolicy Bypass -File $pushScript
        }
        $lastHash = $hash
    }
}
finally {
    Remove-Item $pidFile -Force -ErrorAction SilentlyContinue
}

# Auto commit + push local changes to GitHub (Cloudflare deploys from GitHub)
$ErrorActionPreference = 'Continue'

# Consume hook stdin (JSON) so the pipe does not hang
try { [void][Console]::In.ReadToEnd() } catch { }

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
Set-Location -LiteralPath $repoRoot

$gitCmd = $null
$gitFromPath = Get-Command git -ErrorAction SilentlyContinue
if ($gitFromPath) {
    $gitCmd = $gitFromPath.Source
} elseif (Test-Path 'C:\Program Files\Git\cmd\git.exe') {
    $gitCmd = 'C:\Program Files\Git\cmd\git.exe'
} else {
    Write-Output '{}'
    exit 0
}

$lockDir = Join-Path $repoRoot '.cursor\hooks'
if (-not (Test-Path $lockDir)) {
    New-Item -ItemType Directory -Path $lockDir -Force | Out-Null
}
$lockFile = Join-Path $lockDir '.auto-push.lock'
$now = Get-Date
if (Test-Path $lockFile) {
    $lockAge = $now - (Get-Item $lockFile).LastWriteTime
    if ($lockAge.TotalSeconds -lt 8) {
        Write-Output '{}'
        exit 0
    }
}
New-Item -ItemType File -Path $lockFile -Force | Out-Null

try {
    & $gitCmd add -A 2>$null
    $status = & $gitCmd status --porcelain 2>$null
    if (-not $status) {
        Write-Output '{}'
        exit 0
    }

    $stamp = Get-Date -Format 'yyyy-MM-dd HH:mm'
    $msg = "Auto sync: $stamp"
    & $gitCmd commit -m $msg 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Output '{}'
        exit 0
    }

    $env:GCM_INTERACTIVE = 'never'
    & $gitCmd -c credential.helper=manager push origin HEAD 2>$null | Out-Null
}
finally {
    Remove-Item $lockFile -Force -ErrorAction SilentlyContinue
}

Write-Output '{}'
exit 0

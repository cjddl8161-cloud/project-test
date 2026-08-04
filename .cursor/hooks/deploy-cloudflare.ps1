# Deploy static site files to Cloudflare Pages project "tutor"
$ErrorActionPreference = 'Stop'

$repoRoot = if ($PSScriptRoot) {
    (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
} else {
    (Get-Location).Path
}
Set-Location -LiteralPath $repoRoot

$projectName = 'tutor'
$distDir = Join-Path $repoRoot 'dist'

if (Test-Path $distDir) {
    Remove-Item -LiteralPath $distDir -Recurse -Force
}
New-Item -ItemType Directory -Path $distDir -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $repoRoot 'index.html') -Destination (Join-Path $distDir 'index.html') -Force

$npx = Get-Command npx -ErrorAction SilentlyContinue
if (-not $npx) {
    $env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path', 'User')
}

Write-Host "Deploying to Cloudflare Pages project: $projectName"
& npx --yes wrangler pages deploy $distDir --project-name=$projectName --commit-dirty=true
exit $LASTEXITCODE

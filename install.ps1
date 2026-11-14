param(
  [string]$InstallDir = (Join-Path $env:USERPROFILE '.yanxing\bin'),
  [switch]$Uninstall
)

$ErrorActionPreference = 'Stop'
$RepoRawBase = 'https://raw.githubusercontent.com/buer5/yanxing/main'
$DictFiles = @(
  'xiaoxue6.json', 'zhongkao.json', 'ket2021.json', 'pet2024.json',
  'gaokao3500.json', 'cet4.json', 'cet6.json', 'ielts.json',
  'nce1-sentences.json', 'nce2-sentences.json', 'nce3-sentences.json', 'nce4-sentences.json',
  'ielts-oral-900.json', 'sentences4000.json'
)

function Add-ToUserPath([string]$dir) {
  $norm = $dir.TrimEnd('\')
  $cur = [Environment]::GetEnvironmentVariable('Path', 'User')
  $parts = if ($cur) { @($cur -split ';' | Where-Object { $_.Trim() -ne '' }) } else { @() }
  $exists = $parts | Where-Object { $_.Trim().TrimEnd('\') -ieq $norm } | Select-Object -First 1
  if (-not $exists) {
    $next = (@($parts) + @($norm)) -join ';'
    [Environment]::SetEnvironmentVariable('Path', $next, 'User')
  }
  $sessParts = @($env:Path -split ';' | Where-Object { $_.Trim() -ne '' })
  if (-not ($sessParts | Where-Object { $_.Trim().TrimEnd('\') -ieq $norm } | Select-Object -First 1)) {
    $env:Path = "$norm;$env:Path"
  }
}

function Remove-FromUserPath([string]$dir) {
  $norm = $dir.TrimEnd('\')
  $cur = [Environment]::GetEnvironmentVariable('Path', 'User')
  if (-not $cur) { return }
  $parts = @($cur -split ';' | Where-Object { $_.Trim() -ne '' -and $_.Trim().TrimEnd('\') -ine $norm })
  [Environment]::SetEnvironmentVariable('Path', ($parts -join ';'), 'User')
}

if ($Uninstall) {
  Remove-FromUserPath $InstallDir
  if (Test-Path $InstallDir) { Remove-Item $InstallDir -Recurse -Force }
  Write-Host "已卸载 yanxing CLI（用户数据 ~/.yanxing/yanxing.db 已保留）。" -ForegroundColor Yellow
  return
}

$dictsDest = Join-Path $InstallDir 'dicts'
New-Item -ItemType Directory -Path $dictsDest -Force | Out-Null

$localScript = if ($PSScriptRoot) { Join-Path $PSScriptRoot 'yanxing.ps1' } else { '' }
$localDicts  = if ($PSScriptRoot) { Join-Path $PSScriptRoot 'dicts' } else { '' }

if ($localScript -and (Test-Path $localScript) -and (Test-Path $localDicts)) {
  Write-Host "正在从本地目录安装 yanxing 到 $InstallDir ..." -ForegroundColor Cyan
  Copy-Item $localScript -Destination (Join-Path $InstallDir 'yanxing.ps1') -Force
  Copy-Item (Join-Path $localDicts '*.json') -Destination $dictsDest -Force
} else {
  Write-Host "正在从 GitHub 下载 yanxing 到 $InstallDir ..." -ForegroundColor Cyan
  Invoke-WebRequest -Uri "$RepoRawBase/yanxing.ps1" -OutFile (Join-Path $InstallDir 'yanxing.ps1') -UseBasicParsing
  foreach ($df in $DictFiles) {
    Invoke-WebRequest -Uri "$RepoRawBase/dicts/$df" -OutFile (Join-Path $dictsDest $df) -UseBasicParsing
  }
}

Add-ToUserPath $InstallDir
Write-Host "`n安装完成！已自动注册用户 PATH：$InstallDir" -ForegroundColor Green
Write-Host "现在可以直接运行：yanxing" -ForegroundColor Cyan
Write-Host "查看帮助：yanxing -Help`n" -ForegroundColor DarkGray

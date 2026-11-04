# Runs the freshly built XPrismLauncher with a portable data directory.
#
#   .\scripts\toolchain\run.ps1                  # start, wait -WaitSeconds, report, keep running
#   .\scripts\toolchain\run.ps1 -KillAfter 15    # start, verify it is alive, then close it
#
# Data (instances, logs, config) goes to .tools\run-data so the build never touches the
# user's real Prism Launcher installation.

[CmdletBinding()]
param(
    [ValidateSet('Release', 'Debug', 'RelWithDebInfo')]
    [string]$Config = 'Release',
    [int]$WaitSeconds = 15,
    [switch]$KillAfter
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

. (Join-Path $PSScriptRoot 'env.ps1') | Out-Null

$exe = Join-Path $Root "install\prismlauncher.exe"
if (-not (Test-Path $exe)) {
    # Fall back to the build tree; it needs Qt's bin directory on PATH (env.ps1 provides it),
    # while the install\ copy is self-contained.
    $exe = Join-Path $Root "build\$Config\prismlauncher.exe"
}
if (-not (Test-Path $exe)) {
    throw "Executable not found - run scripts\toolchain\build.ps1 -Install first"
}

$dataDir = Join-Path $Root '.tools\run-data'
New-Item -ItemType Directory -Force -Path $dataDir | Out-Null

$proc = Start-Process -FilePath $exe -ArgumentList @('--dir', $dataDir) -PassThru
Write-Host "Started prismlauncher.exe pid=$($proc.Id), data dir: $dataDir"

Start-Sleep -Seconds $WaitSeconds
$proc.Refresh()

if ($proc.HasExited) {
    throw "Prism Launcher exited early with code $($proc.ExitCode) - check $dataDir\logs"
}

Write-Host ("Window: '{0}'" -f $proc.MainWindowTitle)
Write-Host ("Memory: {0:N0} MB, threads: {1}" -f ($proc.WorkingSet64 / 1MB), $proc.Threads.Count)

$logDir = Join-Path $dataDir 'logs'
if (Test-Path $logDir) {
    Get-ChildItem $logDir -Filter '*.log' | Sort-Object LastWriteTime -Descending | Select-Object -First 1 | ForEach-Object {
        Write-Host "Log: $($_.FullName)"
    }
}

if ($KillAfter) {
    $proc.CloseMainWindow() | Out-Null
    Start-Sleep -Seconds 5
    if (-not $proc.HasExited) { Stop-Process -Id $proc.Id -Force }
    Write-Host 'Closed.'
}

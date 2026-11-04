# Builds XPrismLauncher with the project-local toolchain.
#
#   .\scripts\toolchain\build.ps1              # configure (if needed) + build Release
#   .\scripts\toolchain\build.ps1 -Clean       # wipe build\ first, then configure + build
#   .\scripts\toolchain\build.ps1 -SkipConfigure
#
# Everything (CMake, Ninja, Qt, vcpkg caches, TEMP) lives under .tools\ - see env.ps1.

[CmdletBinding()]
param(
    [switch]$Clean,
    [switch]$SkipConfigure,
    [switch]$Install,
    [ValidateSet('Release', 'Debug', 'RelWithDebInfo')]
    [string]$Config = 'Release'
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

# PowerShell 5.1 turns *any* stderr output of a native command into a terminating error while
# $ErrorActionPreference is 'Stop' (CMake and vcpkg routinely warn on stderr), so native calls
# run with 'Continue' and their exit codes are checked explicitly.
function Invoke-NativeLogged {
    param([string]$LogPath, [scriptblock]$Command)
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & $Command *> $LogPath
        return $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previous
    }
}

. (Join-Path $PSScriptRoot 'env.ps1') | Out-Null

$BuildDir = Join-Path $Root 'build'
$LogDir = Join-Path $Root '.tools\logs'
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

if ($Clean -and (Test-Path $BuildDir)) {
    Write-Host "Removing $BuildDir"
    Remove-Item $BuildDir -Recurse -Force
}

if (-not $SkipConfigure) {
    # Java_* / CMAKE_Java_* are cleared so a changed JAVA_HOME (env.ps1 picks JDK 8-19)
    # is re-detected instead of being served from CMakeCache.txt.
    Write-Host '== configure =='
    $configureLog = Join-Path $LogDir 'cmake-configure.log'
    $exit = Invoke-NativeLogged $configureLog { cmake --preset default "-DCMAKE_BUILD_TYPE=$Config" -U 'Java_*' -U 'CMAKE_Java_*' }
    if ($exit -ne 0) {
        Get-Content $configureLog -Tail 40
        throw "CMake configure failed (exit $exit), full log: $configureLog"
    }
}

Write-Host "== build ($Config) =="
$buildLog = Join-Path $LogDir 'cmake-build.log'
$sw = [Diagnostics.Stopwatch]::StartNew()
$exit = Invoke-NativeLogged $buildLog { cmake --build --preset default --config $Config }
$sw.Stop()
if ($exit -ne 0) {
    Get-Content $buildLog -Tail 40
    throw "Build failed (exit $exit), full log: $buildLog"
}

$exe = Join-Path $BuildDir "$Config\prismlauncher.exe"
Write-Host ("Build OK in {0:N0} min -> {1}" -f $sw.Elapsed.TotalMinutes, $exe)

if ($Install) {
    # `cmake --install` runs qt_deploy_runtime_dependencies, which copies the Qt DLLs and
    # platform plugins next to the exe. Without it the build-tree binary only starts when
    # Qt's bin directory happens to be on PATH (otherwise STATUS_DLL_NOT_FOUND).
    Write-Host '== install =='
    $installLog = Join-Path $LogDir 'cmake-install.log'
    $exit = Invoke-NativeLogged $installLog { cmake --install $BuildDir --config $Config }
    if ($exit -ne 0) {
        Get-Content $installLog -Tail 40
        throw "Install failed (exit $exit), full log: $installLog"
    }
    Write-Host "Installed -> $(Join-Path $Root 'install')"

    # The install step leaves a 1-byte qt.conf (a single space), so Qt falls back to the
    # Qt prefix compiled into the binaries (.tools\Qt\...). That only works while .tools
    # exists - a real Prefix=. makes install\ relocatable.
    $qtConf = Join-Path $Root 'install\qt.conf'
    [System.IO.File]::WriteAllText($qtConf, "[Paths]`nPrefix = .`n", (New-Object System.Text.UTF8Encoding($false)))
    Write-Host "qt.conf    -> $qtConf"
}

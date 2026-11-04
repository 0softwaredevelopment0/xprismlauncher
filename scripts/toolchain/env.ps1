# Sets up the local build toolchain for XPrismLauncher (no global installs).
#
# Dot-source this file in a PowerShell session before running CMake:
#   . .\scripts\toolchain\env.ps1
#
# Provides:
#   * MSVC 2022 x64 environment (vsvars/vcvars64 imported from VS itself)
#   * CMake + Ninja from .tools\venv (PyPI wheels, project-local)
#   * Qt 6 from .tools\Qt (installed with aqtinstall, project-local)
#   * vcpkg from the cmake/vcpkg submodule (VCPKG_ROOT)
#
# Notably absent from the machine by default: CMake/Ninja in PATH and Qt 6,
# hence the project-local .tools directory. See Vault note
# Workspace/xprismlauncher/Обзор for the full story.

$Root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

$ToolsDir = Join-Path $Root '.tools'
$VenvScripts = Join-Path $ToolsDir 'venv\Scripts'
$QtVersion = '6.10.3'
$QtDir = Join-Path $ToolsDir "Qt\$QtVersion\msvc2022_64"
$VcpkgRoot = Join-Path $Root 'cmake\vcpkg'

$vcvarsCandidates = @(
    'C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat',
    'C:\Program Files\Microsoft Visual Studio\2022\Professional\VC\Auxiliary\Build\vcvars64.bat',
    'C:\Program Files\Microsoft Visual Studio\2022\Enterprise\VC\Auxiliary\Build\vcvars64.bat',
    'C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat'
)

function Import-MsvcEnvironment {
    param([Parameter(Mandatory)][string]$VcVarsPath)

    $output = cmd /c "`"$VcVarsPath`" >nul 2>&1 && set"
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to run vcvars64.bat: $VcVarsPath"
    }
    foreach ($line in $output) {
        if ($line -match '^([^=]+)=(.*)$') {
            $name = $Matches[1]
            $value = $Matches[2]
            if ($name -match '^(PATH|INCLUDE|LIB|LIBPATH)$') {
                Set-Item -Path "env:$name" -Value $value
            } elseif ($name -notmatch '^(PROMPT|PS1|VSCMD_|__VSCMD)') {
                Set-Item -Path "env:$name" -Value $value
            }
        }
    }
}

if (-not (Test-Path (Join-Path $Qtdir 'bin\qmake.exe'))) {
    throw "Qt not found at $QtDir - install it with aqtinstall (see scripts\toolchain\README.md)"
}

# Prism's Java sources (libraries/javacheck, libraries/launcher) are compiled with
# `-source 7 -target 7`. JDK 20+ dropped source/target 7 and javac fails with
#   error: Source option 7 is no longer supported. Use 8 or later.
# CI builds with JDK 17, which still accepts 7. Prefer 17, fall back to any JDK 8-19.
$JdkCandidates = @(
    'C:\Program Files\Eclipse Adoptium\jdk-17*'
    'C:\Program Files\Eclipse Adoptium\jdk-19*'
    'C:\Program Files\Eclipse Adoptium\jdk-11*'
    'C:\Program Files\Eclipse Adoptium\jdk-8*'
    'C:\Program Files\Java\jdk-17*'
    'C:\Program Files\Java\jdk-8*'
)
$JavaHome = $null
foreach ($pattern in $JdkCandidates) {
    $hit = Get-ChildItem -Path $pattern -Directory -ErrorAction SilentlyContinue |
        Where-Object { Test-Path (Join-Path $_.FullName 'bin\javac.exe') } |
        Select-Object -First 1
    if ($hit) { $JavaHome = $hit.FullName; break }
}
if (-not $JavaHome) {
    throw 'No JDK 8-19 found - Prism needs javac with support for -source 7 (JDK 20+ rejects it)'
}
$env:JAVA_HOME = $JavaHome

$VcVars = $vcvarsCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $VcVars) {
    throw 'vcvars64.bat not found - install Visual Studio 2022 with the C++ workload'
}
Import-MsvcEnvironment -VcVarsPath $VcVars

$env:PATH = @(
    $VenvScripts
    (Join-Path $QtDir 'bin')
    (Join-Path $JavaHome 'bin')
    $VcpkgRoot
    $env:PATH
) -join ';'

$env:VCPKG_ROOT = $VcpkgRoot
$env:CMAKE_PREFIX_PATH = $QtDir
$env:QT_DIR = $QtDir

# vcpkg defaults to %LOCALAPPDATA%\vcpkg for the registry + binary caches, which the
# agent sandbox forbids writing to. Keep every cache inside the project instead.
$VcpkgCache = Join-Path $ToolsDir 'vcpkg-cache'
$env:X_VCPKG_REGISTRIES_CACHE = Join-Path $VcpkgCache 'registries'
$env:VCPKG_DEFAULT_BINARY_CACHE = Join-Path $VcpkgCache 'binary'
New-Item -ItemType Directory -Force -Path $env:X_VCPKG_REGISTRIES_CACHE, $env:VCPKG_DEFAULT_BINARY_CACHE | Out-Null

# CRITICAL: keep TEMP inside the project. With %LOCALAPPDATA%\Temp (the default) the
# sandboxed agent session blocks the temp writes MSVC needs, and every compile dies with
#   cl : Command line error D8050 : cannot execute '...\c1.dll': failed to get command line into debug records
# (MSBuild additionally dies with "Access to the path '...\Temp\MSBuildTemp' is denied").
# Pointing TEMP/TMP at a workspace directory fixes both.
$TempDir = Join-Path $ToolsDir 'tmp'
New-Item -ItemType Directory -Force -Path (Join-Path $TempDir 'MSBuildTemp') | Out-Null
$env:TEMP = $TempDir
$env:TMP = $TempDir

Write-Host "MSVC      : $env:VCToolsInstallDir"
Write-Host "CMake     : $(& (Join-Path $VenvScripts 'cmake.exe') --version | Select-Object -First 1)"
Write-Host "Qt        : $QtDir"
Write-Host "vcpkg     : $VcpkgRoot"
Write-Host "vcpkg cache: $VcpkgCache"
Write-Host "TEMP      : $TempDir"
Write-Host "JAVA_HOME : $JavaHome"

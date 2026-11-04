# Local build toolchain (Windows / MSVC)

Everything needed to build XPrismLauncher lives inside the repo, under `.tools/` (git-ignored).
No global installs, no PATH changes outside the build shell.

## TL;DR

```powershell
. .\scripts\toolchain\env.ps1            # load MSVC + Qt + CMake/Ninja + vcpkg into this shell
.\scripts\toolchain\build.ps1 -Install   # configure (vcpkg deps) + build Release + install\
.\scripts\toolchain\run.ps1 -WaitSeconds 20
```

Result: `install\prismlauncher.exe` — self-contained (Qt DLLs and plugins deployed next to the exe).

## What is where

| Path | What | How it was installed |
|---|---|---|
| `.tools\venv` | CMake 3.31 + Ninja + aqtinstall (PyPI wheels) | `uv venv .tools\venv --python 3.14` then `uv pip install cmake==3.31.10 ninja aqtinstall` |
| `.tools\Qt\6.10.3\msvc2022_64` | Qt 6 (qtbase, qtsvg, qttools, qttranslations, qtnetworkauth, qtimageformats) | `aqt install-qt windows desktop 6.10.3 win64_msvc2022_64 --archives qtbase qtsvg qttools qttranslations -m qtnetworkauth qtimageformats` |
| `cmake\vcpkg` | vcpkg (submodule) | `cmake\vcpkg\bootstrap-vcpkg.bat -disableMetrics` |
| `.tools\vcpkg-cache` | vcpkg registry + binary caches | `X_VCPKG_REGISTRIES_CACHE` / `VCPKG_DEFAULT_BINARY_CACHE` |
| `.tools\tmp` | `TEMP`/`TMP` for the build | see pitfall #2 |
| `.tools\logs` | CMake/vcpkg/install logs of the last runs | — |
| `.tools\run-data` | portable Prism data dir used by `run.ps1` | — |

MSVC comes from Visual Studio 2022 Community (`vcvars64.bat` is imported by `env.ps1`); the JDK is
picked from installed JDK 8–19 (see pitfall #3).

## Pitfalls (all of them bit us on the first build)

1. **`git submodule update --init` does not work here.** MSYS `sh` cannot fork
   (`dofork: child -1 ... exit code 0xC0000142`, `fork: Resource temporarily unavailable`, exit 254).
   Clone submodules by hand and register them:
   ```powershell
   git clone https://github.com/PrismLauncher/libnbtplusplus.git libraries/libnbtplusplus
   git -C libraries/libnbtplusplus checkout 3538933614059f0f44388a2b16f3db25ce42285b
   git clone --filter=blob:none --no-checkout https://github.com/microsoft/vcpkg.git cmake/vcpkg
   git -C cmake/vcpkg checkout 908da3a305a0a8028d9602ab241b433652b3df69
   ```

2. **`TEMP` must stay inside the project.** With the default `%LOCALAPPDATA%\Temp` every MSVC compile fails with
   ```
   cl : Command line error D8050 : cannot execute '...\c1.dll': failed to get command line into debug records
   ```
   (vcpkg port builds die the same way, and MSBuild adds `Access to the path '...\Temp\MSBuildTemp' is denied`).
   `env.ps1` points `TEMP`/`TMP` at `.tools\tmp`, which fixes both. Any tool you run outside `env.ps1`
   and expect to compile code needs the same treatment.

3. **`JAVA_HOME` must be JDK 8–19.** Prism compiles `libraries/javacheck` and `libraries/launcher` with
   `-source 7 -target 7`, and JDK 20+ rejects it: `error: Source option 7 is no longer supported`.
   CI uses JDK 17. `env.ps1` prefers 17 → 19 → 11 → 8 from Eclipse Adoptium / `C:\Program Files\Java`.
   Changing the JDK requires a re-configure: `build.ps1` passes `-U Java_* -U CMAKE_Java_*` so the cached
   `javac` path is re-detected.

4. **Qt 6.11.x is not installable with aqtinstall.** The version is listed, but its repository XML is missing
   (`ERROR : Failed to locate XML data for Qt version '6.11.2'`). 6.10.3 works; the project allows ≥ 6.8.
   In Qt 6.10 `qtsvg`/`qttools`/`qttranslations` are *base archives* (`--archives`), not modules (`-m`).

5. **aqt and vcpkg want to write outside the repo** (`%APPDATA%\aqt`, `%LOCALAPPDATA%\vcpkg`). `env.ps1` redirects
   `APPDATA` for aqt runs and both vcpkg caches into `.tools\`.

6. **The build-tree exe needs Qt on `PATH`.** `cmake --install` (or `build.ps1 -Install`) deploys the Qt DLLs and
   plugins, so `install\prismlauncher.exe` starts from anywhere. Without it you get `0xC0000135` (`DLL_NOT_FOUND`)
   unless `env.ps1` was sourced first.

7. **Smart App Control** (Windows, if enabled) blocks the unsigned binaries as
   *"Application Policy blocked this file"* (`HKLM:\SYSTEM\CurrentControlSet\Control\CI\Policy` →
   `VerifiedAndReputablePolicyState = 1` means enforcement). It has to be turned off in Windows Security for
   locally built exes to run reliably.

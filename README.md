<p align="center">
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="/program_info/org.prismlauncher.PrismLauncher.logo.svg">
  <source media="(prefers-color-scheme: light)" srcset="/program_info/org.prismlauncher.PrismLauncher.logo-darkmode.svg">
  <img alt="XPrismLauncher" src="/program_info/org.prismlauncher.PrismLauncher.logo-darkmode.svg" width="40%">
</picture>
</p>

<p align="center">
  <b>XPrismLauncher</b> is a fork of Prism Launcher with its own features and a self-contained Windows build setup.<br />
  <br />It is <b>not</b> Prism Launcher and is <b>not</b> endorsed by or affiliated with the Prism Launcher project<br />
  (which in turn is a <b>fork</b> of the MultiMC Launcher, also unendorsed by it).
</p>

## This fork: XPrismLauncher

| | |
|---|---|
| Fork | [0softwaredevelopment0/xprismlauncher](https://github.com/0softwaredevelopment0/xprismlauncher) |
| Upstream | [PrismLauncher/PrismLauncher](https://github.com/PrismLauncher/PrismLauncher) |
| Working branch | `x/develop` — fork changes live here; `develop` mirrors upstream |
| Based on | Prism Launcher 12.0.0 |

No prebuilt binaries are published for this fork — build it locally with the steps below.

### What is different from upstream

- **Two account types instead of licensed accounts only**
  - **Licensed (Microsoft)** — the usual Microsoft sign-in; a Microsoft account that owns Minecraft is required.
  - **Non-licensed** — requires nothing but a nickname: no Microsoft account and no game licence. Created via
    `Accounts → Add non-licensed`, with the vanilla username rule (`3–16` characters, `A-Za-z0-9_`) or any nickname
    when *Allow invalid usernames* is ticked. Such accounts always launch in offline mode, so they can play
    singleplayer and offline-mode servers, but not online-mode ones.
  - The launcher no longer enforces licensed-only gates: an account can be added without a licensed one, the
    first-run setup wizard stops asking for a Microsoft login once any account exists, and an instance launches
    instead of falling back to demo mode. The accounts table names the two kinds `Licensed` and `Non-licensed`.
- **One-click Windows start** — `Start XPrismLauncher.cmd` runs the built launcher with a portable data directory
  (`.tools\run-data`) and a writable `TEMP`, so it also works where writes to `%TEMP%` are restricted.
- **Project-local build toolchain** — CMake, Ninja, Qt 6, vcpkg caches and temporary files all live under `.tools\`;
  nothing is installed system-wide. Scripts and pitfalls: `scripts\toolchain\README.md`.

### Building on Windows

Requirements: Visual Studio 2022 (MSVC x64), JDK 8–19 (JDK 20+ rejects the `-source 7` Java libraries), and
Python with [uv](https://docs.astral.sh/uv/). CMake, Ninja, Qt and vcpkg are provisioned into `.tools\` on first use.

```powershell
. .\scripts\toolchain\env.ps1             # MSVC + Qt + CMake/Ninja + vcpkg into the current session
.\scripts\toolchain\build.ps1 -Install   # configure + build Release + install\
.\scripts\toolchain\run.ps1              # run install\prismlauncher.exe with a portable data directory
```

`cmake --install` is part of `-Install` on purpose: it deploys the Qt DLLs and plugins next to the binary and
writes a relocatable `qt.conf`, which is what makes `install\prismlauncher.exe` self-contained. After a successful
build, double-click `Start XPrismLauncher.cmd`.

### Branches and upstream sync

- `develop` — plain mirror of `upstream/develop`, never edited.
- `x/develop` — fork changes, released from here.
- Sync: `git fetch upstream && git merge upstream/develop` (conflicts resolved in `x/develop`).

## Installation

If you are looking for Prism Launcher itself, all official downloads and instructions are on their
[website](https://prismlauncher.org/download); last upstream build status is in the
[GitHub Actions](https://github.com/PrismLauncher/PrismLauncher/actions) tab (it also includes pull request status).

<p align="center">
<a href="https://repology.org/project/prismlauncher/versions">
    <img src="https://repology.org/badge/vertical-allrepos/prismlauncher.svg?columns=3" alt="Packaging status">
</a>
</p>

### Development Builds

Please understand that these builds are not intended for most users. There may be bugs, and other instabilities. You have been warned.

There are development builds available through:

- [GitHub Actions](https://github.com/PrismLauncher/PrismLauncher/actions) (includes builds from pull requests opened by contributors)
- [nightly.link](https://prismlauncher.org/nightly) (this will always point only to the latest version of develop)

These have debug information in the binaries, so their file sizes are relatively larger.

Prebuilt Development builds are provided for **Linux**, **Windows** and **macOS**.

On Linux, we also offer our own [Flatpak nightly repository](https://github.com/PrismLauncher/flatpak). Most software centers are able to install it by opening [this link](https://flatpak.prismlauncher.org/prismlauncher-nightly.flatpakref).

## Community & Support

Feel free to create a GitHub issue if you find a bug or want to suggest a new feature. We have multiple community spaces where other community members can help you:

- **Our Discord server:** (Software Development)

[![Prism Launcher Discord server](https://discordapp.com/api/guilds/1031648380885147709/widget.png?style=banner3)](https://dsc.gg/softwaredev)

- **Our Matrix space:**

[![Prism Launcher Space](https://img.shields.io/matrix/prismlauncher:matrix.org?style=for-the-badge&label=Matrix%20Space&logo=matrix&color=purple)](https://prismlauncher.org/matrix)

- **Our Subreddit:**

[![r/PrismLauncher](https://img.shields.io/reddit/subreddit-subscribers/prismlauncher?style=for-the-badge&logo=reddit)](https://prismlauncher.org/reddit)

## Translations

The translation effort for Prism Launcher is hosted on [Weblate](https://hosted.weblate.org/projects/prismlauncher/launcher/) and information about translating Prism Launcher is available at <https://github.com/PrismLauncher/Translations>.

## Building

If you want to build Prism Launcher yourself, check the [build instructions](https://prismlauncher.org/wiki/development/build-instructions).
For this fork, the Windows build is scripted — see [Building on Windows](#building-on-windows) above.

## Sponsors & Partners

We thank all the wonderful backers over at Open Collective! Support Prism Launcher by [becoming a backer](https://opencollective.com/prismlauncher).

[![OpenCollective Backers](https://opencollective.com/prismlauncher/backers.svg?width=890&limit=1000)](https://opencollective.com/prismlauncher#backers)

Thanks to JetBrains for providing us a few licenses for all their products, as part of their [Open Source program](https://www.jetbrains.com/opensource/).

<a href="https://jb.gg/OpenSource">
<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://www.jetbrains.com/company/brand/img/logo_jb_dos_4.svg">
  <source media="(prefers-color-scheme: light)" srcset="https://resources.jetbrains.com/storage/products/company/brand/logos/jetbrains.svg">
  <img alt="JetBrains logo" src="https://resources.jetbrains.com/storage/products/company/brand/logos/jetbrains.svg" width="40%">
</picture>
</a>

Thanks to Weblate for hosting our translation efforts.

<a href="https://hosted.weblate.org/engage/prismlauncher/">
<img src="https://hosted.weblate.org/widgets/prismlauncher/-/open-graph.png" alt="Translation status" width="300" />
</a>

Thanks to Netlify for providing us their excellent web services, as part of their [Open Source program](https://www.netlify.com/open-source/).

<a href="https://www.netlify.com"> <img src="https://www.netlify.com/v3/img/components/netlify-color-accent.svg" alt="Deploys by Netlify" /> </a>

Thanks to the awesome people over at [MacStadium](https://www.macstadium.com/), for providing M1-Macs for development purposes!

<a href="https://www.macstadium.com"><img src="https://uploads-ssl.webflow.com/5ac3c046c82724970fc60918/5c019d917bba312af7553b49_MacStadium-developerlogo.png" alt="Powered by MacStadium" width="300"></a>

## Forking/Redistributing/Custom builds policy

You are free to fork, redistribute and provide custom builds as long as you follow the terms of the [license](LICENSE) (this is a legal responsibility), and if you made code changes rather than just packaging a custom build, please do the following as a basic courtesy:

- Make it clear that your fork is not Prism Launcher and is not endorsed by or affiliated with the Prism Launcher project (<https://prismlauncher.org>).
- Go through [CMakeLists.txt](CMakeLists.txt) and change Prism Launcher's API keys to your own or set them to empty strings (`""`) to disable them (this way the program will still compile but the functionality requiring those keys will be disabled).

If you have any questions or want any clarification on the above conditions please make an issue and ask us.

If you are just building Prism Launcher for your distribution, please make sure to set the `Launcher_BUILD_PLATFORM` to a slug representing your distribution. Examples are `archlinux`, `fedora` and `nixpkgs`.

Note that if you build this software without removing the provided API keys in [CMakeLists.txt](CMakeLists.txt) you are accepting the following terms and conditions:

- [Microsoft Identity Platform Terms of Use](https://docs.microsoft.com/en-us/legal/microsoft-identity-platform/terms-of-use)
- [CurseForge 3rd Party API Terms and Conditions](https://support.curseforge.com/en/support/solutions/articles/9000207405-curse-forge-3rd-party-api-terms-and-conditions)

If you do not agree with these terms and conditions, then remove the associated API keys from the [CMakeLists.txt](CMakeLists.txt) file by setting them to an empty string (`""`).

## License [![https://github.com/PrismLauncher/PrismLauncher/blob/develop/LICENSE](https://img.shields.io/github/license/PrismLauncher/PrismLauncher?label=License&logo=gnu&color=C4282D)](LICENSE)

All launcher code is available under the GPL-3.0-only license.

The logo and related assets are under the CC BY-SA 4.0 license.

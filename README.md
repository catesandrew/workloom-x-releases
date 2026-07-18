# workloom-x-releases

Public release binaries and installer for **Workloom** — the `wl` CLI.

The source code lives in the private [`catesandrew/workloom-x`](https://github.com/catesandrew/workloom-x)
repository. This repo mirrors the installer scripts and release assets so anonymous
`curl | sh` installs work without a private-repo token (a private repo's
`raw.githubusercontent.com` and `releases/download` links 404 for unauthenticated
requests). It is updated automatically by the source repo's release workflow.

![License](https://img.shields.io/github/license/catesandrew/workloom-x-releases)
![Latest Release](https://img.shields.io/github/v/release/catesandrew/workloom-x-releases)
![Downloads](https://img.shields.io/github/downloads/catesandrew/workloom-x-releases/total)

## Install

**macOS / Linux:**

```sh
curl -fsSL https://raw.githubusercontent.com/catesandrew/workloom-x-releases/main/scripts/install.sh | sh
```

**Windows (PowerShell):**

```powershell
irm https://raw.githubusercontent.com/catesandrew/workloom-x-releases/main/scripts/install.ps1 | iex
```

The installer detects your platform, downloads the matching `wl` binary from the
latest release, verifies its SHA-256 checksum against the release's `SHA256SUMS`,
and installs it.

Alternatively, with Node 20+: `npm i -g @workloom/cli`.

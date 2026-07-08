# csph — ComputeSphere CLI

Public distribution of release binaries for the **ComputeSphere CLI** (`csph`).

## Install

**Homebrew** (macOS / Linux)

```sh
brew install computesphere/cli/csph
```

**Install script** (macOS / Linux)

```sh
curl -fsSL https://install.computesphere.com | sh
```

Installs to `~/.local/bin` by default — override with `CSPH_INSTALL_DIR`, or pin
a version with `CSPH_VERSION=0.11.6`. The script verifies the release SHA-256
checksum before installing.

**Install script** (Windows, PowerShell)

```powershell
irm https://install.computesphere.com/install.ps1 | iex
```

**Direct download**

Grab the archive for your platform from the
[latest release](https://github.com/computesphere/csph/releases/latest),
extract it, and put `csph` on your `PATH`.

## Documentation

See the [ComputeSphere CLI docs](https://docs.computesphere.com/docs/cli/getting-started).

---

This repository hosts release archives and the public install scripts
([`install.sh`](install.sh), [`install.ps1`](install.ps1)) served at
[install.computesphere.com](https://install.computesphere.com). It is the
download target for the Homebrew formula, the install scripts, and direct
downloads. The scripts are kept here, in the open, so `curl … | sh` users can
audit exactly what runs. Report issues and feedback through the ComputeSphere
console and support.
<#
.SYNOPSIS
  csph installer for Windows — https://install.computesphere.com

.DESCRIPTION
  Downloads the ComputeSphere CLI (csph) release archive for your platform from
  https://github.com/computesphere/csph/releases, verifies its SHA-256 checksum,
  and installs csph.exe onto your user PATH.

      irm https://install.computesphere.com/install.ps1 | iex

  Environment overrides:
    CSPH_VERSION      Version to install (default: latest, e.g. "0.11.6")
    CSPH_INSTALL_DIR  Install directory (default: %LOCALAPPDATA%\csph\bin)
#>
$ErrorActionPreference = 'Stop'

$Repo   = 'computesphere/csph'
$Binary = 'csph.exe'

function Info($m)  { Write-Host "==> $m" -ForegroundColor Blue }
function Warn($m)  { Write-Host "warning: $m" -ForegroundColor Yellow }
function Die($m)   { Write-Host "error: $m" -ForegroundColor Red; exit 1 }

# --- detect arch -------------------------------------------------------------
switch ($env:PROCESSOR_ARCHITECTURE) {
  'AMD64' { $Arch = 'amd64' }
  'ARM64' { $Arch = 'arm64' }
  'x86'   { $Arch = '386' }
  default { Die "unsupported architecture: $($env:PROCESSOR_ARCHITECTURE)" }
}

$Asset     = "windows_$Arch.zip"
$Checksums = 'windows_sha256_checksums.txt'

# --- resolve version ---------------------------------------------------------
$Version = $env:CSPH_VERSION
if (-not $Version) {
  Info 'Resolving latest release...'
  $resp = Invoke-WebRequest -Uri "https://github.com/$Repo/releases/latest" -MaximumRedirection 0 -ErrorAction SilentlyContinue
  $loc  = $resp.Headers.Location
  if (-not $loc) { $loc = $resp.Headers['Location'] }
  $Version = ($loc -split '/tag/')[-1]
  if (-not $Version) { Die 'could not resolve the latest version — set CSPH_VERSION explicitly' }
}

$Base = "https://github.com/$Repo/releases/download/$Version"
Info "Installing csph $Version (windows/$Arch)"

$Tmp = Join-Path $env:TEMP ("csph-" + [System.Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $Tmp -Force | Out-Null
try {
  # --- download --------------------------------------------------------------
  Info "Downloading $Asset..."
  try { Invoke-WebRequest -Uri "$Base/$Asset" -OutFile (Join-Path $Tmp $Asset) }
  catch { Die "download failed: $Base/$Asset (does version $Version ship windows/$Arch?)" }

  # --- verify checksum -------------------------------------------------------
  try {
    Invoke-WebRequest -Uri "$Base/$Checksums" -OutFile (Join-Path $Tmp $Checksums)
    $line = Select-String -Path (Join-Path $Tmp $Checksums) -Pattern ([regex]::Escape($Asset)) | Select-Object -First 1
    if ($line) {
      $expected = ($line.Line -split '\s+')[0]
      $actual   = (Get-FileHash -Path (Join-Path $Tmp $Asset) -Algorithm SHA256).Hash.ToLower()
      if ($actual -ne $expected.ToLower()) { Die "checksum mismatch for $Asset (expected $expected, got $actual)" }
      Info 'Checksum verified.'
    } else {
      Warn "no checksum listed for $Asset — skipping verification"
    }
  } catch {
    Warn "could not fetch $Checksums — skipping checksum verification"
  }

  # --- extract ---------------------------------------------------------------
  Expand-Archive -Path (Join-Path $Tmp $Asset) -DestinationPath $Tmp -Force
  # The archive ships the binary as computesphere.exe (GoReleaser's default name)
  # rather than csph.exe, so accept either and install it as csph.exe.
  $bin = Get-ChildItem -Path $Tmp -Recurse -File |
    Where-Object { $_.Name -in @('csph.exe', 'computesphere.exe') } |
    Select-Object -First 1
  if (-not $bin) { Die "could not find the csph binary inside $Asset" }

  # --- install ---------------------------------------------------------------
  $InstallDir = $env:CSPH_INSTALL_DIR
  if (-not $InstallDir) { $InstallDir = Join-Path $env:LOCALAPPDATA 'csph\bin' }
  New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
  Copy-Item -Path $bin.FullName -Destination (Join-Path $InstallDir $Binary) -Force
  Info "Installed csph to $InstallDir\$Binary"

  # --- PATH (user scope) -----------------------------------------------------
  $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
  if (($userPath -split ';') -notcontains $InstallDir) {
    [Environment]::SetEnvironmentVariable('Path', "$userPath;$InstallDir", 'User')
    Warn "Added $InstallDir to your user PATH — restart your terminal to pick it up."
  }
  Info "Done. Run 'csph auth login' to get started."
}
finally {
  Remove-Item -Path $Tmp -Recurse -Force -ErrorAction SilentlyContinue
}

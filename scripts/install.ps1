# Workloom CLI installer (Windows).
#
#   irm https://raw.githubusercontent.com/catesandrew/workloom-x-releases/main/scripts/install.ps1 | iex
#
# Downloads the win32-x64 `wl.exe` from the latest GitHub Release, verifies its
# SHA-256 against the release's SHA256SUMS asset, and installs it. Override with:
#   $env:WL_VERSION      release tag (default: latest, e.g. cli-v0.2.0)
#   $env:WL_INSTALL_DIR  install dir (default: $env:LOCALAPPDATA\Workloom\bin)
$ErrorActionPreference = 'Stop'

# The public mirror repo (source lives in the private catesandrew/workloom-x
# repo; release assets + this script are mirrored here so anonymous installs
# work without a private-repo token).
$Repo = 'catesandrew/workloom-x-releases'
$InstallDir = if ($env:WL_INSTALL_DIR) { $env:WL_INSTALL_DIR } else { Join-Path $env:LOCALAPPDATA 'Workloom\bin' }
$Target = 'win32-x64'
$Asset = "wl-$Target.zip"

# Resolve version tag.
if ($env:WL_VERSION) {
  $Tag = $env:WL_VERSION
} else {
  $resp = Invoke-WebRequest -UseBasicParsing -Uri "https://github.com/$Repo/releases/latest" -MaximumRedirection 0 -ErrorAction SilentlyContinue
  $loc = $resp.Headers.Location
  if (-not $loc) { $loc = (Invoke-WebRequest -UseBasicParsing -Uri "https://github.com/$Repo/releases/latest").BaseResponse.ResponseUri.AbsoluteUri }
  $Tag = ($loc -split '/tag/')[-1]
  if (-not $Tag) { throw "Could not resolve the latest release tag; set `$env:WL_VERSION explicitly." }
}

$Base = "https://github.com/$Repo/releases/download/$Tag"
Write-Host "Installing wl ($Target) from $Tag"

$Tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("wl-" + [System.Guid]::NewGuid())
New-Item -ItemType Directory -Force -Path $Tmp | Out-Null
try {
  $zip = Join-Path $Tmp $Asset
  Invoke-WebRequest -UseBasicParsing -Uri "$Base/$Asset" -OutFile $zip

  # Verify checksum against SHA256SUMS (required).
  $sums = Join-Path $Tmp 'SHA256SUMS'
  try { Invoke-WebRequest -UseBasicParsing -Uri "$Base/SHA256SUMS" -OutFile $sums }
  catch { throw "SHA256SUMS not found for $Tag - refusing to install an unverified binary." }
  $expected = (Select-String -Path $sums -Pattern " $([regex]::Escape($Asset))$" | Select-Object -First 1).Line -split '\s+' | Select-Object -First 1
  if (-not $expected) { throw "SHA256SUMS has no entry for $Asset." }
  $actual = (Get-FileHash -Algorithm SHA256 -Path $zip).Hash.ToLower()
  if ($expected.ToLower() -ne $actual) { throw "Checksum mismatch for $Asset (expected $expected, got $actual)." }
  Write-Host 'Checksum verified.'

  Expand-Archive -Path $zip -DestinationPath $Tmp -Force
  New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
  Move-Item -Force -Path (Join-Path $Tmp 'wl.exe') -Destination (Join-Path $InstallDir 'wl.exe')
  Write-Host "Installed to $InstallDir\wl.exe"

  # PATH hint (persist to the user PATH if missing).
  $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
  if ($userPath -notlike "*$InstallDir*") {
    [Environment]::SetEnvironmentVariable('Path', "$userPath;$InstallDir", 'User')
    Write-Host "Added $InstallDir to your user PATH. Restart your shell, then: wl --version"
  } else {
    Write-Host 'Run: wl --version'
  }
}
finally {
  Remove-Item -Recurse -Force $Tmp -ErrorAction SilentlyContinue
}

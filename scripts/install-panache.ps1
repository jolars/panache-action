Param()

$ErrorActionPreference = 'Stop'

$repo = if ($env:PANACHE_REPO) { $env:PANACHE_REPO } else { 'jolars/panache' }
$version = if ($env:PANACHE_VERSION) { $env:PANACHE_VERSION } else { 'latest' }
$installDir = if ($env:PANACHE_INSTALL_DIR) { $env:PANACHE_INSTALL_DIR } else { Join-Path $env:LOCALAPPDATA 'Programs\panache\bin' }

$arch = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()
switch ($arch) {
    'X64' { $target = 'x86_64-pc-windows-msvc' }
    'Arm64' { $target = 'aarch64-pc-windows-msvc' }
    default { throw "Unsupported Windows architecture: $arch" }
}

$asset = "panache-$target.zip"

if ($version -eq 'latest') {
    $url = "https://github.com/$repo/releases/latest/download/$asset"
} else {
    $tag = if ($version.StartsWith('v')) { $version } else { "v$version" }
    $url = "https://github.com/$repo/releases/download/$tag/$asset"
}

$tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ("panache-install-" + [System.Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmpDir | Out-Null

try {
    $zipPath = Join-Path $tmpDir $asset
    Write-Host "Downloading $asset ($version)..."
    Invoke-WebRequest -Uri $url -OutFile $zipPath

    Expand-Archive -Path $zipPath -DestinationPath $tmpDir -Force
    New-Item -ItemType Directory -Path $installDir -Force | Out-Null
    Copy-Item -Path (Join-Path $tmpDir 'panache.exe') -Destination (Join-Path $installDir 'panache.exe') -Force

    Write-Host "Installed panache to $(Join-Path $installDir 'panache.exe')"
}
finally {
    Remove-Item -Recurse -Force $tmpDir -ErrorAction SilentlyContinue
}

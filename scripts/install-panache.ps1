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
$apiUrl = "https://api.github.com/repos/$repo/releases?per_page=100"

function Resolve-LatestTagWithAsset {
    param(
        [Parameter(Mandatory = $true)]
        [string]$AssetName
    )

    $headers = @{
        Accept = 'application/vnd.github+json'
        'X-GitHub-Api-Version' = '2022-11-28'
    }

    if ($env:GITHUB_TOKEN) {
        $headers['Authorization'] = "Bearer $($env:GITHUB_TOKEN)"
    }

    $releases = Invoke-RestMethod -Uri $apiUrl -Headers $headers
    foreach ($release in $releases) {
        if ($release.draft -or $release.prerelease) {
            continue
        }

        foreach ($releaseAsset in $release.assets) {
            if ($releaseAsset.name -eq $AssetName) {
                return $release.tag_name
            }
        }
    }

    throw "Could not find a non-draft release in $repo containing asset $AssetName"
}

if ($version -eq 'latest') {
    $tag = Resolve-LatestTagWithAsset -AssetName $asset
    $base = "https://github.com/$repo/releases/download/$tag"
} else {
    $tag = if ($version.StartsWith('v')) { $version } else { "v$version" }
    $base = "https://github.com/$repo/releases/download/$tag"
}
$url = "$base/$asset"
$sumsUrl = "$base/SHA256SUMS"

$tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ("panache-install-" + [System.Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmpDir | Out-Null

try {
    $zipPath = Join-Path $tmpDir $asset
    Write-Host "Downloading $asset ($version)..."
    Invoke-WebRequest -Uri $url -OutFile $zipPath

    # Verify against the release's SHA256SUMS manifest. Releases that predate
    # the manifest 404 here, in which case we warn and continue.
    $expected = $null
    $sumsPath = Join-Path $tmpDir 'SHA256SUMS'
    try {
        Invoke-WebRequest -Uri $sumsUrl -OutFile $sumsPath -ErrorAction Stop
    } catch {
        Write-Warning "No SHA256SUMS published for this release; skipping checksum verification"
    }
    if (Test-Path $sumsPath) {
        foreach ($line in Get-Content $sumsPath) {
            $parts = $line -split '\s+', 2
            if ($parts.Count -eq 2) {
                $name = $parts[1].TrimStart('*').Trim()
                if ($name -eq $asset) { $expected = $parts[0].Trim(); break }
            }
        }
        if ($expected) {
            $actual = (Get-FileHash -Path $zipPath -Algorithm SHA256).Hash.ToLower()
            if ($actual -ne $expected.ToLower()) {
                throw "Checksum verification failed for $asset (expected $expected, got $actual)"
            }
            Write-Host "Verified $asset (sha256)"
        } else {
            Write-Warning "$asset not listed in SHA256SUMS; skipping checksum verification"
        }
    }

    # Verify build provenance when the gh CLI is available. Stronger than the
    # checksum: it ties the archive to the workflow that built it. A present-
    # but-failing attestation aborts; a missing attestation (older releases) or
    # missing gh warns and continues. When no attestation exists, gh reports it
    # either as "no attestations found" or as an HTTP 404 on the attestations
    # API endpoint, so tolerate both.
    if (Get-Command gh -ErrorAction SilentlyContinue) {
        $attestOut = & gh attestation verify $zipPath --repo $repo 2>&1 | Out-String
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Verified $asset provenance (attestation)"
        } elseif ($attestOut -match '(?i)no attestation|http 404') {
            Write-Warning "No provenance attestation for this release; skipping"
        } else {
            Write-Host $attestOut
            throw "Provenance verification failed for $asset"
        }
    } else {
        Write-Warning "gh CLI not found; skipping provenance verification"
    }

    Expand-Archive -Path $zipPath -DestinationPath $tmpDir -Force
    New-Item -ItemType Directory -Path $installDir -Force | Out-Null
    Copy-Item -Path (Join-Path $tmpDir 'panache.exe') -Destination (Join-Path $installDir 'panache.exe') -Force

    Write-Host "Installed panache to $(Join-Path $installDir 'panache.exe')"
}
finally {
    Remove-Item -Recurse -Force $tmpDir -ErrorAction SilentlyContinue
}

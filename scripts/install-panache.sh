#!/usr/bin/env sh
set -eu

REPO="${PANACHE_REPO:-jolars/panache}"
INSTALL_DIR="${PANACHE_INSTALL_DIR:-$HOME/.local/bin}"
VERSION="${PANACHE_VERSION:-latest}"
VERIFY="${PANACHE_VERIFY_CHECKSUM:-true}"

os="$(uname -s)"
arch="$(uname -m)"

case "$os" in
Linux)
	case "$arch" in
	x86_64 | amd64) target="x86_64-unknown-linux-gnu" ;;
	aarch64 | arm64) target="aarch64-unknown-linux-gnu" ;;
	*)
		echo "Unsupported Linux architecture: $arch" >&2
		exit 1
		;;
	esac
	;;
Darwin)
	case "$arch" in
	x86_64 | amd64) target="x86_64-apple-darwin" ;;
	arm64 | aarch64) target="aarch64-apple-darwin" ;;
	*)
		echo "Unsupported macOS architecture: $arch" >&2
		exit 1
		;;
	esac
	;;
*)
	echo "Unsupported operating system: $os" >&2
	exit 1
	;;
esac

asset="panache-${target}.tar.gz"

if [ "$VERSION" = "latest" ]; then
	base="https://github.com/${REPO}/releases/latest/download"
else
	case "$VERSION" in
	v*) tag="$VERSION" ;;
	*) tag="v${VERSION}" ;;
	esac
	base="https://github.com/${REPO}/releases/download/${tag}"
fi
url="${base}/${asset}"
sums_url="${base}/SHA256SUMS"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT INT TERM

echo "Downloading ${asset} (${VERSION})..."
curl --proto '=https' --tlsv1.2 -fLsS "$url" -o "$tmpdir/$asset"

if [ "$VERIFY" = "true" ]; then
	# Verify the archive against the release's SHA256SUMS manifest. Releases
	# that predate the manifest return 404, in which case we warn and continue.
	if curl --proto '=https' --tlsv1.2 -fLsS "$sums_url" -o "$tmpdir/SHA256SUMS" 2>/dev/null; then
		expected="$(awk -v a="$asset" '{n=$2; sub(/^\*/, "", n); if (n == a) print $1}' "$tmpdir/SHA256SUMS")"
		if [ -z "$expected" ]; then
			echo "Warning: $asset not listed in SHA256SUMS; skipping checksum verification" >&2
		else
			if command -v sha256sum >/dev/null 2>&1; then
				actual="$(sha256sum "$tmpdir/$asset" | awk '{print $1}')"
			else
				actual="$(shasum -a 256 "$tmpdir/$asset" | awk '{print $1}')"
			fi
			if [ "$actual" != "$expected" ]; then
				echo "Checksum verification failed for $asset" >&2
				echo "  expected: $expected" >&2
				echo "  actual:   $actual" >&2
				exit 1
			fi
			echo "Verified $asset (sha256)"
		fi
	else
		echo "Warning: no SHA256SUMS published for this release; skipping checksum verification" >&2
	fi
fi

# Verify build provenance when the gh CLI is available. This is stronger than
# the checksum: it ties the archive to the workflow that built it, via a
# Sigstore signature. A present-but-failing attestation aborts; a missing
# attestation (older releases) or missing gh warns and continues. When no
# attestation exists, gh reports it either as "no attestations found" or as an
# HTTP 404 on the attestations API endpoint, so tolerate both.
if command -v gh >/dev/null 2>&1; then
	if attest_out="$(gh attestation verify "$tmpdir/$asset" --repo "$REPO" 2>&1)"; then
		echo "Verified $asset provenance (attestation)"
	elif printf '%s' "$attest_out" | grep -qiE 'no attestation|http 404'; then
		echo "Warning: no provenance attestation for this release; skipping" >&2
	else
		echo "Provenance verification failed for $asset" >&2
		echo "$attest_out" >&2
		exit 1
	fi
else
	echo "Warning: gh CLI not found; skipping provenance verification" >&2
fi

tar -xzf "$tmpdir/$asset" -C "$tmpdir"
mkdir -p "$INSTALL_DIR"
install -m 755 "$tmpdir/panache" "$INSTALL_DIR/panache"

echo "Installed panache to $INSTALL_DIR/panache"

#!/usr/bin/env sh
set -eu

REPO="${PANACHE_REPO:-jolars/panache}"
INSTALL_DIR="${PANACHE_INSTALL_DIR:-$HOME/.local/bin}"
VERSION="${PANACHE_VERSION:-latest}"
API_URL="https://api.github.com/repos/${REPO}/releases?per_page=100"

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

resolve_latest_tag_with_asset() {
	api_response="$(mktemp)"

	cleanup_api_response() {
		rm -f "$api_response"
	}

	if ! command -v python3 >/dev/null 2>&1; then
		echo "python3 is required to resolve the latest Panache release tag" >&2
		cleanup_api_response
		exit 1
	fi

	if [ -n "${GITHUB_TOKEN:-}" ]; then
		curl --proto '=https' --tlsv1.2 -fLsS \
			-H "Accept: application/vnd.github+json" \
			-H "X-GitHub-Api-Version: 2022-11-28" \
			-H "Authorization: Bearer ${GITHUB_TOKEN}" \
			"$API_URL" \
			-o "$api_response"
	else
		curl --proto '=https' --tlsv1.2 -fLsS \
			-H "Accept: application/vnd.github+json" \
			-H "X-GitHub-Api-Version: 2022-11-28" \
			"$API_URL" \
			-o "$api_response"
	fi

	if [ ! -s "$api_response" ]; then
		echo "Failed to query GitHub Releases API for ${REPO}. If rate-limited, provide GITHUB_TOKEN." >&2
		cleanup_api_response
		return 1
	fi

	tag="$(
		python3 -c '
import json
import sys

asset = sys.argv[1]
releases = json.load(sys.stdin)

for release in releases:
    if release.get("draft") or release.get("prerelease"):
        continue
    for release_asset in release.get("assets", []):
        if release_asset.get("name") == asset:
            print(release.get("tag_name", ""))
            raise SystemExit(0)

raise SystemExit(1)
' "$asset" <"$api_response"
	)" || {
		cleanup_api_response
		return 1
	}

	cleanup_api_response
	printf '%s\n' "$tag"
}

if [ "$VERSION" = "latest" ]; then
	tag="$(resolve_latest_tag_with_asset)" || {
		echo "Could not find a non-draft release in ${REPO} containing asset ${asset}" >&2
		exit 1
	}
	url="https://github.com/${REPO}/releases/download/${tag}/${asset}"
else
	case "$VERSION" in
	v*) tag="$VERSION" ;;
	*) tag="v${VERSION}" ;;
	esac
	url="https://github.com/${REPO}/releases/download/${tag}/${asset}"
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT INT TERM

echo "Downloading ${asset} (${VERSION})..."
curl --proto '=https' --tlsv1.2 -fLsS "$url" -o "$tmpdir/$asset"

tar -xzf "$tmpdir/$asset" -C "$tmpdir"
mkdir -p "$INSTALL_DIR"
install -m 755 "$tmpdir/panache" "$INSTALL_DIR/panache"

echo "Installed panache to $INSTALL_DIR/panache"

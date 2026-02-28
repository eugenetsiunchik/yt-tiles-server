#!/usr/bin/env bash
set -euo pipefail

# Fetch ONLY one dataset MBTiles by URL and install it atomically.
#
# Usage:
#   ./scripts/fetch-mbtiles.sh grodno  https://example.com/grodno.mbtiles
#   ./scripts/fetch-mbtiles.sh minsk   https://example.com/minsk.mbtiles
#
# Notes:
# - Supports http(s) URLs.
# - Downloads to a temp file, then uses update-mbtiles.sh for the atomic swap + SIGHUP reload.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

DATASET="${1:-}"
URL="${2:-}"

if [[ -z "${DATASET}" || -z "${URL}" ]]; then
  echo "Usage: $0 <dataset> <http(s)://url/to/file.mbtiles>"
  exit 2
fi

tmp="$(mktemp -t "${DATASET}.mbtiles.XXXXXX")"
trap 'rm -f "${tmp}"' EXIT

echo "==> Downloading ${URL}"
curl -fL --retry 3 --retry-delay 2 -o "${tmp}" "${URL}"

echo "==> Installing ${DATASET}.mbtiles"
"${ROOT_DIR}/scripts/update-mbtiles.sh" "${DATASET}" "${tmp}"


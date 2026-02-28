#!/usr/bin/env bash
set -euo pipefail

# Generic MBTiles updater for multiple datasets (country + city squares).
#
# Usage:
#   ./scripts/update-mbtiles.sh belarus /path/to/belarus.mbtiles
#   ./scripts/update-mbtiles.sh grodno  /path/to/grodno.mbtiles
#
# Writes into ./data/mbtiles/<dataset>.mbtiles with atomic rotation:
#   <dataset>.mbtiles      (current)
#   <dataset>.mbtiles.bak  (previous)

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST_DIR="${ROOT_DIR}/data/mbtiles"

DATASET="${1:-}"
NEW_FILE="${2:-}"

if [[ -z "${DATASET}" || -z "${NEW_FILE}" ]]; then
  echo "Usage: $0 <dataset> </path/to/file.mbtiles>"
  exit 2
fi
if [[ ! "${DATASET}" =~ ^[a-z0-9][a-z0-9_-]*$ ]]; then
  echo "ERROR: dataset must match ^[a-z0-9][a-z0-9_-]*$"
  exit 2
fi
if [[ ! -f "${NEW_FILE}" ]]; then
  echo "ERROR: file not found: ${NEW_FILE}"
  exit 2
fi

mkdir -p "${DEST_DIR}"

tmp="${DEST_DIR}/${DATASET}.mbtiles.new"
dest="${DEST_DIR}/${DATASET}.mbtiles"
bak="${DEST_DIR}/${DATASET}.mbtiles.bak"

echo "==> Copying to ${tmp}"
cp -f "${NEW_FILE}" "${tmp}"
sync

echo "==> Rotating files"
if [[ -f "${dest}" ]]; then
  mv -f "${dest}" "${bak}"
fi
mv -f "${tmp}" "${dest}"
sync

echo "==> Reloading tileserver (SIGHUP)"
docker compose kill -s HUP tileserver >/dev/null 2>&1 || true

echo "==> Purging nginx tile cache (best-effort)"
# Nginx cache keys are long-lived (we set immutable caching). Purging ensures updates take effect immediately.
docker compose exec -T nginx sh -lc 'rm -rf /tmp/nginx-cache/*' >/dev/null 2>&1 || true

echo "==> Done."
echo "Current: ${dest}"
echo "Backup:  ${bak} (delete when happy)"


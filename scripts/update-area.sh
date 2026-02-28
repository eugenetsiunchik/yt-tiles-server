#!/usr/bin/env bash
set -euo pipefail

# City-area MBTiles updater (for frequently updated squares).
#
# Usage:
#   ./scripts/update-area.sh grodno /path/to/grodno.mbtiles

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

AREA="${1:-}"
NEW_FILE="${2:-}"

"${ROOT_DIR}/scripts/update-mbtiles.sh" "${AREA}" "${NEW_FILE}"


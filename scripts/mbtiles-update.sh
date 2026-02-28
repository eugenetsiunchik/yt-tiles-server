#!/usr/bin/env bash
set -euo pipefail

# Backward-compatible wrapper (country-level update).
# Usage:
#   ./scripts/mbtiles-update.sh /path/to/new/belarus.mbtiles

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NEW_FILE="${1:-}"

"${ROOT_DIR}/scripts/update-mbtiles.sh" belarus "${NEW_FILE}"

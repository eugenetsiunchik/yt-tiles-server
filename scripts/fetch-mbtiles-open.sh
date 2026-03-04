#!/usr/bin/env bash
set -euo pipefail

# Build (download + generate) an OpenMapTiles-compatible MBTiles from open data (OSM),
# using the Planetiler OpenMapTiles Docker image.
#
# Usage:
#   ./scripts/fetch-mbtiles-open.sh belarus belarus
#
# Env:
#   MAXZOOM=14
#   PLANETILER_IMAGE=openmaptiles/planetiler-openmaptiles:latest

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST_DIR="${ROOT_DIR}/data/mbtiles"

DATASET="${1:-}"
AREA="${2:-}"

if [[ -z "${DATASET}" || -z "${AREA}" ]]; then
  echo "Usage: $0 <dataset> <area>"
  echo "Example: $0 belarus belarus"
  exit 2
fi
if [[ ! "${DATASET}" =~ ^[a-z0-9][a-z0-9_-]*$ ]]; then
  echo "ERROR: dataset must match ^[a-z0-9][a-z0-9_-]*$"
  exit 2
fi

MAXZOOM="${MAXZOOM:-14}"
PLANETILER_IMAGE="${PLANETILER_IMAGE:-openmaptiles/planetiler-openmaptiles:latest}"

mkdir -p "${DEST_DIR}"

OUT_HOST="${DEST_DIR}/${DATASET}.mbtiles.new"
OUT_IN_CONTAINER="/data/data/mbtiles/${DATASET}.mbtiles.new"

echo "==> Building MBTiles (area='${AREA}', maxzoom='${MAXZOOM}')"
echo "==> Output: ${OUT_HOST}"
DOCKER_RUN_ARGS=(--rm)
if [[ -t 0 && -t 1 ]]; then
  DOCKER_RUN_ARGS+=(-it)
fi

docker run "${DOCKER_RUN_ARGS[@]}" \
  -v "${ROOT_DIR}:/data" \
  "${PLANETILER_IMAGE}" \
  --force \
  --download \
  --area="${AREA}" \
  --maxzoom="${MAXZOOM}" \
  --output="${OUT_IN_CONTAINER}"

echo "==> Installing ${DATASET}.mbtiles"
"${ROOT_DIR}/scripts/update-mbtiles.sh" "${DATASET}" "${OUT_HOST}"


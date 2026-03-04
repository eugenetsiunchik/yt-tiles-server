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
#   JAVA_XMX=8g                          (optional, sets heap via JAVA_TOOL_OPTIONS)
#   JAVA_TOOL_OPTIONS="-Xmx8g ..."       (optional, passed through to container)
#   STORAGE=mmap                         (default: mmap; use ram if you have lots of memory)
#   NODEMAP_TYPE=array                   (default: array)
#   PLANETILER_EXTRA_ARGS="--help ..."   (optional)

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
STORAGE="${STORAGE:-mmap}"
NODEMAP_TYPE="${NODEMAP_TYPE:-array}"
PLANETILER_EXTRA_ARGS="${PLANETILER_EXTRA_ARGS:-}"

if [[ -n "${JAVA_XMX:-}" && -z "${JAVA_TOOL_OPTIONS:-}" ]]; then
  JAVA_TOOL_OPTIONS="-Xmx${JAVA_XMX}"
fi

mkdir -p "${DEST_DIR}"

BUILD_HOST="${DEST_DIR}/${DATASET}.build.mbtiles"
BUILD_IN_CONTAINER="/data/data/mbtiles/${DATASET}.build.mbtiles"
OUT_HOST="${DEST_DIR}/${DATASET}.mbtiles.new"

echo "==> Building MBTiles (area='${AREA}', maxzoom='${MAXZOOM}')"
echo "==> Output: ${BUILD_HOST}"
DOCKER_RUN_ARGS=(--rm)
if [[ -t 0 && -t 1 ]]; then
  DOCKER_RUN_ARGS+=(-it)
fi

DOCKER_ENV_ARGS=()
if [[ -n "${JAVA_TOOL_OPTIONS:-}" ]]; then
  echo "==> JAVA_TOOL_OPTIONS=${JAVA_TOOL_OPTIONS}"
  DOCKER_ENV_ARGS+=(-e "JAVA_TOOL_OPTIONS=${JAVA_TOOL_OPTIONS}")
fi

docker run "${DOCKER_RUN_ARGS[@]}" \
  "${DOCKER_ENV_ARGS[@]}" \
  -v "${ROOT_DIR}:/data" \
  "${PLANETILER_IMAGE}" \
  --force \
  --download \
  --area="${AREA}" \
  --maxzoom="${MAXZOOM}" \
  --storage="${STORAGE}" \
  --nodemap-type="${NODEMAP_TYPE}" \
  --output="${BUILD_IN_CONTAINER}" \
  ${PLANETILER_EXTRA_ARGS}

echo "==> Staging ${OUT_HOST}"
mv -f "${BUILD_HOST}" "${OUT_HOST}"

echo "==> Installing ${DATASET}.mbtiles"
"${ROOT_DIR}/scripts/update-mbtiles.sh" "${DATASET}" "${OUT_HOST}"


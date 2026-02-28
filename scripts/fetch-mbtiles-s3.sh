#!/usr/bin/env bash
set -euo pipefail

# Fetch ONLY one dataset MBTiles from S3 and install it atomically.
#
# Usage (direct S3 URI):
#   ./scripts/fetch-mbtiles-s3.sh grodno "s3://my-bucket/tilesets/grodno/2026-02-28/grodno.mbtiles"
#
# Usage (manifest JSON on S3; value must be a full s3://... URI):
#   ./scripts/fetch-mbtiles-s3.sh grodno --manifest "s3://my-bucket/manifests/latest.json"
#
# Requirements (VPS): awscli, jq

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

DATASET="${1:-}"
MODE_OR_URI="${2:-}"
ARG3="${3:-}"

if [[ -z "${DATASET}" || -z "${MODE_OR_URI}" ]]; then
  echo "Usage: $0 <dataset> <s3://bucket/key.mbtiles>"
  echo "   or: $0 <dataset> --manifest <s3://bucket/latest.json>"
  exit 2
fi

if [[ "${MODE_OR_URI}" == "--manifest" ]]; then
  if [[ -z "${ARG3}" ]]; then
    echo "ERROR: missing manifest S3 URI"
    exit 2
  fi
  MANIFEST_URI="${ARG3}"
  echo "==> Reading manifest ${MANIFEST_URI}"
  SRC_URI="$(aws s3 cp "${MANIFEST_URI}" - | jq -r ".${DATASET}")"
  if [[ -z "${SRC_URI}" || "${SRC_URI}" == "null" ]]; then
    echo "ERROR: dataset '${DATASET}' not found in manifest"
    exit 2
  fi
else
  SRC_URI="${MODE_OR_URI}"
fi

tmp="$(mktemp -t "${DATASET}.mbtiles.XXXXXX")"
trap 'rm -f "${tmp}"' EXIT

echo "==> Downloading ${SRC_URI}"
aws s3 cp "${SRC_URI}" "${tmp}"

echo "==> Installing ${DATASET}.mbtiles"
"${ROOT_DIR}/scripts/update-mbtiles.sh" "${DATASET}" "${tmp}"


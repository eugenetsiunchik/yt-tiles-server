#!/usr/bin/env bash
set -euo pipefail

# Fetch public, redistributable glyphs + sprites.
# This keeps the repo small and lets you update assets without rebuilding images.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ASSETS_DIR="${ROOT_DIR}/assets"

mkdir -p "${ASSETS_DIR}/fonts"
mkdir -p "${ASSETS_DIR}/sprites"

echo "==> Downloading OpenMapTiles fonts (glyph PBFs)"
tmp_fonts="$(mktemp -d)"
# Pre-generated glyph PBFs live on gh-pages.
curl -fsSL -o "${tmp_fonts}/fonts.zip" "https://github.com/openmaptiles/fonts/archive/refs/heads/gh-pages.zip"
unzip -q "${tmp_fonts}/fonts.zip" -d "${tmp_fonts}"
rm -f "${tmp_fonts}/fonts.zip"

# TileServer-GL expects:
#   assets/fonts/<Font Name>/<range>.pbf
# The extracted path is fonts-gh-pages/<Font Name>/<range>.pbf
rsync -a --delete "${tmp_fonts}/fonts-gh-pages/" "${ASSETS_DIR}/fonts/"
rm -rf "${tmp_fonts}"

echo "==> Downloading a minimal sprite set (osm-bright style sprites)"
tmp_sprites="$(mktemp -d)"
# The default branch no longer ships compiled sprite artifacts; they live on gh-pages.
curl -fsSL -o "${tmp_sprites}/sprites.zip" "https://github.com/openmaptiles/osm-bright-gl-style/archive/refs/heads/gh-pages.zip"
unzip -q "${tmp_sprites}/sprites.zip" -d "${tmp_sprites}"
rm -f "${tmp_sprites}/sprites.zip"

# Place sprite files under assets/sprites/belarus/ so style.json can reference:
#   /sprites/belarus/sprite(.json|.png|@2x...)
mkdir -p "${ASSETS_DIR}/sprites/belarus"
cp -f "${tmp_sprites}/osm-bright-gl-style-gh-pages/sprite."* "${ASSETS_DIR}/sprites/belarus/"
cp -f "${tmp_sprites}/osm-bright-gl-style-gh-pages/sprite@2x."* "${ASSETS_DIR}/sprites/belarus/"

rm -rf "${tmp_sprites}"

echo "==> Done."
echo "Fonts in:   ${ASSETS_DIR}/fonts/"
echo "Sprites in: ${ASSETS_DIR}/sprites/belarus/"

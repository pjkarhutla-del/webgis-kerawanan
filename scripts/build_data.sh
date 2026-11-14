#!/usr/bin/env bash
# Mengubah data kerawanan di folder raw/ menjadi vector tiles ringan (PMTiles).
#   raw/*kerawanan*.(shp|geojson|gpkg|zip)  ->  data/kerawanan.pmtiles
# Batas kawasan TIDAK diproses: cukup taruh langsung data/kawasan.geojson.
#
# Opsi (environment variable, semuanya opsional):
#   SRC_EPSG=32750          paksa CRS sumber bila .prj tidak ada
#   SHAPE_ENCODING=UTF-8    paksa encoding atribut (.dbf)
#   KEEP_FIELDS=kwn_karhut  hanya simpan kolom ini (file lebih kecil)
#   MAX_ZOOM=12             zoom maksimum tile (makin besar = makin detail & makin berat)
set -euo pipefail
cd "$(dirname "$0")/.."

RAW="raw"
OUT="data"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$OUT"

for cmd in ogr2ogr ogrinfo tippecanoe; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "ERROR: '$cmd' tidak ditemukan. Lihat README."; exit 1; }
done

SRC="$(find "$RAW" -maxdepth 1 -type f \( -iname '*kerawanan*.shp' -o -iname '*kerawanan*.geojson' \
  -o -iname '*kerawanan*.json' -o -iname '*kerawanan*.gpkg' -o -iname '*kerawanan*.zip' \) | head -n1 || true)"
if [ -z "$SRC" ]; then
  echo "ERROR: tidak ada file kerawanan di raw/ (nama harus memuat kata 'kerawanan')."; exit 1
fi
case "$SRC" in *.zip|*.ZIP) SRC="/vsizip/$SRC" ;; esac

echo "=== Kerawanan: $SRC"
echo "--- Kolom/atribut pada file ini (isi 'field' di config.json):"
ogrinfo -so -al "$SRC" | sed -n '/^Layer name/,$p' | head -40

# shellcheck disable=SC2086
ogr2ogr ${SHAPE_ENCODING:+--config SHAPE_ENCODING $SHAPE_ENCODING} \
  -f GeoJSON "$TMP/kerawanan.geojson" "$SRC" \
  -t_srs EPSG:4326 ${SRC_EPSG:+-s_srs EPSG:$SRC_EPSG} \
  -dim XY -makevalid -nlt PROMOTE_TO_MULTI \
  -lco COORDINATE_PRECISION=6 ${KEEP_FIELDS:+-select $KEEP_FIELDS}

tippecanoe -f -o "$OUT/kerawanan.pmtiles" -l kerawanan \
  -Z4 -z"${MAX_ZOOM:-12}" \
  --coalesce-smallest-as-needed --detect-shared-borders \
  --simplification=2 "$TMP/kerawanan.geojson"

echo "=== Selesai. Ukuran hasil:"
ls -lh "$OUT"

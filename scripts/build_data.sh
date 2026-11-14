#!/usr/bin/env bash
# Mengubah shapefile di folder raw/ menjadi PMTiles ringan di folder data/.
#   raw/*kerawanan*.shp  -> data/kerawanan.pmtiles
#   raw/*kawasan*.shp    -> data/kawasan.pmtiles + data/kawasan_index.json
#
# Opsi (environment variable, semuanya opsional):
#   SRC_EPSG=32750        paksa CRS sumber bila .prj tidak ada
#   SHAPE_ENCODING=UTF-8  paksa encoding atribut (.dbf)
#   KEEP_FIELDS=KELAS,SKOR  hanya simpan kolom tertentu pada kerawanan (mengecilkan file)
#   MAX_ZOOM_KER=12  MAX_ZOOM_KAW=13   zoom maksimum tile (makin besar = makin detail & makin berat)
set -euo pipefail
cd "$(dirname "$0")/.."

RAW="raw"
OUT="data"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$OUT"

for cmd in ogr2ogr ogrinfo tippecanoe python3; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "ERROR: '$cmd' tidak ditemukan. Lihat README."; exit 1; }
done

KER="$(find "$RAW" -maxdepth 1 -iname '*kerawanan*.shp' | head -n1 || true)"
KAW="$(find "$RAW" -maxdepth 1 -iname '*kawasan*.shp' ! -iname '*kerawanan*' | head -n1 || true)"

to_geojson() { # $1 = input .shp, $2 = output .geojson
  # shellcheck disable=SC2086
  ogr2ogr ${SHAPE_ENCODING:+--config SHAPE_ENCODING $SHAPE_ENCODING} \
    -f GeoJSON "$2" "$1" \
    -t_srs EPSG:4326 ${SRC_EPSG:+-s_srs EPSG:$SRC_EPSG} \
    -dim XY -makevalid -nlt PROMOTE_TO_MULTI \
    -lco COORDINATE_PRECISION=6 ${3:+-select $3}
}

if [ -n "$KER" ]; then
  echo "=== Kerawanan: $KER"
  echo "--- Kolom/atribut pada file ini (isi 'field' di config.json):"
  ogrinfo -so -al "$KER" | sed -n '/^Layer name/,$p' | head -40
  to_geojson "$KER" "$TMP/kerawanan.geojson" "${KEEP_FIELDS:-}"
  tippecanoe -f -o "$OUT/kerawanan.pmtiles" -l kerawanan \
    -Z4 -z"${MAX_ZOOM_KER:-12}" \
    --coalesce-smallest-as-needed --detect-shared-borders \
    --simplification=2 "$TMP/kerawanan.geojson"
else
  echo "(lewati) tidak ada raw/*kerawanan*.shp"
fi

if [ -n "$KAW" ]; then
  echo "=== Kawasan: $KAW"
  echo "--- Kolom/atribut pada file ini (isi 'namaField' di config.json):"
  ogrinfo -so -al "$KAW" | sed -n '/^Layer name/,$p' | head -40
  to_geojson "$KAW" "$TMP/kawasan.geojson" ""
  tippecanoe -f -o "$OUT/kawasan.pmtiles" -l kawasan \
    -Z3 -z"${MAX_ZOOM_KAW:-13}" \
    --drop-smallest-as-needed --simplification=2 "$TMP/kawasan.geojson"
  python3 scripts/make_index.py "$TMP/kawasan.geojson" "$OUT/kawasan_index.json"
else
  echo "(lewati) tidak ada raw/*kawasan*.shp"
fi

echo "=== Selesai. Ukuran hasil:"
ls -lh "$OUT"

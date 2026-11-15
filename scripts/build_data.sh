#!/usr/bin/env bash
# Mengubah data mentah di folder raw/ menjadi vector tiles ringan (PMTiles) di folder data/.
#
#   raw/*kerawanan*.shp           -> data/kerawanan.pmtiles  (kolom Rwn_karhut)
#   raw/BA_KK_2015_2026_CEA.shp   -> data/frekuensi.pmtiles  (kolom Frekuensi)
#   raw/KK_Gambut_Final_CEA.shp   -> data/gambut.pmtiles     (kolom Skor_Gbt)
#   raw/KK_Jalan_v2.shp           -> data/jalan.pmtiles
#   raw/KK_Sungai_v2.shp          -> data/sungai.pmtiles
#   raw/KK_Pemukiman_v2.shp       -> data/pemukiman.pmtiles
#
# Setiap sumber bisa berupa .shp, .geojson, .gpkg, atau .zip (berisi shapefile).
# Layer yang filenya tidak ada di raw/ dilewati. Batas kawasan TIDAK diproses:
# taruh langsung data/kawasan.geojson.
#
# Opsi (environment variable, semuanya opsional):
#   SRC_EPSG=32750              paksa CRS sumber bila .prj tidak ada
#   SHAPE_ENCODING=UTF-8        paksa encoding atribut (.dbf)
#   MAX_ZOOM=12                 zoom maksimum tile (makin besar = makin detail & makin berat)
#   KEEP_FIELDS_<ID>=kolom1,kolom2   simpan kolom tertentu saja pada satu layer,
#                                    mis. KEEP_FIELDS_KERAWANAN=Rwn_karhut
#                                    (ID: KERAWANAN FREKUENSI GAMBUT JALAN SUNGAI PEMUKIMAN)
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

BUILT=0

find_src() { # $1 = pola nama file tanpa ekstensi (boleh memakai *)
  find "$RAW" -maxdepth 1 -type f \( -iname "$1.shp" -o -iname "$1.geojson" -o -iname "$1.json" \
    -o -iname "$1.gpkg" -o -iname "$1.zip" \) | head -n1 || true
}

build_layer() { # $1=id  $2=pola nama  $3=zoom min  $4=zoom maks  $5...=opsi tambahan tippecanoe
  local id="$1" pat="$2" zmin="$3" zmax="$4"
  shift 4
  local src
  src="$(find_src "$pat")"
  if [ -z "$src" ]; then
    echo "(lewati) [$id] tidak ada file '$pat' di raw/"
    return 0
  fi
  case "$src" in *.zip|*.ZIP) src="/vsizip/$src" ;; esac

  local keepvar keep
  keepvar="KEEP_FIELDS_$(echo "$id" | tr '[:lower:]' '[:upper:]')"
  keep="${!keepvar:-}"

  echo
  echo "=== [$id] $src"
  echo "--- Kolom/atribut pada file ini:"
  ogrinfo -so -al "$src" | sed -n '/^Layer name/,$p' | head -40

  # shellcheck disable=SC2086
  ogr2ogr ${SHAPE_ENCODING:+--config SHAPE_ENCODING $SHAPE_ENCODING} \
    -f GeoJSON "$TMP/$id.geojson" "$src" \
    -t_srs EPSG:4326 ${SRC_EPSG:+-s_srs EPSG:$SRC_EPSG} \
    -dim XY -makevalid -nlt PROMOTE_TO_MULTI \
    -lco COORDINATE_PRECISION=6 ${keep:+-select $keep}

  tippecanoe -f -o "$OUT/$id.pmtiles" -l "$id" \
    -Z"$zmin" -z"${MAX_ZOOM:-$zmax}" "$@" "$TMP/$id.geojson"
  rm -f "$TMP/$id.geojson"
  BUILT=$((BUILT + 1))
}

# Poligon luas: gabungkan poligon kecil bila tile terlalu padat.
build_layer kerawanan '*kerawanan*'          0 12 --coalesce-smallest-as-needed --detect-shared-borders --simplification=2
build_layer frekuensi 'BA_KK_2015_2026_CEA'  0 12 --coalesce-smallest-as-needed --simplification=2
build_layer gambut    'KK_Gambut_Final_CEA'  0 12 --coalesce-smallest-as-needed --detect-shared-borders --simplification=2
# Garis & pemukiman: baru dibuat mulai zoom 7 (sesuai "minzoom" di config.json).
build_layer jalan     'KK_Jalan_v2'          7 13 --drop-densest-as-needed --extend-zooms-if-still-dropping
build_layer sungai    'KK_Sungai_v2'         7 13 --drop-densest-as-needed --extend-zooms-if-still-dropping
build_layer pemukiman 'KK_Pemukiman_v2'      7 13 --drop-smallest-as-needed --simplification=2

if [ "$BUILT" -eq 0 ]; then
  echo "ERROR: tidak ada data yang dibangun. Periksa nama file di raw/ (lihat komentar di atas)."
  exit 1
fi

echo
echo "=== Selesai: $BUILT layer. Ukuran hasil:"
ls -lh "$OUT"

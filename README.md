# WebGIS Kerawanan Kebakaran

Peta web statis (MapLibre GL) dengan:

- **Batas kawasan** (`data/kawasan.geojson`, GeoJSON biasa, garis `#AD3FFF`) + **label nama kawasan** dari kolom `NKWS`.
- **6 layer data** berbentuk vector tiles PMTiles, dibuat otomatis dari data mentah di `raw/`.
- **Panel kiri tunggal** (menempel penuh di sisi kiri, bisa disembunyikan/ditampilkan dengan tombol di tepinya) berisi cari kawasan, peta dasar, serta legenda & layer.
- **Legenda interaktif**: klik item untuk menampilkan / menyembunyikan layer; tiap layer punya slider **opasitas** sendiri dan pegangan ⠿ untuk **mengatur urutan dengan drag-and-drop** (paling atas di daftar = paling depan di peta; bisa juga dengan tombol panah atas/bawah saat pegangan difokuskan). Klik popup mengikuti urutan yang sama.

```
├── index.html
├── config.json                  # daftar layer, kolom, warna, legenda, label
├── assets/
│   ├── logo kehutanan.png       # nama persis seperti ini
│   └── Logo KK.png              # nama persis seperti ini (huruf besar/kecil berpengaruh di GitHub Pages)
├── raw/                         # data mentah (shp / geojson / gpkg / zip)
├── data/
│   ├── kawasan.geojson          # taruh langsung di sini
│   └── *.pmtiles                # dibuat otomatis dari raw/
├── scripts/build_data.sh
└── .github/workflows/pages.yml  # build tiles + deploy
```

## Layer

| Layer | File di `raw/` | Kolom | Simbologi | Default |
|---|---|---|---|---|
| Kerawanan Kebakaran | `Skoring_Kerawanan_Kebakaran_KK_dissolve.*` (nama memuat "kerawanan") | `Rwn_karhut` | 4 Sangat Tinggi `#d32020`, 3 Tinggi `#fb7050`, 2 Sedang `#fcbea5`, 1 Rendah `#fff5f0` | tampil |
| Frekuensi Kebakaran 2015-2026 | `BA_KK_2015_2026_CEA.*` | `Frekuensi` | gradasi kuning → merah tua (titik warna di `config.json`, `gradasi`) | sembunyi |
| Gambut | `KK_Gambut_Final_CEA.*` | `Skor_Gbt` | 5 = Gambut (hijau), 1 = Non-Gambut (oranye) | sembunyi |
| Jalan | `KK_Jalan_v2.*` | - | garis merah, tampil zoom ≥ 7 | sembunyi |
| Sungai | `KK_Sungai_v2.*` | - | garis biru, tampil zoom ≥ 7 | sembunyi |
| Pemukiman | `KK_Pemukiman_v2.*` | - | poligon ungu `#8e24aa`, tampil zoom ≥ 7 | sembunyi |

- **Area tanpa data dibiarkan kosong.** Pulau atau kawasan yang tidak punya data (mis. Sulawesi, Maluku, Papua) tidak digambar sama sekali. Poligon bernilai 0, kosong, atau di luar legenda juga tidak diwarnai.
- Ubah warna, label, nilai, opasitas awal (`opacity`), urutan awal (`z`: makin besar makin di atas), dan layer yang tampil saat dibuka (`"visible": true/false`) di `config.json`. Pengaturan opasitas dan urutan di panel berlaku selama halaman terbuka.
- Rentang gradasi frekuensi di `config.json` (nilai 1 sampai 12) hanya perkiraan. Sesuaikan dengan nilai maksimum `Frekuensi` pada data Anda.
- Layer yang file mentahnya tidak ada dilewati, dan peta memberi tahu layer mana yang belum tersedia.

## Label kawasan

Label `NKWS` meniru aturan di dashboard: muncul mulai zoom 9 (zoom Leaflet; di peta ini setara zoom 8), ukuran huruf `max(8, 9 + (zoom-9)*1.1)` px, huruf tebal `#00334e` dengan garis tepi putih, ditempatkan di dalam bagian kawasan yang sedang terlihat di layar. Label bisa dimatikan lewat legenda ("Label Kawasan").

## Mode A: build otomatis di GitHub (tanpa install)

1. Buat repository baru di GitHub.
2. Taruh `kawasan.geojson` di `data/`, semua shapefile di `raw/` (lengkap dengan `.shx .dbf .prj .cpg`), dan logo di `assets/`.
3. Upload lewat **Git atau GitHub Desktop**, karena file besar tidak bisa lewat web (batas web 25 MB per file; batas GitHub 100 MB per file):
   ```bash
   git init && git add . && git commit -m "WebGIS kerawanan"
   git branch -M main
   git remote add origin https://github.com/USERNAME/NAMA-REPO.git
   git push -u origin main
   ```
4. **Settings → Pages → Build and deployment → Source: GitHub Actions**.
5. Tunggu workflow di tab **Actions** selesai (±5-20 menit tergantung ukuran data). Alamat: `https://USERNAME.github.io/NAMA-REPO/`.
6. Log langkah *Build PMTiles* menampilkan daftar kolom setiap file. Pastikan nama kolom sama dengan `field` di `config.json`.

Bila ada file mentah yang lebih dari 100 MB, perkecil dulu (mapshaper.org atau QGIS) atau pakai Mode B.

## Mode B: build di komputer sendiri (bisa upload lewat web)

Butuh GDAL (`ogr2ogr`) dan `tippecanoe` (Linux/macOS, atau WSL di Windows):

```bash
bash scripts/build_data.sh
python3 -m http.server 8000   # uji di http://localhost:8000
```

Hasil di `data/*.pmtiles` biasanya jauh lebih kecil dari data mentah, sehingga bisa diupload lewat web GitHub. Hapus tanda `#` pada baris `# raw/` di `.gitignore` agar data mentah tidak ikut. Workflow otomatis melewati build bila `raw/` kosong. Pengaturan Pages tetap *GitHub Actions*.

## Pengaturan lanjutan (environment variable pada build)

| Variabel | Fungsi |
|---|---|
| `SRC_EPSG=32750` | Paksa CRS sumber bila data tanpa info CRS (berlaku ke semua layer) |
| `SHAPE_ENCODING=UTF-8` | Perbaiki karakter atribut yang rusak |
| `MAX_ZOOM=12` | Zoom maksimum tile; turunkan bila file masih terlalu besar |
| `KEEP_FIELDS_KERAWANAN=Rwn_karhut` | Simpan kolom tertentu saja pada satu layer (ID: `KERAWANAN FREKUENSI GAMBUT JALAN SUNGAI PEMUKIMAN`) |

Di GitHub Actions, isi pada blok `env:` (contoh komentar ada di `pages.yml`).

## Catatan

- `kawasan.geojson` harus berkoordinat WGS84 (EPSG:4326). Shapefile `_CEA` perlu `.prj` agar diproyeksikan ulang dengan benar.
- Folder `raw/` harus tetap ada di repo pada Mode A karena tiles dibangun ulang tiap push.
- Klik peta untuk melihat atribut kawasan dan layer yang sedang tampil pada titik tersebut.
- Peta dasar memakai tile Esri dan OpenStreetMap; cantumkan atribusi bila dipublikasikan luas.

# WebGIS Kerawanan Kebakaran

Peta web statis (MapLibre GL + PMTiles) berisi **batas kawasan** dan **skoring kerawanan kebakaran**.
Shapefile besar (±80 MB) diubah otomatis menjadi *vector tiles* sehingga browser hanya mengunduh bagian peta yang sedang dilihat.

```
├── index.html                  # aplikasi peta
├── config.json                 # judul, kolom, warna kelas, legenda
├── assets/                     # logo-kehutanan.png, logo-kk.png (opsional)
├── raw/                        # TARUH SHAPEFILE DI SINI
├── data/                       # hasil build (kerawanan.pmtiles, kawasan.pmtiles, kawasan_index.json)
├── scripts/build_data.sh       # shapefile -> PMTiles (dipakai Actions maupun lokal)
├── scripts/make_index.py       # indeks pencarian kawasan
└── .github/workflows/pages.yml # build + deploy otomatis
```

## Mode A (disarankan): build otomatis di GitHub, tanpa install apa pun

1. Buat repository baru di GitHub (mis. `webgis-kerawanan`).
2. Siapkan shapefile di folder `raw/` (semua komponennya: `.shp .shx .dbf .prj .cpg`):
   - Kerawanan: `Skoring_Kerawanan_Kebakaran_KK_dissolve.*` (nama harus memuat kata **kerawanan**).
   - Batas kawasan: ganti nama menjadi mis. `kawasan.*` (nama harus memuat kata **kawasan**).
3. Upload ke GitHub **lewat Git atau GitHub Desktop**, bukan drag-and-drop di web (web dibatasi 25 MB per file; batas mutlak GitHub 100 MB per file):
   ```bash
   cd webgis-kerawanan
   git init
   git add .
   git commit -m "WebGIS kerawanan kebakaran"
   git branch -M main
   git remote add origin https://github.com/USERNAME/webgis-kerawanan.git
   git push -u origin main
   ```
4. Di GitHub: **Settings → Pages → Build and deployment → Source: GitHub Actions**.
5. Buka tab **Actions**, tunggu workflow selesai (±3-6 menit, karena tippecanoe dikompilasi). Alamat peta: `https://USERNAME.github.io/webgis-kerawanan/`.
6. Buka log langkah *Build data*: ada daftar kolom shapefile. Sesuaikan `config.json`:
   - `kerawanan.field` = kolom kelas/skor, dan `kerawanan.kelas[].nilai` = isi kolom tersebut persis (huruf besar/kecil berpengaruh).
   - `kawasan.namaField` = kolom nama kawasan.
   Lalu commit + push lagi (build ulang otomatis).

Folder `raw/` harus tetap ada di repo pada mode ini, karena data dibangun ulang tiap push.

## Mode B: build di komputer sendiri (repo lebih ringan)

Butuh GDAL (`ogr2ogr`), `tippecanoe`, dan Python 3 (Linux/macOS, atau WSL di Windows).

```bash
bash scripts/build_data.sh
python3 -m http.server 8000      # uji lokal di http://localhost:8000
```

Lalu hapus tanda `#` pada baris `# raw/` di `.gitignore`, commit folder `data/`, dan push. Workflow otomatis melewati build bila `raw/` tidak berisi `.shp`. Pengaturan Pages tetap *GitHub Actions*.

## Pengaturan lanjutan (environment variable pada build)

| Variabel | Fungsi |
|---|---|
| `SRC_EPSG=32750` | Paksa CRS sumber bila shapefile tanpa `.prj` |
| `SHAPE_ENCODING=UTF-8` | Perbaiki karakter atribut yang rusak |
| `KEEP_FIELDS=KELAS,SKOR` | Simpan kolom tertentu saja pada kerawanan, file lebih kecil |
| `MAX_ZOOM_KER=12` | Zoom maksimum tile kerawanan; turunkan bila file masih terlalu besar |

Di GitHub Actions, isi variabel ini pada blok `env:` (sudah ada contoh komentar di `pages.yml`).

## Catatan

- Ganti logo dengan menaruh `assets/logo-kehutanan.png` dan `assets/logo-kk.png` (bila tidak ada, otomatis disembunyikan).
- Peta dasar memakai tile Esri dan OpenStreetMap; cantumkan atribusi bila dipublikasikan luas.
- Klik peta untuk melihat atribut kawasan dan kerawanan pada titik tersebut.

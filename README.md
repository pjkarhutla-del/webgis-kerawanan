# WebGIS Kerawanan Kebakaran

Peta web statis (MapLibre GL) dengan dua layer:

- **Batas kawasan**: GeoJSON biasa (`data/kawasan.geojson`), dimuat langsung.
- **Kerawanan kebakaran**: vector tiles PMTiles (`data/kerawanan.pmtiles`), dibuat dari data mentah ±80 MB sehingga browser hanya mengunduh bagian yang sedang dilihat.

```
├── index.html
├── config.json                  # judul, kolom, warna & legenda
├── assets/                      # logo-kehutanan.png, logo-kk.png (opsional)
├── raw/                         # data kerawanan mentah (shp / geojson / gpkg / zip)
├── data/
│   ├── kawasan.geojson          # taruh langsung di sini
│   └── kerawanan.pmtiles        # dibuat otomatis dari raw/
├── scripts/build_data.sh
└── .github/workflows/pages.yml  # build tiles + deploy
```

## Simbologi kerawanan (kolom `Rwn_karhut`)

| Nilai | Warna |
|---|---|
| 4 (tertinggi) | `#d32020` |
| 3 | `#fb7050` |
| 2 | `#fcbea5` |
| 1 (terendah) | `#fff5f0` |

Warna, label legenda, dan nama kolom diatur di `config.json` bagian `kerawanan`; legenda dibuat otomatis dari daftar itu.

## Mode A: build otomatis di GitHub (tanpa install)

1. Buat repository baru di GitHub.
2. Taruh `kawasan.geojson` di `data/`, dan data kerawanan (`Skoring_Kerawanan_Kebakaran_KK_dissolve.shp` beserta `.shx .dbf .prj .cpg`, atau `.zip`-nya) di `raw/`.
3. Upload lewat **Git atau GitHub Desktop** karena file ±80 MB tidak bisa lewat web (batas web 25 MB per file; batas GitHub 100 MB):
   ```bash
   git init && git add . && git commit -m "WebGIS kerawanan"
   git branch -M main
   git remote add origin https://github.com/USERNAME/NAMA-REPO.git
   git push -u origin main
   ```
4. **Settings → Pages → Build and deployment → Source: GitHub Actions**.
5. Tunggu workflow di tab **Actions** selesai (±3-6 menit). Alamat: `https://USERNAME.github.io/NAMA-REPO/`.
6. Log langkah *Build kerawanan.pmtiles* menampilkan daftar kolom data. Pastikan `kerawanan.field` di `config.json` sama dengan kolom kelas (`Rwn_karhut`) dan `kawasan.namaField` sama dengan kolom nama kawasan.

## Mode B: build di komputer sendiri (bisa upload lewat web)

Butuh GDAL (`ogr2ogr`) dan `tippecanoe` (Linux/macOS, atau WSL di Windows):

```bash
bash scripts/build_data.sh
python3 -m http.server 8000   # uji di http://localhost:8000
```

`data/kerawanan.pmtiles` biasanya jauh di bawah 25 MB, jadi bersama `kawasan.geojson` bisa diupload lewat web GitHub. Hapus tanda `#` pada baris `# raw/` di `.gitignore` agar data mentah tidak ikut. Workflow otomatis melewati build bila `raw/` kosong. Pengaturan Pages tetap *GitHub Actions*.

## Pengaturan lanjutan (environment variable pada build)

| Variabel | Fungsi |
|---|---|
| `SRC_EPSG=32750` | Paksa CRS sumber bila data tanpa info CRS |
| `SHAPE_ENCODING=UTF-8` | Perbaiki karakter atribut yang rusak |
| `KEEP_FIELDS=Rwn_karhut` | Simpan kolom tertentu saja, file lebih kecil |
| `MAX_ZOOM=12` | Zoom maksimum tile; turunkan bila file masih terlalu besar |

Di GitHub Actions, isi pada blok `env:` (contoh komentar ada di `pages.yml`).

## Catatan

- `kawasan.geojson` harus berkoordinat WGS84 (EPSG:4326).
- Folder `raw/` harus tetap ada di repo pada Mode A karena tiles dibangun ulang tiap push.
- Klik peta untuk melihat atribut kawasan dan kerawanan.
- Peta dasar memakai tile Esri dan OpenStreetMap; cantumkan atribusi bila dipublikasikan luas.

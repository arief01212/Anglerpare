# 🎣 Fishing Solunar

Aplikasi mobile **Flutter** untuk menentukan **waktu makan ikan (solunar)** di
spot lokasi pengguna. Perhitungan solunar berjalan **100% offline** (tanpa
internet & tanpa API key) berdasarkan posisi **Bulan & Matahari**. Peta memakai
**OpenStreetMap** gratis.

> Internet hanya dipakai untuk memuat ubin (tile) peta. Perhitungan jadwal makan
> ikan tetap berfungsi tanpa koneksi.

---

## ✨ Fitur

- 🗺️ **Peta interaktif** `flutter_map` + OpenStreetMap (gratis, tanpa API key).
- 📍 **GPS otomatis** mengambil lokasi pengguna via `geolocator`.
- 🌙 **Perhitungan solunar offline** dari posisi Bulan & Matahari:
  - **Major Period** — saat Bulan transit atas & bawah (durasi ±2 jam).
  - **Minor Period** — saat moonrise & moonset (durasi ±1 jam).
  - **Faktor fase bulan** — aktivitas tertinggi saat purnama / bulan baru.
  - **Bonus skor** bila periode beririsan dengan sunrise/sunset.
- ➕ **Tambah spot** dengan **long-press** di peta, lalu jadwal makan ikan
  langsung dihitung ulang untuk titik tersebut.
- 📊 **Panel bawah**: fase bulan, daftar periode Major/Minor, skor berwarna
  (🟢 hijau / 🟠 oranye / 🔴 merah), dan penanda **"SEKARANG"** saat ikan aktif.
- 🕒 Semua waktu memakai **zona waktu lokal perangkat**.

---

## 🧮 Rumus Skor

```
Skor = Bobot_Periode × Faktor_Fase + Bonus_Matahari
```

| Komponen | Nilai |
|---|---|
| Bobot Major (transit atas/bawah Bulan) | **1.0** |
| Bobot Minor (moonrise/moonset) | **0.6** |
| Faktor Fase | **0.5 – 1.0** (tertinggi saat purnama & bulan baru) |
| Bonus Matahari | **+0.3** bila beririsan sunrise/sunset (±1 jam) |

Faktor fase memakai `0.75 + 0.25 · cos(4πφ)`, dengan `φ` = fase bulan
(0 = baru, 0.5 = purnama). Puncak (1.0) terjadi saat bulan baru & purnama,
lembah (0.5) saat kuartal.

**Pewarnaan skor:** `≥ 0.9` hijau (Tinggi) · `≥ 0.6` oranye (Sedang) ·
`< 0.6` merah (Rendah).

---

## 📁 Struktur Proyek

```
lib/
├── main.dart                         # Entry point aplikasi
├── models/
│   ├── fishing_spot.dart             # Model spot mancing
│   └── solunar_models.dart           # SolunarPeriod, SolunarDay, rating, enum
├── services/
│   ├── sun_calc.dart                 # Port algoritma SunCalc (Matahari & Bulan) - OFFLINE
│   ├── solunar_calculator.dart       # Logika solunar + rumus skor
│   └── location_service.dart         # Pembungkus GPS geolocator
└── ui/
    ├── map_screen.dart               # Peta OSM + interaksi long-press
    └── solunar_panel.dart            # Panel bawah (fase, periode, skor, "SEKARANG")
test/
└── solunar_calculator_test.dart      # Unit test mesin solunar
```

> **Catatan astronomi:** Rumus posisi Matahari & Bulan di `sun_calc.dart`
> merupakan port langsung dari algoritma **SunCalc** (Vladimir Agafonkin,
> lisensi BSD-2). Disertakan di dalam proyek agar perhitungan **sepenuhnya
> offline** dan tidak bergantung pada perubahan API paket pihak ketiga. Jika
> Anda lebih memilih paket `suncalc` dari pub.dev, mesin di `solunar_calculator.dart`
> dapat dengan mudah diarahkan ke paket tersebut.

---

## 🚀 Langkah Setup

### 1. Prasyarat
- Flutter SDK **3.x** (Dart `>=3.0.0`). Cek dengan `flutter doctor`.

### 2. Buat scaffolding platform
Repo ini berisi kode `lib/`, `pubspec.yaml`, `test/`, serta file izin
(`AndroidManifest.xml` & `Info.plist`). Untuk melengkapi folder platform
(`android/`, `ios/`, dll.) di proyek yang baru di-clone, jalankan di root:

```bash
flutter create .
```

> `flutter create` **tidak menimpa** file yang sudah ada, sehingga
> `AndroidManifest.xml`, `Info.plist`, dan kode `lib/` Anda tetap aman.

### 3. Pasang dependensi
```bash
flutter pub get
```

### 4. Jalankan
```bash
flutter run
```

### 5. Uji logika solunar
```bash
flutter test
```

---

## 🔐 Konfigurasi Izin Lokasi

### Android — `android/app/src/main/AndroidManifest.xml`
Sudah disertakan:
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.INTERNET" />
```
Pastikan `minSdkVersion` minimal **21** di `android/app/build.gradle`
(geolocator & flutter_map). Contoh:
```gradle
defaultConfig {
    minSdkVersion 21
    targetSdkVersion 34
}
```

### iOS — `ios/Runner/Info.plist`
Sudah disertakan:
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Aplikasi memerlukan lokasi untuk menghitung waktu makan ikan (solunar) di sekitar Anda.</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>Aplikasi memerlukan lokasi untuk menghitung waktu makan ikan (solunar) di sekitar Anda.</string>
```
Set deployment target iOS **12.0+** di `ios/Podfile` (`platform :ios, '12.0'`).

---

## 🕹️ Cara Pakai

1. Buka aplikasi → lokasi GPS diambil otomatis (izinkan akses lokasi).
2. Panel bawah menampilkan fase bulan, periode Major/Minor, dan skor.
3. **Long-press** di mana saja pada peta untuk menambah spot baru — jadwal
   makan ikan otomatis dihitung ulang untuk titik tersebut.
4. Tap penanda spot untuk berpindah perhitungan antar lokasi.
5. Saat ada periode aktif, banner hijau **"IKAN SEDANG AKTIF — SEKARANG!"**
   muncul dan periode terkait ditandai **SEKARANG**.

---

## 📦 Dependensi

| Paket | Fungsi |
|---|---|
| `flutter_map` | Peta interaktif berbasis OpenStreetMap |
| `latlong2` | Tipe koordinat `LatLng` |
| `geolocator` | Akses GPS / lokasi perangkat |

Algoritma astronomi (SunCalc) disertakan langsung di dalam proyek untuk
operasi offline.

---

## ⚠️ Catatan

- Akurasi posisi Bulan/Matahari mengikuti algoritma SunCalc (presisi cukup
  untuk keperluan solunar memancing, bukan untuk navigasi astronomi presisi).
- Pada lintang ekstrem, Matahari/Bulan bisa tidak terbit/terbenam pada hari
  tertentu; periode terkait akan dilewati secara otomatis.

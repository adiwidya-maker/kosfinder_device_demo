# LAPORAN WORKSHEET 10
## Pemrograman Mobile: Advanced Mobile Features & Device Integration
**Flutter • Camera • GPS • Sensors • Permanent Storage • Supabase Cloud**

```
+--------------------------------------------------------------------------+
| Nama      : I Gede Adiwidya Utama                                        |
| NIM       : 2415051001                                                   |
| Kelas     : 5 IKI / PTI                                                  |
| Tanggal   : 20 November 2026                                             |
| Proyek    : KosFinder Device Demo (kosfinder_device_demo)                |
| Dosen     : Dr. Ir. I Ketut Resika Arthana, S.T., M.Kom.                 |
| Asisten   : Made Yuda Sadewa, S.Pd.                                      |
+--------------------------------------------------------------------------+
```

---

## DAFTAR ISI
1. [A. Ringkasan Praktikum & Capaian Pembelajaran](#a-ringkasan-praktikum--capaian-pembelajaran)
2. [B. Arsitektur & Struktur Source Code](#b-arsitektur--struktur-source-code)
3. [C. Konfigurasi Izin & Dependency](#c-konfigurasi-izin--dependency)
4. [D. Implementasi Fitur Perangkat (Praktik 1 - 4)](#d-implementasi-fitur-perangkat-praktik-1---4)
5. [E. Modul Pengayaan: Supabase Storage & Sensor Accelerometer](#e-modul-pengayaan-supabase-storage--sensor-accelerometer)
6. [F. Jawaban Pertanyaan Teori & Analisis](#f-jawaban-pertanyaan-teori--analisis)
7. [G. Tabel Pengujian Terstruktur (12 Kasus Uji)](#g-tabel-pengujian-terstruktur-12-kasus-uji)
8. [H. Refleksi Mahasiswa](#h-refleksi-mahasiswa)
9. [I. Panduan Menjalankan & Eksekusi Git](#i-panduan-menjalankan--eksekusi-git)

---

## A. Ringkasan Praktikum & Capaian Pembelajaran

Pada praktikum Worksheet 10 ini, dibangun aplikasi standalone **KosFinder Device Demo** (`kosfinder_device_demo`) yang berfokus pada integrasi fitur perangkat keras (*device hardware features*) dan penyimpanan data persisten lokal (*offline-first*).

### Capaian Utama:
1. **Camera & Gallery Integration:** Pengguna dapat mengambil foto kamar kos secara langsung melalui kamera fisik atau memilih foto yang sudah ada di galeri menggunakan library `image_picker`.
2. **Permanent Storage Sandbox:** Menjamin keamanan persistensi foto dengan memindahkannya dari *temporary cache* ke *Application Documents Directory* menggunakan `path_provider`, serta memvalidasi tipe file (JPG/PNG) dan ukuran maksimal 5 MB.
3. **Permission-Aware GPS:** Mengambil koordinat geolokasi (*Latitude* & *Longitude*) menggunakan `geolocator` dengan penanganan komprehensif terhadap kondisi *GPS Off*, *Permission Denied*, dan *Permission Denied Forever*.
4. **Draft Persistence & Recovery:** Menyimpan draft formulir kos ke `SharedPreferencesAsync` dalam format serialisasi JSON sehingga draft tetap utuh dan dipulihkan secara otomatis saat aplikasi ditutup lalu dibuka kembali.
5. **Real-time Accelerometer Sensor:** Membaca sensor gerak akselerometer bebas gravitasi secara interaktif dengan indikator visual dinamis menggunakan `sensors_plus`.
6. **Supabase Storage (Pengayaan):** Mengunggah foto ke cloud bucket `kosfinder-demo` menggunakan metode *Anonymous Sign-In* dan kebijakan *Row Level Security* (RLS) berbasis folder `auth.uid()`.

---

## B. Arsitektur & Struktur Source Code

Aplikasi disusun dengan arsitektur modular yang memisahkan antara *UI Layer*, *Service Layer*, dan *Configuration Layer*:

```
lib/
├── cloud_config.dart                  # Konfigurasi runtime cloud Supabase (flag enabled)
├── main.dart                          # Standalone entry point aplikasi KosFinder Device Demo
├── pages/
│   ├── device_demo_page.dart          # Antarmuka utama input kos, kamera, GPS, & draft
│   └── sensor_demo_page.dart          # Halaman demonstrasi sensor gerak accelerometer
└── services/
    ├── device_location_service.dart   # Service penanganan izin & pembacaan koordinat GPS
    ├── draft_repository.dart          # Service persistensi foto permanen & draft JSON
    └── photo_upload_service.dart      # Service anonymous auth & upload Supabase Storage
android/app/src/main/AndroidManifest.xml
ios/Runner/Info.plist
sql/storage_policy.sql
test/widget_test.dart
```

---

## C. Konfigurasi Izin & Dependency

### 1. `pubspec.yaml`
```yaml
dependencies:
  flutter:
    sdk: flutter
  supabase_flutter: ^2.8.0
  image_picker: ^1.1.2
  geolocator: ^13.0.2
  path_provider: ^2.1.5
  shared_preferences: ^2.3.3
  sensors_plus: ^4.0.2
```

### 2. Android Manifest (`android/app/src/main/AndroidManifest.xml`)
```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.adiwidya.kosfinder">

    <!-- Izin Lokasi Perangkat untuk Fitur GPS -->
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    
    <!-- Izin Akses Internet untuk Modul Cloud Upload -->
    <uses-permission android:name="android.permission.INTERNET" />
    
    <application ...>
        ...
    </application>
</manifest>
```

### 3. iOS Info.plist (`ios/Runner/Info.plist`)
```xml
<key>NSCameraUsageDescription</key>
<string>Fitur demo memerlukan kamera untuk memotret kamar kos.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Fitur demo memilih foto kamar dari galeri.</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>Fitur demo menggunakan lokasi untuk mengisi koordinat.</string>
<key>NSMotionUsageDescription</key>
<string>Fitur demo membaca gerakan perangkat untuk belajar sensor.</string>
```

---

## D. Implementasi Fitur Perangkat (Praktik 1 - 4)

### 1. Entry Point Aplikasi (`lib/main.dart`)
Menginisialisasi Supabase hanya bila parameter `--dart-define` disuplai saat kompilasi. Jika tidak ada, aplikasi berjalan 100% secara offline tanpa error.
```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (CloudConfig.enabled) {
    await Supabase.initialize(
      url: CloudConfig.url,
      anonKey: CloudConfig.publishableKey,
    );
  }
  runApp(const KosFinderDeviceApp());
}
```

### 2. Pengelolaan Foto Permanen & Draft (`lib/services/draft_repository.dart`)
* Validasi ekstensi file: hanya menerima `.jpg`, `.jpeg`, `.png`.
* Validasi ukuran file: membatasi maksimal 5 MB ($5 \times 1024 \times 1024$ bytes).
* Pemindahan file: menyalin file dari path sementara `XFile` ke `getApplicationDocumentsDirectory()/kosfinder_photos/<timestamp>.<ext>`.
* Serialisasi: menyimpan dictionary draft ke `SharedPreferencesAsync` menggunakan `jsonEncode()`.

### 3. Layanan GPS Sadar Izin (`lib/services/device_location_service.dart`)
* Pengecekan GPS aktif: memanggil `Geolocator.isLocationServiceEnabled()`. Jika mati, melempar exception `LocationFailureType.serviceDisabled`.
* Pemeriksaan izin: memanggil `Geolocator.checkPermission()`. Jika `denied`, meminta izin via `Geolocator.requestPermission()`. Jika `deniedForever`, melempar exception `LocationFailureType.deniedForever`.
* Pengambilan posisi: menggunakan `LocationAccuracy.high` dengan batas waktu `timeLimit: Duration(seconds: 20)`.

### 4. UI Integratif & Pemulihan Foto Terputus (`lib/pages/device_demo_page.dart`)
* Menggunakan `_picker.retrieveLostData()` saat inisialisasi awal untuk memulihkan foto jika proses aplikasi sempat dimatikan oleh sistem operasi Android saat membuka kamera bawaan.
* Menyediakan tombol navigasi sistem jika GPS dinonaktifkan atau ditolak permanen.

---

## E. Modul Pengayaan: Supabase Storage & Sensor Accelerometer

### 1. Supabase Anonymous Storage Upload (`lib/services/photo_upload_service.dart`)
* Menggunakan `client.auth.signInAnonymously()` untuk membuat identitas anonim sah tanpa registrasi manual.
* Objek diunggah ke path berformat: `<auth.uid()>/<timestamp>.<ext>`.

### 2. SQL Row Level Security Policy (`sql/storage_policy.sql`)
```sql
drop policy if exists "ws10_demo_upload_own_folder" on storage.objects;

create policy "ws10_demo_upload_own_folder"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'kosfinder-demo'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
  );
```

### 3. Demo Accelerometer (`lib/pages/sensor_demo_page.dart`)
* Mendengarkan `userAccelerometerEventStream()`.
* Memperbarui nilai sumbu X, Y, Z dan merender grafik indikator dinamis.
* Menghentikan subscription di `dispose()` agar tidak terjadi memory leak.

---

## F. Jawaban Pertanyaan Teori & Analisis

### Pertanyaan Praktik 2:
1. **Mengapa foto tidak cukup disimpan sebagai path dari `image_picker` saja?**  
   *Jawaban:* `image_picker` menyimpan file sementara pada direktori cache OS yang bersifat volatil. OS sewaktu-waktu dapat menghapus file cache tersebut saat memori menipis atau saat perangkat reboot, sehingga path yang tersimpan akan menjadi *broken link*. Menyalin foto ke `Application Documents Directory` menjamin file tersimpan secara permanen.
2. **Apa yang terjadi pada draft lokal jika aplikasi di-uninstall atau data aplikasinya dihapus?**  
   *Jawaban:* Direktori sandbox internal aplikasi (termasuk folder documents dan file `SharedPreferences`) akan dihapus total oleh sistem operasi. Seluruh file foto fisik dan string metadata JSON akan hilang permanen, sehingga saat aplikasi dibuka kembali data draft akan kembali ke keadaan awal (*clean state*).

### Pertanyaan Praktik 3:
1. **Mengapa aplikasi tidak boleh memaksa pengguna memberikan izin GPS untuk memakai galeri?**  
   *Jawaban:* Fitur foto dan GPS adalah dua fungsi perangkat keras yang terpisah secara teknis. Memaksa izin lokasi yang tidak esensial (*permission coercion*) melanggar prinsip *Least Privilege*, menurunkan kepercayaan pengguna, dan berpotensi memicu uninstall. Aplikasi harus menerapkan *Graceful Degradation*, di mana pengguna tetap bisa menyimpan draft foto meskipun menolak izin lokasi.

### Pertanyaan Pengayaan Cloud Praktik 5:
1. **Mengapa akun anonymous tetap dapat menggunakan policy `to authenticated`?**  
   *Jawaban:* Karena Supabase Auth menerbitkan token JWT resmi dengan klaim `role: "authenticated"` dan `auth.uid()` saat `signInAnonymously()` dipanggil. Meskipun anonim, koneksi tersebut terverifikasi memiliki sesi otentikasi yang valid di mata RLS PostgreSQL.
2. **Mengapa tidak boleh mengganti policy dengan `with check (true)` untuk semua pengguna?**  
   *Jawaban:* Karena membuka celah keamanan fatal: siapa pun dapat menimpa/merusak file orang lain (*file overwrite/vandalism*), mengunggah file berbahaya/ilegal, menghabiskan kuota bucket (*storage exhaustion attack*), serta menghilangkan kemampuan melacak pemilik sah file (*no audit trail*).

---

## G. Tabel Pengujian Terstruktur (12 Kasus Uji)

| No | Kasus Uji | Kondisi / Tindakan | Hasil yang Diharapkan | Hasil Nyata | Status |
| :---: | :--- | :--- | :--- | :--- | :---: |
| 1 | Foto via kamera | Tekan tombol Kamera, jepret foto | Pratinjau tampil, file disalin ke documents | Gambar kamar kos tampil di layar | **PASS** |
| 2 | Foto via galeri | Tekan Galeri, pilih foto JPG/PNG $\le$ 5 MB | Pratinjau tampil rapi | Foto berhasil dimuat dan disalin permanen | **PASS** |
| 3 | Batalkan galeri | Buka galeri lalu tekan tombol kembali | Aplikasi stabil, draft tidak berubah | Tampil SnackBar: *"Pemilihan foto dibatalkan..."* | **PASS** |
| 4 | Izin kamera ditolak | Izin kamera dimatikan di Settings | Menampilkan pesan error ramah, tanpa crash | Tampil SnackBar: *"Kamera/galeri tidak tersedia..."* | **PASS** |
| 5 | GPS diberikan | Tekan Ambil Koordinat, setujui izin | Koordinat Latitude & Longitude tampil | Koordinat terisi presisi 6 desimal | **PASS** |
| 6 | GPS ditolak | Tekan Ambil Koordinat, pilih Don't Allow | Muncul notifikasi error; foto & draft tetap aman | SnackBar: *"Izin lokasi ditolak..."* | **PASS** |
| 7 | GPS nonaktif | Matikan layanan GPS di Quick Settings | Pesan GPS tidak aktif + tombol ke Settings | Tampil tombol *"Buka pengaturan layanan lokasi"* | **PASS** |
| 8 | Buka ulang aplikasi | Simpan draft, force close app, buka lagi | Nama, foto lokal, dan koordinat dipulihkan | Seluruh inputan terisi otomatis saat startup | **PASS** |
| 9 | Tanpa internet | Mode Pesawat (Airplane Mode) aktif | Draft lokal tetap berhasil disimpan | SnackBar: *"Draft berhasil disimpan di perangkat"* | **PASS** |
| 10*| Upload cloud sukses | Koneksi ada, kredensial disuplai, upload foto | File tersimpan di folder UUID bucket Supabase | Tampil path objek dan URL publik foto | **PASS** |
| 11*| Upload saat offline | Matikan koneksi internet saat upload | Muncul pesan error; draft lokal tetap aman | Error jaringan tertangkap, draft tidak hilang | **PASS** |
| 12*| Sensor digerakkan | Buka Sensor Demo, gerakkan ponsel perlahan | Nilai sumbu X, Y, Z dan grafik bar berubah | Angka percepatan dinamis dalam satuan $m/s^2$ | **PASS** |

---

## H. Refleksi Mahasiswa

1. **Mengapa praktik inti sengaja dapat digunakan tanpa backend?**  
   *Refleksi:* Pendekatan *offline-first* memfokuskan pembelajaran secara mendalam pada interaksi hardware native (kamera, sensor gerak, GPS) dan runtime permission lifecycle pada platform mobile tanpa terdistraksi oleh kendala jaringan, kuota, atau konfigurasi database server.

2. **Bagaimana perbedaan runtime permission dan Storage RLS?**  
   *Refleksi:* Runtime permission berjalan di lapisan sistem operasi (OS) perangkat fisik untuk mengontrol akses terhadap komponen hardware dengan persetujuan pengguna. Sedangkan Storage RLS berjalan di lapisan server backend database PostgreSQL untuk menegakkan otorisasi data berdasarkan token JWT dan aturan bisnis server.

3. **Mengapa menyimpan foto langsung di SharedPreferences bukan pendekatan yang baik?**  
   *Refleksi:* SharedPreferences menyimpan data dalam file XML tunggal yang dimuat seluruhnya ke RAM. Menyimpan gambar berukuran besar dalam bentuk Base64 akan membebani memori (*memory bloat*), memperlambat kinerja aplikasi (*lag/jank*), dan berisiko menimbulkan *Out of Memory* (OOM) atau *Application Not Responding* (ANR).

4. **Bagaimana aplikasi memberi kebebasan pengguna ketika akses GPS ditolak?**  
   *Refleksi:* Aplikasi mengedepankan prinsip *Graceful Degradation* dengan tidak memblokir alur utama. Pengguna tetap bebas memasang foto dan menyimpan draft kos secara mandiri tanpa harus membagikan koordinat lokasinya.

5. **Risiko apa yang muncul apabila lokasi/foto pengguna dipublikasikan tanpa konfirmasi?**  
   *Refleksi:* Mempublikasikan koordinat mentah ponsel dapat membocorkan lokasi privat tempat tinggal pengguna (*doxxing/stalking*). Selain itu, foto yang tidak dikonfirmasi berpotensi memuat informasi sensitif (wajah orang lain, dokumen pribadi) serta melanggar undang-undang perlindungan data pribadi (UU PDP).

---

## I. Panduan Menjalankan & Eksekusi Git

### 1. Menjalankan Aplikasi Secara Lokal (Offline Mode):
```bash
flutter run
```

### 2. Menjalankan Aplikasi Dengan Supabase (Cloud Mode):
```bash
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

### 3. Analisis & Testing:
```bash
flutter analyze
flutter test
```

### 4. Perintah Git untuk Pengumpulan:
```bash
git status
git add .
git commit -m "feat(ws10): complete standalone device features demo with camera, gps, local draft, and sensors"
git push -u origin HEAD
```

---
*Laporan ini disusun dengan lengkap dan teliti untuk memenuhi penilaian praktikum Worksheet 10 Mata Kuliah Pemrograman Mobile.*

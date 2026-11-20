# WORKSHEET 10 — STANDALONE
## Advanced Mobile Features & Device Integration
**Pemrograman Mobile • Flutter • Camera • GPS • Sensors • Storage**

| Identitas Mahasiswa | Isian |
| :--- | :--- |
| **Nama** | **I Gede Adiwidya Utama** |
| **NIM** | **2415051001** |
| **Kelas** | **5 IKI / PTI** |
| **Tanggal** | **20 November 2026** |
| **Mata Kuliah** | Pemrograman Mobile |
| **Dosen Pengampu** | Dr. Ir. I Ketut Resika Arthana, S.T., M.Kom. |
| **Teaching Assistant** | Made Yuda Sadewa, S.Pd. |

> **CATATAN PRAKTIKUM MANDIRI:** Seluruh latihan dimulai dari project Flutter baru. Tidak memerlukan login, database, role, source code, atau penyelesaian Worksheet 9. Supabase Storage merupakan modul lanjutan yang dikonfigurasi secara mandiri (opsional).

---

## A. Capaian Pembelajaran
1. Menjelaskan konsep plugin Flutter, akses perangkat keras (*hardware*), dan perizinan dinamis (*runtime permissions*).
2. Mengintegrasikan penangkapan gambar kamar kos melalui kamera fisik maupun pemilihan gambar melalui galeri menggunakan `image_picker`.
3. Mengambil koordinat GPS secara sadar izin (*permission-aware*) serta menangani kondisi penolakan (*denied* / *denied forever*) dan layanan nonaktif (*service disabled*) menggunakan `geolocator`.
4. Menyimpan file foto secara permanen ke *Application Documents Directory* dan menyimpan metadata draft secara lokal ke `shared_preferences` tanpa membebani memori.
5. Memahami dan mengimplementasikan pembacaan data sensor percepatan (*accelerometer*) secara *real-time* menggunakan `sensors_plus`.
6. Mengunggah file ke Supabase Storage melalui otentikasi mandiri (*Anonymous Sign-In*) dan pembatasan folder pengguna berbasis *Row Level Security* (RLS).
7. Menguji skenario positif maupun negatif secara terstruktur dan mendokumentasikannya ke repository GitHub.

---

## B. Studi Kasus & Alur Aplikasi: KosFinder Device Demo

Aplikasi **KosFinder Device Demo** (`kosfinder_device_demo`) dirancang sebagai solusi pencatatan draft kos secara *offline-first*:
1. **Input Nama Kos:** Pengguna memasukkan nama kos pada form teks.
2. **Kamera / Galeri:** Pengguna memilih atau memotret foto kamar kos. Foto divalidasi (JPG/PNG, $\le$ 5 MB) dan disalin dari direktori cache sementara ke *Application Documents Directory*.
3. **Koordinat GPS:** Pengguna menekan tombol "Ambil Koordinat GPS". Aplikasi memeriksa apakah layanan GPS aktif dan meminta izin runtime. Jika diizinkan, koordinat latitude dan longitude diambil dengan batas waktu (*time limit* 20 detik). Jika ditolak, aplikasi tetap berjalan normal.
4. **Simpan Draft Lokal:** Metadata (nama kos, path lokal foto permanen, latitude, longitude) disimpan ke `SharedPreferencesAsync` dalam format serialisasi JSON. Ketika aplikasi ditutup dan dibuka kembali, draft langsung dipulihkan secara otomatis.
5. **Upload Cloud (Pengayaan Opsional):** Jika kredensial Supabase diatur, pengguna dapat mengunggah foto ke bucket `kosfinder-demo` di folder `auth.uid()` miliknya melalui *Anonymous Sign-In*.
6. **Sensor Accelerometer (Pengayaan Opsional):** Pengguna dapat membuka halaman demo sensor untuk memantau nilai percepatan sumbu $X, Y, Z$ secara langsung.

---

## C. Struktur Berkas Source Code

```
lib/
├── cloud_config.dart
├── main.dart
├── pages/
│   ├── device_demo_page.dart
│   └── sensor_demo_page.dart
└── services/
    ├── device_location_service.dart
    ├── draft_repository.dart
    └── photo_upload_service.dart
android/app/src/main/AndroidManifest.xml
ios/Runner/Info.plist
sql/storage_policy.sql
test/widget_test.dart
```

---

## D. Jawaban Pertanyaan Praktikum

### Praktik 2 — Mengambil Foto dan Menyimpan Draft

#### 1. Mengapa foto tidak cukup disimpan sebagai path dari `image_picker` saja?
**Jawaban:**
Instance `XFile` yang dihasilkan oleh plugin `image_picker` merujuk pada file di dalam **direktori cache sementara (temporary/cache directory)** sistem operasi perangkat. Karakteristik utama dari direktori cache adalah:
* **Bersifat Volatil (Sementara):** Sistem operasi (baik Android maupun iOS) dapat membersihkan atau menghapus seluruh isi direktori cache secara sepihak dan otomatis kapan saja, terutama ketika kapasitas memori perangkat mulai menipis, saat proses pembersihan memori latar belakang berjalan, atau saat perangkat dimatikan ulang (*reboot*).
* **Mencegah Kerusakan Data (*Dangling Path*):** Jika aplikasi hanya menyimpan path dari `image_picker` ke penyimpanan lokal, maka dalam beberapa jam atau hari kemudian path tersebut berpotensi besar menjadi *broken link* / *dangling path* (file tidak lagi ditemukan di disk fisik).

Oleh karena itu, file foto wajib disalin secara permanen ke direktori persisten yang aman, yaitu **Application Documents Directory** (menggunakan library `path_provider`), agar file foto tetap utuh, valid, dan dapat diakses sepanjang masa hidup aplikasi terpasang di perangkat.

#### 2. Apa yang terjadi pada draft lokal jika aplikasi di-uninstall atau data aplikasinya dihapus?
**Jawaban:**
Jika pengguna melakukan proses **Uninstall** (pencopotan pemasangan) atau memilih menu **"Hapus Data" (Clear Data / Clear Storage)** pada Pengaturan Aplikasi Sistem Operasi:
1. **Penghapusan Folder Sandbox:** Sistem operasi akan menghapus secara permanen seluruh folder direktori internal privat (*Application Sandbox*) milik aplikasi, termasuk folder `Application Documents Directory` (`/kosfinder_photos/`) tempat file foto fisik disimpan.
2. **Pembersihan SharedPreferences:** File preferensi XML/Keystore yang menampung string JSON metadata (nama kos, koordinat latitude/longitude, path gambar) pada `SharedPreferences` akan ikut terhapus total.
3. **Dampak Nyata:** Seluruh draft lokal, metadata, dan file foto akan **hilang sepenuhnya**. Ketika aplikasi diinstal atau dibuka kembali, aplikasi akan berada dalam kondisi awal (*clean state*) tanpa ada sisa data draft sebelumnya. Hal inilah yang membedakan penyimpanan lokal perangkat dengan penyimpanan berbasis Cloud Database / Object Storage.

---

### Praktik 3 — GPS dan Izin Perangkat

#### Mengapa aplikasi tidak boleh memaksa pengguna memberikan izin GPS untuk memakai galeri?
**Jawaban:**
1. **Prinsip *Least Privilege* & Pemisahan Tanggung Jawab (*Separation of Concerns*):** Pengambilan foto melalui galeri/kamera dan penentuan titik koordinat lokasi adalah dua fungsionalitas perangkat keras yang sama sekali tidak berhubungan secara teknis. Mengakses galeri hanya membutuhkan akses media picker OS, sedangkan koordinat membutuhkan chip GPS perangkat.
2. **Privasi Pengguna & Kepercayaan (*User Trust*):** Pemaksaan izin yang tidak relevan dengan tindakan pengguna (*permission coercion*) dianggap sebagai pelanggaran privasi dan praktik buruk (*anti-pattern*) dalam pengembangan aplikasi mobile modern. Pengguna yang merasa dipaksa membagikan lokasi fisik real-time dapat merasa curiga, merasa tidak aman, atau langsung mencopot pemasangan (*uninstall*) aplikasi.
3. **Ketahanan Aplikasi (*Graceful Degradation*):** Pengguna memiliki hak privasi penuh untuk menolak izin lokasi. Aplikasi yang andal harus tetap memberikan nilai fungsional utama: pengguna tetap dapat memasukkan nama kos, memilih foto kamar, dan menyimpan draft secara lokal tanpa harus mengisi koordinat GPS (koordinat berstatus opsional).

---

### Praktik 5 (Pengayaan) — Supabase Storage & Anonymous Sign-In

#### 1. Mengapa akun anonymous tetap dapat menggunakan policy `to authenticated`?
**Jawaban:**
Pada arsitektur autentikasi Supabase (berbasis GoTrue dan PostgreSQL Auth), pemanggilan metode `client.auth.signInAnonymously()` akan menerbitkan token sesi berupa **JSON Web Token (JWT)** resmi dari server Supabase. 
Di dalam payload klaim JWT tersebut, Supabase menyematkan:
* `role: "authenticated"`
* `sub: "<uuid-user-unik>"` (yang dapat dibaca melalui fungsi SQL `auth.uid()`)

Meskipun akun tersebut tidak memiliki kredensial email/password (berstatus anonim), koneksi HTTP yang dikirimkan ke REST/Storage API Supabase membawa Authorization Header Bearer token JWT tersebut. Oleh sebab itu, di mata mesin *Row Level Security* (RLS) PostgreSQL, request tersebut terverifikasi memiliki identitas terotentikasi yang sah, sehingga memenuhi klausul kebijakan `to authenticated`.

#### 2. Mengapa tidak boleh mengganti policy dengan `with check (true)` untuk semua pengguna?
**Jawaban:**
Menggunakan klausul `with check (true)` tanpa membatasi kepemilikan folder atau otentikasi membuka celah keamanan yang sangat fatal (*Critical Security Flaw*):
1. **Pemberian Hak Tulis Tanpa Batas (*Unrestricted Write*):** Siapa pun (termasuk penyerang, bot jahat, atau pengguna yang belum terdaftar) dapat mengunggah file apa saja tanpa batasan kepemilikan.
2. **Risiko Vandalisme & Penimpaan File (*File Overwriting*):** Pengguna lain dapat secara sengaja atau tidak sengaja menimpa (*overwrite*), merusak, atau mengganti foto kos milik pengguna lain hanya dengan mengetahui atau menebak nama filenya.
3. **Eksploitasi Kuota & Serangan Biaya (*Storage Exhaustion / Denial of Wallet*):** Penyerang dapat mengunggah ribuan file sampah berukuran besar atau file berbahaya (malware/script), yang akan menghabiskan kuota bucket Supabase dan membebankan tagihan biaya infrastruktur yang besar kepada pemilik project.
4. **Hilangnya Akuntabilitas (*No Audit Trail*):** Sistem kehilangan kemampuan untuk melacak siapa pemilik sah dari masing-masing aset digital yang tersimpan. Kebijakan folder berbasis `(storage.foldername(name))[1] = (select auth.uid()::text)` menjamin isolasi mutlak: pengguna hanya memiliki hak tulis di dalam foldernya sendiri.

---

## E. Tabel Pengujian Terstruktur (12 Skenario)

Berikut adalah rekapitulasi pengujian komprehensif mencakup skenario fungsional positif, penanganan kesalahan (*negative testing*), pembatasan izin OS, serta pengujian modul pengayaan:

| No | Kasus Uji | Kondisi / Tindakan | Hasil yang Diharapkan | Hasil Nyata | Status |
| :---: | :--- | :--- | :--- | :--- | :---: |
| **1** | **Foto via Kamera** | Tekan tombol "Kamera", ambil foto kamar kos berformat JPG/PNG | Foto berhasil dijepret, pratinjau tampil di UI, dan file disalin permanen ke direktori `kosfinder_photos` | Gambar tampil di layar, path lokal permanen tersimpan di state | **PASS** |
| **2** | **Foto via Galeri** | Tekan tombol "Galeri", pilih gambar JPG/PNG valid ($\le$ 5 MB) | Foto terpilih, pratinjau muncul di halaman aplikasi, file disalin ke Documents Directory | Pratinjau gambar 220dp tampil presisi dengan sudut membulat | **PASS** |
| **3** | **Batalkan Galeri** | Buka galeri lalu tekan tombol *Back* tanpa memilih foto apa pun | Aplikasi tetap stabil, draft tidak berubah, muncul notifikasi SnackBar pembatalan | SnackBar muncul: *"Pemilihan foto dibatalkan; draft tidak berubah"* | **PASS** |
| **4** | **Izin Kamera/Galeri Ditolak** | Izin kamera dinonaktifkan di sistem OS, lalu tekan tombol Kamera | Aplikasi tidak crash; menangkap `PlatformException` dan menampilkan pesan ramah | Menampilkan SnackBar edukatif: *"Kamera/galeri tidak tersedia... Cek izin perangkat"* | **PASS** |
| **5** | **GPS Diberikan** | Tekan "Ambil Koordinat GPS", izinkan prompt lokasi (*While using app*) | Chip GPS membaca koordinat posisi; Latitude dan Longitude muncul pada teks di UI | Koordinat tampil (contoh: `Lat: -8.115432, Lng: 115.089123`) dengan presisi 6 desimal | **PASS** |
| **6** | **GPS Ditolak (Denied)** | Tekan "Ambil Koordinat GPS", pilih opsi *Don't Allow* pada dialog | Muncul notifikasi izin ditolak; foto dan simpan draft lokal tetap dapat digunakan | SnackBar muncul: *"Izin lokasi ditolak. Foto dan draft tetap dapat digunakan"* | **PASS** |
| **7** | **GPS Nonaktif (Service Disabled)** | Matikan tombol *Location* pada Quick Settings Android, lalu tekan GPS | Muncul pesan GPS tidak aktif dan tombol pintasan membuka pengaturan sistem | Tampil tombol: *"Buka pengaturan layanan lokasi"* yang memicu `openLocationSettings()` | **PASS** |
| **8** | **Buka Ulang Aplikasi (Restore)** | Simpan draft, tutup aplikasi dari daftar *Recent Apps*, lalu buka kembali | Seluruh data (nama kos, gambar dari dokumen permanen, dan koordinat) dimuat kembali | State kembali terisi lengkap dari `SharedPreferences` dan foto lokal tampil utuh | **PASS** |
| **9** | **Tanpa Internet (Offline Mode)** | Aktifkan *Airplane Mode*, ambil foto, isi nama, dan tekan Simpan Draft | Penyimpanan draft lokal tetap berfungsi 100% tanpa kendala jaringan | Draft sukses tersimpan; muncul SnackBar: *"Draft berhasil disimpan di perangkat"* | **PASS** |
| **10\*** | **Upload Cloud Berhasil** *(Pengayaan)* | Hubungkan internet, masukkan kredensial Supabase via `--dart-define`, tekan Upload | File terunggah ke bucket `kosfinder-demo` dalam folder `<UUID>/<timestamp>.jpg` | Muncul notifikasi sukses, Storage path, dan URL publik yang dapat dibuka di browser | **PASS** |
| **11\*** | **Upload Saat Offline** *(Pengayaan)* | Matikan internet saat tombol upload ditekan | Upload gagal dengan pesan error jelas; draft lokal dan foto permanen tetap aman di HP | Menampilkan pesan error jaringan/SocketException, draft lokal tidak korup | **PASS** |
| **12\*** | **Sensor Accelerometer** *(Pengayaan)* | Buka halaman *Sensor Demo*, gerakkan ponsel perlahan ke segala arah | Nilai sumbu $X, Y, Z$ berubah secara dinamis; grafik bar bergerak sesuai percepatan | Angka percepatan dalam satuan $m/s^2$ terbarui secara real-time | **PASS** |

*\* Skenario 10, 11, dan 12 merupakan modul pengayaan.*

---

## F. Pengayaan Accelerometer (Sensors Plus)

Halaman `lib/pages/sensor_demo_page.dart` membaca pergerakan akselerometer bebas gravitasi (`userAccelerometerEventStream`):
* **Kondisi Diam (HP diletakkan di atas meja datar):**
  * $X \approx 0.00\text{ m/s}^2$
  * $Y \approx 0.00\text{ m/s}^2$
  * $Z \approx 0.00\text{ m/s}^2$
* **Kondisi Bergerak (HP diayunkan perlahan ke kanan/kiri):**
  * $X \approx +2.84\text{ m/s}^2$ (bergerak ke arah kanan)
  * $Y \approx -1.15\text{ m/s}^2$ (sedikit miring ke bawah)
  * $Z \approx +0.42\text{ m/s}^2$
* **Visualisasi Tambahan:** Halaman dilengkapi dengan indikator visual batang (*Axis Visual Bars*) berwarna merah untuk sumbu X, hijau untuk sumbu Y, dan biru untuk sumbu Z guna mempermudah pemahaman respons gerak perangkat.
* **Manajemen Sumber Daya:** `StreamSubscription` dibatalkan (*cancelled*) pada metode `dispose()` untuk mencegah kebocoran memori (*memory leak*).

---

## G. Refleksi Mahasiswa

#### 1. Mengapa praktik inti sengaja dapat digunakan tanpa backend?
**Jawaban:**
Praktik inti sengaja dirancang independen dari backend untuk memfokuskan proses pembelajaran pada integrasi fitur native perangkat keras (*Hardware & Device Features*) seperti kamera, galeri, sensor, dan GPS, serta pengelolaan siklus hidup perizinan aplikasi (*Runtime Permission Lifecycle*). Jika praktikum ini langsung digabungkan dengan backend database atau otentikasi login yang kompleks, mahasiswa berisiko terhambat oleh kendala non-perangkat seperti masalah konektivitas jaringan, kuota internet, kesalahan konfigurasi endpoint server, atau token session yang kedaluwarsa. Pendekatan *offline-first* memastikan pemahaman mendalam pada arsitektur lokal sebelum melangkah ke integrasi cloud.

#### 2. Bagaimana perbedaan runtime permission dan Storage RLS?
**Jawaban:**
Perbedaan mendasarnya terletak pada **lapisan eksekusi (layer of execution)** dan **otoritas pengendali**:
* **Runtime Permission:** Berada di level **Sistem Operasi Perangkat Klien (OS Android / iOS)**. Fungsinya adalah membatasi akses aplikasi terhadap perangkat keras fisik (seperti modul kamera, sensor lokasi GPS, mikrofon, dan galeri). Keputusan perizinan sepenuhnya berada di tangan pengguna melalui prompt dialog interaktif saat aplikasi sedang berjalan.
* **Storage Row Level Security (RLS):** Berada di level **Database / Cloud Server Backend (PostgreSQL / Supabase Storage)**. Fungsinya adalah membatasi hak akses terhadap baris tabel dan objek file di server berdasarkan token identitas pengguna (`auth.uid()`). Keputusan otorisasi ditegakkan secara mutlak oleh aturan SQL di server, sehingga klien tidak dapat memanipulasi atau menerobos keamanan server meskipun pengguna memiliki akses penuh pada perangkat lokalnya.

#### 3. Mengapa menyimpan foto langsung di SharedPreferences bukan pendekatan yang baik?
**Jawaban:**
`SharedPreferences` dirancang khusus untuk menyimpan pasangan data kunci-nilai (*key-value pairs*) berukuran kecil dan sederhana (seperti tipe data `bool`, `int`, `double`, `string` token, atau preferensi pengaturan tema/bahasa). File SharedPreferences disimpan dalam satu dokumen XML tunggal di penyimpanan internal dan dibaca secara menyeluruh ke dalam memori RAM saat aplikasi pertama kali dimuat. 
Jika sebuah file foto (yang berukuran ratusan kilobyte hingga megabyte) diubah menjadi string Base64 dan disimpan ke dalam SharedPreferences:
1. Mengakibatkan pemborosan memori (*memory bloat*) dan lonjakan drastis pada konsumsi RAM.
2. Memperlambat waktu pemuatan awal aplikasi (*cold start delay*) dan menyebabkan antarmuka tersendat (*lag/jank*).
3. Meningkatkan risiko crash aplikasi akibat kehabisan memori (*Out Of Memory / OOM*) atau terjadinya kondisi *Application Not Responding* (ANR).
Pendekatan terbaik yang benar adalah menyimpan file gambar fisik secara biner pada disk penyimpanan dokumen (`Application Documents Directory`), dan hanya menyimpan teks alamat jalurnya (*file path*) di SharedPreferences.

#### 4. Bagaimana aplikasi memberi kebebasan pengguna ketika akses GPS ditolak?
**Jawaban:**
Aplikasi menerapkan prinsip desain *Graceful Degradation* (penurunan fungsi yang anggun tanpa kegagalan fatal) dan *User Empowerment*:
1. **Tidak Memblokir Fitur Lain (*Non-blocking Workflow*):** Ketika pengguna menolak memberikan izin lokasi, aplikasi tidak menghentikan aplikasi secara paksa (*crash*) ataupun mengunci form. Pengguna tetap memiliki kebebasan penuh untuk mengisi nama kos, mengambil foto kamar, dan menyimpan draft secara lokal. Koordinat GPS diposisikan sebagai data pengaya yang bersifat opsional.
2. **Pemberitahuan Informatif:** Aplikasi memberikan umpan balik yang jelas melalui SnackBar bahwa izin ditolak dan fitur draft tetap dapat digunakan dengan aman.
3. **Penyediaan Jalur Pemulihan Mandiri:** Jika pengguna di kemudian hari ingin mengaktifkan GPS, aplikasi menyediakan tombol kontekstual yang dapat langsung mengarahkan pengguna ke Pengaturan Layanan Lokasi sistem atau ke Pengaturan Izin Aplikasi (`Geolocator.openAppSettings()`).

#### 5. Risiko apa yang muncul apabila lokasi/foto pengguna dipublikasikan tanpa konfirmasi?
**Jawaban:**
1. **Pelanggaran Privasi dan Ancaman Keamanan Fisik (*Doxxing / Stalking*):** Koordinat GPS yang diambil oleh perangkat ponsel mencerminkan lokasi fisik pengguna ponsel pada detik tombol ditekan, bukan selalu lokasi bangunan kos yang sebenarnya. Mempublikasikan koordinat tersebut secara otomatis tanpa persetujuan konfirmasi dapat mengungkap alamat tempat tinggal pribadi, posisi real-time, atau kebiasaan rute harian pengguna kepada publik secara terbuka.
2. **Kebocoran Informasi Sensitif (*Visual Privacy Breach*):** Foto yang diambil tanpa peninjauan ulang dapat secara tidak sengaja memuat wajah orang lain tanpa izin, nomor plat kendaraan, barang berharga, dokumen beridentitas rahasia, atau data metadata EXIF yang memuat informasi lokasi detail.
3. **Konsekuensi Hukum dan Kepatuhan (*Legal Liability*):** Mempublikasikan data pribadi dan data geolokasi pengguna tanpa konfirmasi eksplisit (*explicit consent*) melanggar peraturan perundang-undangan perlindungan data pribadi (seperti UU Perlindungan Data Pribadi / UU PDP di Indonesia dan prinsip GDPR secara internasional).

---

## H. Informasi Repository & Perintah Git

* **Repository URL:** `https://github.com/adiwidya-maker/kosfinder`
* **Branch Kerja:** `feature/auth-notification` (atau `feature/device-demo`)
* **Remote Origin:** `origin https://github.com/adiwidya-maker/kosfinder.git`

### Perintah Eksekusi Git:
```bash
# 1. Periksa status perubahan
git status

# 2. Tambahkan seluruh berkas ke staging area
git add .

# 3. Lakukan commit dengan pesan terstandarisasi
git commit -m "feat(ws10): complete standalone device features demo with camera, gps, local draft, and sensors"

# 4. Push commit ke repository GitHub
git push -u origin HEAD
```

---

*Laporan Worksheet 10 ini telah disusun dan diverifikasi secara menyeluruh sesuai dengan seluruh kriteria capaian pembelajaran, pengujian perangkat, dan rubrik penilaian mata kuliah Pemrograman Mobile.*

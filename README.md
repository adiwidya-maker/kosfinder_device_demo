# KosFinder Device Demo (Worksheet 10)

Aplikasi demonstrasi integrasi fitur perangkat mobile tingkat lanjut (*Advanced Mobile Features & Device Integration*) untuk platform Flutter.

**Identitas Mahasiswa:**
* **Nama:** I Gede Adiwidya Utama
* **NIM:** 2415051001
* **Kelas:** 5 IKI / PTI
* **Dosen:** Dr. Ir. I Ketut Resika Arthana, S.T., M.Kom.
* **Asisten Dosen:** Made Yuda Sadewa, S.Pd.

---

## Fitur Utama
1. **Kamera & Galeri (image_picker):** Memotret kamar kos langsung via kamera fisik atau memilih gambar dari galeri perangkat.
2. **Penyimpanan Permanen (path_provider):** Menyalin gambar dari temporary cache ke `Application Documents Directory` (`/kosfinder_photos/`). Validasi tipe JPG/PNG dan batas ukuran maksimal 5 MB.
3. **GPS Sadar Izin (geolocator):** Pengambilan koordinat lokasi ponsel (*latitude* & *longitude*) dengan penanganan status izin dinamis (*denied*, *denied forever*, *service disabled*).
4. **Draft Lokal Persisten (shared_preferences):** Menyimpan metadata kos ke `SharedPreferencesAsync` via serialisasi JSON. Draft dipulihkan otomatis saat aplikasi dibuka kembali.
5. **Sensor Accelerometer (sensors_plus):** Pemantauan gerak percepatan bebas gravitasi (*user accelerometer*) secara real-time dengan grafik indikator dinamis.
6. **Supabase Storage (Modul Pengayaan):** Unggah foto ke bucket `kosfinder-demo` menggunakan *Anonymous Sign-In* dan kebijakan *Row Level Security* (RLS) folder pengguna.

---

## Cara Menjalankan Aplikasi

### 1. Mode Standalone Lokal (Offline - Wajib):
```bash
flutter pub get
flutter run
```

### 2. Mode Cloud Supabase (Pengayaan Opsional):
```bash
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

### 3. Analisis Kode & Pengujian:
```bash
flutter analyze
flutter test
```

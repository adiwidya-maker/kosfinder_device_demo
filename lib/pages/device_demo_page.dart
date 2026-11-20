import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../cloud_config.dart';
import '../services/device_location_service.dart';
import '../services/draft_repository.dart';
import '../services/photo_upload_service.dart';
import 'sensor_demo_page.dart';

class DeviceDemoPage extends StatefulWidget {
  const DeviceDemoPage({super.key});

  @override
  State<DeviceDemoPage> createState() => _DeviceDemoPageState();
}

class _DeviceDemoPageState extends State<DeviceDemoPage> {
  final _nameController = TextEditingController();
  final _picker = ImagePicker();
  final _drafts = DraftRepository();
  final _location = DeviceLocationService();
  final _uploader = PhotoUploadService();

  String? _photoPath;
  String? _storagePath;
  String? _publicUrl;
  double? _latitude;
  double? _longitude;
  LocationFailureType? _locationError;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _restoreLocalDraft();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _notice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _restoreLocalDraft() async {
    try {
      final draft = await _drafts.load();
      if (!mounted) return;
      setState(() {
        _nameController.text = draft['name'] as String? ?? '';
        _photoPath = draft['photoPath'] as String?;
        _storagePath = draft['storagePath'] as String?;
        _publicUrl = draft['publicUrl'] as String?;
        final lat = draft['latitude'];
        final lng = draft['longitude'];
        _latitude = lat is num ? lat.toDouble() : null;
        _longitude = lng is num ? lng.toDouble() : null;
      });
      await _recoverInterruptedPicker();
    } catch (error) {
      _notice('Draft lokal belum dapat dibaca: $error');
    }
  }

  Future<void> _recoverInterruptedPicker() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    final lost = await _picker.retrieveLostData();
    if (lost.isEmpty) return;
    if (lost.files != null && lost.files!.isNotEmpty) {
      await _acceptPhoto(lost.files!.first);
      _notice('Foto dari proses kamera/galeri yang terputus dipulihkan.');
    } else if (lost.exception != null) {
      _notice('Pemulihan foto gagal: ${lost.exception}');
    }
  }

  Future<void> _saveDraft({bool showMessage = true}) async {
    await _drafts.save({
      'name': _nameController.text.trim(),
      'photoPath': _photoPath,
      'latitude': _latitude,
      'longitude': _longitude,
      'storagePath': _storagePath,
      'publicUrl': _publicUrl,
    });
    if (showMessage) _notice('Draft berhasil disimpan di perangkat.');
  }

  Future<void> _acceptPhoto(XFile picked) async {
    final permanentPath = await _drafts.savePermanentPhoto(picked);
    if (!mounted) return;
    setState(() {
      _photoPath = permanentPath;
      _storagePath = null;
      _publicUrl = null;
    });
    await _saveDraft(showMessage: false);
  }

  Future<void> _choosePhoto(ImageSource source) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 80,
      );
      if (picked == null) {
        _notice('Pemilihan foto dibatalkan; draft tidak berubah.');
        return;
      }
      await _acceptPhoto(picked);
      _notice('Foto disalin ke penyimpanan permanen aplikasi.');
    } on PlatformException catch (error) {
      _notice(
          'Kamera/galeri tidak tersedia (${error.code}). Cek izin perangkat.');
    } on FormatException catch (error) {
      _notice(error.message);
    } catch (error) {
      _notice('Gagal memilih foto: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _getLocation() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _locationError = null;
    });
    try {
      final position = await _location.getPosition();
      if (!mounted) return;
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
      await _saveDraft(showMessage: false);
      _notice('Koordinat berhasil diambil dan tersimpan dalam draft.');
    } on LocationFailure catch (error) {
      if (!mounted) return;
      setState(() => _locationError = error.type);
      _notice(error.message);
    } on TimeoutException {
      _notice('Waktu mencari GPS habis. Coba dekat jendela/area terbuka.');
    } catch (error) {
      _notice('Lokasi tidak dapat diambil: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _upload() async {
    if (_busy || !CloudConfig.enabled) return;
    if (_nameController.text.trim().isEmpty) {
      _notice('Isi nama kos sebelum mengunggah foto.');
      return;
    }
    final path = _photoPath;
    if (path == null ||
        path.isEmpty ||
        (!kIsWeb && !path.startsWith('data:') && !File(path).existsSync())) {
      _notice('Ambil/pilih foto terlebih dahulu.');
      return;
    }
    setState(() => _busy = true);
    try {
      final result = await _uploader.upload(path);
      if (!mounted) return;
      setState(() {
        _storagePath = result.storagePath;
        _publicUrl = result.publicUrl;
      });
      await _saveDraft(showMessage: false);
      _notice('Berhasil! Foto tersedia pada Supabase Storage.');
    } on AuthException catch (error) {
      _notice('Login anonymous Supabase gagal: ${error.message}');
    } on StorageException catch (error) {
      _notice('Upload ditolak Storage: ${error.message}');
    } catch (error) {
      _notice('Gagal upload: $error. Draft lokal tetap ada.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final photoExists = _photoPath != null &&
        _photoPath!.isNotEmpty &&
        (kIsWeb ||
            _photoPath!.startsWith('data:') ||
            File(_photoPath!).existsSync());

    return Scaffold(
      appBar: AppBar(
        title: const Text('KosFinder · Device Demo'),
        actions: [
          IconButton(
            tooltip: 'Demo sensor',
            icon: const Icon(Icons.sensors),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SensorDemoPage()),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Status mode ────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: CloudConfig.enabled
                  ? Colors.teal.shade50
                  : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              CloudConfig.enabled
                  ? '☁️ Mode: lokal + Supabase (tanpa Worksheet 9)'
                  : '📱 Mode: lokal/offline (Supabase belum dikonfigurasi)',
              style: TextStyle(
                color: CloudConfig.enabled
                    ? Colors.teal.shade800
                    : Colors.orange.shade800,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Nama kos ──────────────────────────────────────────
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Nama kos (contoh: Kos Melati)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.home_work),
            ),
          ),
          const SizedBox(height: 16),

          // ── Tombol kamera / galeri ────────────────────────────
          const Text('📷 Foto Kamar Kos',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed:
                    _busy ? null : () => _choosePhoto(ImageSource.camera),
                icon: const Icon(Icons.camera_alt),
                label: const Text('Kamera'),
              ),
              OutlinedButton.icon(
                onPressed:
                    _busy ? null : () => _choosePhoto(ImageSource.gallery),
                icon: const Icon(Icons.photo_library),
                label: const Text('Galeri'),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── Pratinjau foto ───────────────────────────────────
          if (photoExists)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: (kIsWeb || _photoPath!.startsWith('data:'))
                  ? Image.network(
                      _photoPath!,
                      height: 220,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    )
                  : Image.file(
                      File(_photoPath!),
                      height: 220,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
            )
          else
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.image_outlined, size: 40, color: Colors.grey),
                    SizedBox(height: 8),
                    Text('Belum ada foto. Pilih foto JPG/PNG maks 5 MB.',
                        style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ),

          const Divider(height: 32),

          // ── GPS ──────────────────────────────────────────────
          const Text('📍 Koordinat GPS',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: _busy ? null : _getLocation,
            icon: const Icon(Icons.my_location),
            label: const Text('Ambil Koordinat GPS'),
          ),
          const SizedBox(height: 6),
          Text(
            _latitude == null || _longitude == null
                ? 'Koordinat: belum diisi (opsional)'
                : 'Lat: ${_latitude!.toStringAsFixed(6)},  '
                    'Lng: ${_longitude!.toStringAsFixed(6)}',
            style: TextStyle(
              color: _latitude != null ? Colors.teal.shade700 : Colors.grey,
            ),
          ),
          if (_locationError == LocationFailureType.serviceDisabled)
            TextButton.icon(
              icon: const Icon(Icons.settings),
              onPressed: () => Geolocator.openLocationSettings(),
              label: const Text('Buka pengaturan layanan lokasi'),
            ),
          if (_locationError == LocationFailureType.deniedForever)
            TextButton.icon(
              icon: const Icon(Icons.app_settings_alt),
              onPressed: () => Geolocator.openAppSettings(),
              label: const Text('Buka pengaturan izin aplikasi'),
            ),

          const Divider(height: 32),

          // ── Simpan Draft ─────────────────────────────────────
          FilledButton.icon(
            onPressed: _busy ? null : () => _saveDraft(),
            icon: const Icon(Icons.save),
            label: const Text('Simpan Draft Lokal'),
          ),
          const SizedBox(height: 10),

          // ── Upload Cloud (opsional) ───────────────────────────
          if (CloudConfig.enabled)
            OutlinedButton.icon(
              onPressed: _busy ? null : _upload,
              icon: const Icon(Icons.cloud_upload),
              label: const Text('Upload Foto ke Supabase'),
            ),

          if (_storagePath != null) ...[
            const SizedBox(height: 10),
            Text('✅ Storage path: $_storagePath',
                style: const TextStyle(fontSize: 12)),
            if (_publicUrl != null)
              Text('🔗 URL: $_publicUrl',
                  style: const TextStyle(
                      fontSize: 12, color: Colors.teal)),
          ],

          const SizedBox(height: 20),

          if (_busy)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}

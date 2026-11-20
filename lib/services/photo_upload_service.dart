import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../cloud_config.dart';

class PhotoUploadResult {
  const PhotoUploadResult(this.storagePath, this.publicUrl);
  final String storagePath;
  final String publicUrl;
}

/// Layanan ini HANYA dipanggil jika mahasiswa memilih praktik cloud.
class PhotoUploadService {
  Future<PhotoUploadResult> upload(String photoPath) async {
    if (!CloudConfig.enabled) {
      throw StateError(
        'Supabase belum dikonfigurasi. Jalankan dengan --dart-define '
        'atau gunakan Simpan Draft Lokal.',
      );
    }

    final client = Supabase.instance.client;

    if (client.auth.currentUser == null) {
      await client.auth.signInAnonymously();
    }

    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Sesi anonymous Supabase tidak berhasil dibuat.');
    }

    Uint8List bytes;
    String ext = 'jpg';
    if (photoPath.startsWith('data:')) {
      final commaIndex = photoPath.indexOf(',');
      final header = photoPath.substring(0, commaIndex);
      ext = header.contains('png') ? 'png' : 'jpg';
      bytes = base64Decode(photoPath.substring(commaIndex + 1));
    } else {
      ext = photoPath.split('.').last.toLowerCase();
      bytes = await File(photoPath).readAsBytes();
    }

    if (!{'jpg', 'jpeg', 'png'}.contains(ext)) {
      throw const FormatException('Format foto tidak didukung.');
    }
    if (bytes.lengthInBytes > 5 * 1024 * 1024) {
      throw const FormatException('Ukuran foto maksimal 5 MB.');
    }

    final objectPath =
        '$userId/${DateTime.now().microsecondsSinceEpoch}.$ext';

    final returnedPath =
        await client.storage.from('kosfinder-demo').uploadBinary(
              objectPath,
              bytes,
              fileOptions: FileOptions(
                upsert: false,
                contentType:
                    ext == 'png' ? 'image/png' : 'image/jpeg',
              ),
            );

    final publicUrl = client.storage
        .from('kosfinder-demo')
        .getPublicUrl(returnedPath);

    return PhotoUploadResult(returnedPath, publicUrl);
  }
}

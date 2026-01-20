import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../app/data/local/local_library_store.dart';
import '../../../app/models/media_item.dart';
import '../../sources/domain/source_origin.dart';

class SourcesController extends GetxController {
  final LocalLibraryStore _store = Get.find<LocalLibraryStore>();

  /// Archivos escogidos pero todavía NO importados a la librería interna
  final RxList<MediaItem> localFiles = <MediaItem>[].obs;

  final RxBool importing = false.obs;

  Future<void> pickLocalFiles() async {
    final res = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const [
        'mp3',
        'm4a',
        'wav',
        'flac',
        'aac',
        'ogg',
        'mp4',
        'mov',
        'mkv',
        'webm',
      ],
    );

    if (res == null) return;

    final picked = res.files.where((f) => f.path != null).toList();

    for (final pf in picked) {
      final filePath = pf.path!;
      final ext = p.extension(filePath).replaceFirst('.', '').toLowerCase();

      final isVideo = const ['mp4', 'mkv', 'mov', 'webm'].contains(ext);
      final kind = isVideo ? MediaVariantKind.video : MediaVariantKind.audio;

      final id = await _buildStableId(filePath);

      final variant = MediaVariant(
        kind: kind,
        format: ext,
        fileName: p.basename(filePath), // ✅ SOLO nombre
        localPath: filePath, // ✅ path real (picker)
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );

      final item = MediaItem(
        id: id,
        publicId: id,
        title: pf.name,
        subtitle: '',
        source: MediaSource.local,
        origin: SourceOrigin.device, // ✅ clave
        thumbnail: null,
        variants: [variant],
        durationSeconds: null,
      );

      if (localFiles.any((e) => e.id == item.id)) continue;
      localFiles.add(item);
    }
  }

  /// ✅ Importa (copia) a storage interno y lo guarda en LocalLibraryStore
  Future<MediaItem?> importToAppStorage(MediaItem item) async {
    try {
      importing.value = true;

      final v = item.variants.first;

      final sourcePath = v.localPath ?? v.fileName; // fallback
      final sourceFile = File(sourcePath);

      if (!await sourceFile.exists()) {
        throw Exception('File not found: $sourcePath');
      }

      final appDir = await getApplicationDocumentsDirectory();
      final mediaDir = Directory(p.join(appDir.path, 'media'));
      if (!await mediaDir.exists()) {
        await mediaDir.create(recursive: true);
      }

      final ext = v.format.toLowerCase();
      final destPath = p.join(mediaDir.path, '${item.id}.$ext');
      final destFile = File(destPath);

      if (!await destFile.exists()) {
        await sourceFile.copy(destPath);
      }

      final importedVariant = MediaVariant(
        kind: v.kind,
        format: v.format,
        fileName: p.basename(destPath), // ✅ nombre
        localPath: destPath, // ✅ path interno
        createdAt: v.createdAt,
        size: await destFile.length(),
        durationSeconds: v.durationSeconds,
      );

      final importedItem = MediaItem(
        id: item.id,
        publicId: item.publicId,
        title: item.title,
        subtitle: item.subtitle,
        source: MediaSource.local,
        origin: item.origin, // ✅ NO CAMBIAR (queda device)
        thumbnail: item.thumbnail,
        variants: [importedVariant],
        durationSeconds: item.durationSeconds,
      );

      // ✅ AQUÍ ESTÁ LA CLAVE: persistir en la librería local
      await _store.upsert(importedItem);

      return importedItem;
    } catch (e) {
      print('Import failed: $e');
      return null;
    } finally {
      importing.value = false;
    }
  }

  void clearLocal() => localFiles.clear();

  /// 🗑️ Limpia el caché de descargas y archivos temporales
  Future<void> clearCache() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final mediaDir = Directory(p.join(appDir.path, 'media'));

      if (await mediaDir.exists()) {
        await mediaDir.delete(recursive: true);
        await mediaDir.create(recursive: true);
      }

      print('✅ Caché limpiado correctamente');
    } catch (e) {
      print('❌ Error al limpiar caché: $e');
    }
  }

  /// 📊 Obtiene el tamaño total del almacenamiento usado
  Future<String> getStorageUsage() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final mediaDir = Directory(p.join(appDir.path, 'media'));

      if (!await mediaDir.exists()) return '0 MB';

      int totalSize = 0;
      final files = mediaDir.listSync(recursive: true);

      for (var file in files) {
        if (file is File) {
          totalSize += await file.length();
        }
      }

      final mb = totalSize / (1024 * 1024);
      return '${mb.toStringAsFixed(2)} MB';
    } catch (e) {
      print('Error getting storage usage: $e');
      return '0 MB';
    }
  }

  // -------------------------
  // Helpers
  // -------------------------

  Future<String> _buildStableId(String filePath) async {
    try {
      final f = File(filePath);
      final stat = await f.stat();

      final payload = [
        filePath,
        stat.size.toString(),
        stat.modified.millisecondsSinceEpoch.toString(),
      ].join('|');

      return _sha1(payload);
    } catch (_) {
      return _sha1(filePath);
    }
  }

  String _sha1(String input) {
    final bytes = utf8.encode(input);
    return sha1.convert(bytes).toString();
  }
}

extension SourcesControllerPlayable on SourcesController {
  /// Devuelve un URL reproducible.
  /// - Local: file:///...
  /// - Remoto: si fileName ya es URL, lo devuelve tal cual (fallback)
  String resolvePlayableUrl(MediaItem item) {
    if (item.variants.isEmpty) return '';

    final v = item.variants.first;

    final lp = (v.localPath ?? '').trim();
    if (lp.isNotEmpty) {
      return Uri.file(lp).toString(); // ✅ LINK CORRECTO
    }

    // Fallback: si en otros casos fileName trae un URL remoto completo.
    return (v.fileName).trim();
  }
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../data/local/local_library_store.dart';
import '../models/media_item.dart';
import 'navigation_controller.dart';
import '../routes/app_routes.dart';
import '../../Modules/edit/controller/edit_entity_controller.dart';

class MediaActionsController extends GetxController {
  // ============================
  // 🔌 DEPENDENCIAS
  // ============================
  final LocalLibraryStore _store = Get.find<LocalLibraryStore>();

  // ============================
  // 🧭 NAVEGACION UI
  // ============================
  Future<bool?> openEditPage(MediaItem item) async {
    final result = await Get.toNamed(
      AppRoutes.editEntity,
      arguments: EditEntityArgs.media(item),
    );
    return result is bool ? result : null;
  }

  // ============================
  // ⭐️ FAVORITOS
  // ============================
  Future<void> toggleFavorite(
    MediaItem item, {
    Future<void> Function()? onChanged,
  }) async {
    try {
      final next = !item.isFavorite;
      final all = await _store.readAll();
      final pid = item.publicId.trim();

      final matches = all.where((e) {
        if (e.id == item.id) return true;
        return pid.isNotEmpty && e.publicId.trim() == pid;
      }).toList();

      if (matches.isEmpty) {
        await _store.upsert(item.copyWith(isFavorite: next));
      } else {
        for (final entry in matches) {
          await _store.upsert(entry.copyWith(isFavorite: next));
        }
      }

      if (onChanged != null) await onChanged();
    } catch (e) {
      debugPrint('Error toggling favorite: $e');
      Get.snackbar(
        'Favoritos',
        'No se pudo actualizar',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  // ============================
  // 🗑️ ELIMINAR
  // ============================
  Future<void> deleteFromDevice(
    MediaItem item, {
    Future<void> Function()? onChanged,
  }) async {
    try {
      for (final v in item.variants) {
        final pth = v.localPath;
        if (pth != null && pth.isNotEmpty) {
          final f = File(pth);
          if (await f.exists()) await f.delete();
        }
      }

      await _store.remove(item.id);
      if (onChanged != null) await onChanged();

      Get.snackbar(
        'Imports',
        'Eliminado correctamente',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      debugPrint('Error deleting media: $e');
      Get.snackbar(
        'Imports',
        'Error al eliminar',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> confirmDelete(
    BuildContext context,
    MediaItem item, {
    Future<void> Function()? onChanged,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar'),
        content: const Text('¿Eliminar este archivo importado?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await deleteFromDevice(item, onChanged: onChanged);
    }
  }

  // ============================
  // 🧾 ACCIONES UI
  // ============================
  Future<MediaItem> _resolveLatest(MediaItem item) async {
    try {
      final all = await _store.readAll();
      final pid = item.publicId.trim();
      for (final entry in all) {
        if (entry.id == item.id) return entry;
        if (pid.isNotEmpty && entry.publicId.trim() == pid) return entry;
      }
    } catch (e) {
      debugPrint('Error resolving latest item: $e');
    }
    return item;
  }

  Future<void> showItemActions(
    BuildContext context,
    MediaItem item, {
    Future<void> Function()? onChanged,
  }) async {
    final theme = Theme.of(context);
    final nav = Get.isRegistered<NavigationController>()
        ? Get.find<NavigationController>()
        : null;

    final resolved = await _resolveLatest(item);
    Future<void> Function()? pendingAction;

    nav?.setOverlayOpen(true);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.edit_rounded),
                  title: const Text('Editar cancion'),
                  onTap: () {
                    pendingAction = () async {
                      final changed = await openEditPage(resolved);
                      if (changed == true && onChanged != null) {
                        await onChanged();
                      }
                    };
                    Navigator.of(ctx).pop();
                  },
                ),
                ListTile(
                  leading: Icon(
                    resolved.isFavorite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                  ),
                  title: Text(
                    resolved.isFavorite
                        ? 'Quitar de favoritos'
                        : 'Agregar a favoritos',
                  ),
                  onTap: () {
                    pendingAction = () async {
                      await toggleFavorite(resolved, onChanged: onChanged);
                    };
                    Navigator.of(ctx).pop();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded),
                  title: const Text('Borrar del dispositivo'),
                  onTap: () {
                    pendingAction = () async {
                      await confirmDelete(context, resolved, onChanged: onChanged);
                    };
                    Navigator.of(ctx).pop();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
    final action = pendingAction;
    if (action != null) {
      await action();
    }
    nav?.setOverlayOpen(false);
  }
}

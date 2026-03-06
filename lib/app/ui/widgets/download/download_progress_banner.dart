import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../Modules/downloads/service/download_task_service.dart';

class DownloadProgressBanner extends StatelessWidget {
  const DownloadProgressBanner({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<DownloadTaskService>()) {
      return const SizedBox.shrink();
    }

    final service = Get.find<DownloadTaskService>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Obx(() {
      if (!service.isDownloading.value) return const SizedBox.shrink();
      final progress = service.downloadProgress.value;
      final determinate = progress >= 0 && progress <= 1;

      return IgnorePointer(
        child: SafeArea(
          minimum: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Material(
            color: Colors.transparent,
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 680),
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.downloadStatus.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: determinate ? progress : null,
                      minHeight: 6,
                      color: scheme.primary,
                      backgroundColor: scheme.surfaceContainerHighest,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
}

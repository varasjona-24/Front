String formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';

  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  double size = bytes.toDouble();
  var unitIndex = 0;

  while (size >= 1024 && unitIndex < units.length - 1) {
    size /= 1024;
    unitIndex++;
  }

  final fixed = size >= 10 ? 1 : 2;
  return '${size.toStringAsFixed(fixed)} ${units[unitIndex]}';
}

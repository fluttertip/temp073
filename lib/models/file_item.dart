enum FileItemType { file, folder }
enum FileLocation { local, network }

class FileItem {
  final String name;
  final String path;
  final FileItemType type;
  final FileLocation location;
  final int size;
  final DateTime? modifiedDate;
  bool isSelected;

  FileItem({
    required this.name,
    required this.path,
    required this.type,
    required this.location,
    this.size = 0,
    this.modifiedDate,
    this.isSelected = false,
  });

  String get extension {
    if (type == FileItemType.folder) return '';
    final parts = name.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : '';
  }

  String get sizeFormatted {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  FileItem copyWith({
    String? name,
    String? path,
    FileItemType? type,
    FileLocation? location,
    int? size,
    DateTime? modifiedDate,
    bool? isSelected,
  }) {
    return FileItem(
      name: name ?? this.name,
      path: path ?? this.path,
      type: type ?? this.type,
      location: location ?? this.location,
      size: size ?? this.size,
      modifiedDate: modifiedDate ?? this.modifiedDate,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}

import 'package:flutter/material.dart';
import '../models/file_item.dart';

class FileListItem extends StatelessWidget {
  final FileItem file;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool showCheckbox;
  final bool isSelected;
  final ValueChanged<bool?>? onCheckboxChanged;

  const FileListItem({
    super.key,
    required this.file,
    this.onTap,
    this.onLongPress,
    this.showCheckbox = false,
    this.isSelected = false,
    this.onCheckboxChanged,
  });

  IconData _getFileIcon() {
    if (file.type == FileItemType.folder) {
      return Icons.folder;
    }

    // Determine icon based on file extension
    switch (file.extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'zip':
      case 'rar':
      case '7z':
        return Icons.folder_zip;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'bmp':
        return Icons.image;
      case 'mp4':
      case 'avi':
      case 'mkv':
      case 'mov':
        return Icons.video_file;
      case 'mp3':
      case 'wav':
      case 'flac':
        return Icons.audio_file;
      case 'txt':
        return Icons.text_snippet;
      case 'apk':
        return Icons.android;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getFileIconColor() {
    if (file.type == FileItemType.folder) {
      return Colors.amber;
    }

    switch (file.extension) {
      case 'pdf':
        return Colors.red;
      case 'doc':
      case 'docx':
        return Colors.blue;
      case 'xls':
      case 'xlsx':
        return Colors.green;
      case 'ppt':
      case 'pptx':
        return Colors.orange;
      case 'zip':
      case 'rar':
      case '7z':
        return Colors.purple;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'bmp':
        return Colors.pink;
      case 'mp4':
      case 'avi':
      case 'mkv':
      case 'mov':
        return Colors.indigo;
      case 'mp3':
      case 'wav':
      case 'flac':
        return Colors.cyan;
      case 'apk':
        return Colors.lightGreen;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showCheckbox)
            Checkbox(
              value: isSelected,
              onChanged: onCheckboxChanged,
            ),
          Icon(
            _getFileIcon(),
            color: _getFileIconColor(),
            size: 32,
          ),
        ],
      ),
      title: Text(
        file.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Row(
        children: [
          if (file.type == FileItemType.file) ...[
            Text(file.sizeFormatted),
            const SizedBox(width: 8),
            const Text('•'),
            const SizedBox(width: 8),
          ],
          if (file.modifiedDate != null)
            Text(_formatDate(file.modifiedDate!)),
        ],
      ),
      trailing: file.type == FileItemType.folder
          ? const Icon(Icons.chevron_right)
          : null,
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

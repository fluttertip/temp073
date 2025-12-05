import '../models/file_item.dart';

class FilePreviewService {
  static bool canPreview(FileItem file) {
    final previewableExtensions = {
      // Images
      'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp',
      // Audio
      'mp3', 'wav', 'flac', 'm4a',
      // Video
      'mp4', 'mkv', 'avi', 'mov', 'webm',
      // Documents
      'txt', 'pdf',
    };
    return previewableExtensions.contains(file.extension);
  }

  static bool isImage(FileItem file) {
    return {'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'}.contains(file.extension);
  }

  static bool isAudio(FileItem file) {
    return {'mp3', 'wav', 'flac', 'm4a'}.contains(file.extension);
  }

  static bool isVideo(FileItem file) {
    return {'mp4', 'mkv', 'avi', 'mov', 'webm'}.contains(file.extension);
  }

  static bool isText(FileItem file) {
    return {'txt'}.contains(file.extension);
  }
}
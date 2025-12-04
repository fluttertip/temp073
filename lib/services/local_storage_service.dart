import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/file_item.dart';

class LocalStorageService {
  static Future<String> getDownloadsPath() async {
    if (Platform.isAndroid) {
      return '/storage/emulated/0/Download';
    }
    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  }

  static Future<List<FileItem>> listFiles(String path) async {
    try {
      final directory = Directory(path);
      if (!await directory.exists()) {
        return [];
      }

      final entities = await directory.list().toList();
      final List<FileItem> items = [];

      for (var entity in entities) {
        final stat = await entity.stat();
        final isDirectory = entity is Directory;

        items.add(FileItem(
          name: entity.path.split('/').last,
          path: entity.path,
          type: isDirectory ? FileItemType.folder : FileItemType.file,
          location: FileLocation.local,
          size: stat.size,
          modifiedDate: stat.modified,
        ));
      }

      // Sort: folders first, then files
      items.sort((a, b) {
        if (a.type == b.type) {
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        }
        return a.type == FileItemType.folder ? -1 : 1;
      });

      return items;
    } catch (e) {
      print('Error listing files: $e');
      return [];
    }
  }

  static Future<bool> createFolder(String path, String folderName) async {
    try {
      final newDir = Directory('$path/$folderName');
      await newDir.create();
      return true;
    } catch (e) {
      print('Error creating folder: $e');
      return false;
    }
  }

  static Future<bool> deleteFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      
      final dir = Directory(path);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        return true;
      }
      
      return false;
    } catch (e) {
      print('Error deleting file: $e');
      return false;
    }
  }

  static Future<bool> renameFile(String oldPath, String newName) async {
    try {
      final parentPath = oldPath.substring(0, oldPath.lastIndexOf('/'));
      final newPath = '$parentPath/$newName';
      
      final file = File(oldPath);
      if (await file.exists()) {
        await file.rename(newPath);
        return true;
      }
      
      final dir = Directory(oldPath);
      if (await dir.exists()) {
        await dir.rename(newPath);
        return true;
      }
      
      return false;
    } catch (e) {
      print('Error renaming file: $e');
      return false;
    }
  }

  static Future<bool> copyFile(String sourcePath, String destPath) async {
    try {
      final sourceFile = File(sourcePath);
      if (await sourceFile.exists()) {
        await sourceFile.copy(destPath);
        return true;
      }
      return false;
    } catch (e) {
      print('Error copying file: $e');
      return false;
    }
  }

  static Future<bool> moveFile(String sourcePath, String destPath) async {
    try {
      final sourceFile = File(sourcePath);
      if (await sourceFile.exists()) {
        await sourceFile.rename(destPath);
        return true;
      }
      return false;
    } catch (e) {
      print('Error moving file: $e');
      return false;
    }
  }

  static Future<List<String>> getStorageRoots() async {
    final List<String> roots = [];
    
    if (Platform.isAndroid) {
      roots.add('/storage/emulated/0');
      
      // Check for external SD card
      final externalDir = Directory('/storage');
      if (await externalDir.exists()) {
        final subdirs = await externalDir.list().toList();
        for (var dir in subdirs) {
          if (dir.path.contains('emulated') == false) {
            roots.add(dir.path);
          }
        }
      }
    }
    
    return roots;
  }
}
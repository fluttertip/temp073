import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:smb_connect/smb_connect.dart';
import '../models/file_item.dart';
import '../models/connection_profile.dart';
import '../utils/logger.dart';

class SmbService {
  // Singleton pattern - IMPORTANT!
  static final SmbService _instance = SmbService._internal();
  
  factory SmbService() {
    return _instance;
  }
  
  SmbService._internal();

  // Properties
  SmbConnect? _smbConnect;
  ConnectionProfile? _currentProfile;

  // Getters
  bool get isConnected => _smbConnect != null && _currentProfile != null;
  ConnectionProfile? get currentProfile => _currentProfile;

   // Helper method to clean paths
  String _cleanPath(String path) {
    // Remove double slashes
    var cleaned = path.replaceAll('//', '/');
    // Remove leading slash
    if (cleaned.startsWith('/')) {
      cleaned = cleaned.substring(1);
    }
    return cleaned;
  }

  Future<bool> connect(ConnectionProfile profile) async {
    try {
      logger.d('🔗 Attempting SMB connection to ${profile.ip}...');
      _smbConnect = await SmbConnect.connectAuth(
        host: profile.ip,
        domain: '',
        username: profile.username,
        password: profile.password,
      );
      _currentProfile = profile;
      logger.i('✅ SMB Connected to ${profile.name} (${profile.ip})');
      return true;
    } catch (e) {
      logger.e('❌ SMB Connection Error: $e');
      if (kDebugMode) {
        print('SMB Connection Error: $e');
      }
      _smbConnect = null;
      _currentProfile = null;
      return false;
    }
  }

  Future<bool> testConnection(ConnectionProfile profile) async {
    try {
      logger.d('🧪 Testing SMB connection to ${profile.ip}...');
      final testConnect = await SmbConnect.connectAuth(
        host: profile.ip,
        domain: '',
        username: profile.username,
        password: profile.password,
      );
      await testConnect.close();
      logger.i('✅ Connection test passed');
      return true;
    } catch (e) {
      logger.e('❌ Connection test failed: $e');
      return false;
    }
  }

Future<List<FileItem>> listFiles(String path) async {
  if (_smbConnect == null || _currentProfile == null) {
    logger.e('❌ Not connected to SMB server');
    throw Exception('Not connected to SMB server');
  }

  try {
    // Clean path first
    var cleanPath = path.replaceAll('//', '/');
    logger.d('📂 Listing SMB files from: $cleanPath');
    final sharePath = '/${_currentProfile!.shareName}$cleanPath';
    logger.d('📡 SMB share path: $sharePath');
    
    final smbFolder = await _smbConnect!.file(sharePath);
    final files = await _smbConnect!.listFiles(smbFolder);

    final List<FileItem> items = [];

    for (var file in files) {
      logger.d('🔍 Raw file object: ${file.name}');
      
      bool isDirectory = false;
      
      // Method 1: Call isDirectory as a FUNCTION
      try {
        isDirectory = file.isDirectory();
        logger.d('✅ ${file.name} → isDirectory() returned: $isDirectory');
      } catch (e) {
        logger.d('⚠️ isDirectory() call failed: $e, falling back to size check');
        // Fallback to size-based detection
        isDirectory = file.size == 0;
      }
      
      logger.d('📋 FINAL: ${file.name} → Type: ${isDirectory ? "📁 FOLDER" : "📄 FILE"} | Size: ${file.size} | Attributes: ${file.attributes}');
      
      items.add(FileItem(
        name: file.name,
        path: '$path/${file.name}',
        type: isDirectory ? FileItemType.folder : FileItemType.file,
        location: FileLocation.network,
        size: isDirectory ? 0 : file.size,
        modifiedDate: DateTime.fromMillisecondsSinceEpoch(file.lastModified),
      ));
    }

    // Sort: folders first, then files
    items.sort((a, b) {
      if (a.type == b.type) {
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
      return a.type == FileItemType.folder ? -1 : 1;
    });

    final folderCount = items.where((i) => i.type == FileItemType.folder).length;
    final fileCount = items.where((i) => i.type == FileItemType.file).length;
    logger.i('✅ Listed ${items.length} SMB items (📁 $folderCount folders, 📄 $fileCount files)');
    return items;
  } catch (e) {
    logger.e('❌ Error listing SMB files: $e');
    logger.e('Stack trace: ${StackTrace.current}');
    return [];
  }
}
  // Future<List<FileItem>> listFiles(String path) async {
  //   if (_smbConnect == null || _currentProfile == null) {
  //     logger.e('❌ Not connected to SMB server');
  //     throw Exception('Not connected to SMB server');
  //   }

  //   try {
  //     logger.d('📂 Listing SMB files from: $path');
  //     final sharePath = '/${_currentProfile!.shareName}$path';
  //     final smbFolder = await _smbConnect!.file(sharePath);
  //     final files = await _smbConnect!.listFiles(smbFolder);

  //     final List<FileItem> items = [];

  //     for (var file in files) {
  //       final isDirectory = file.isDirectory == true;
        
  //       items.add(FileItem(
  //         name: file.name,
  //         path: '$path/${file.name}',
  //         type: isDirectory ? FileItemType.folder : FileItemType.file,
  //         location: FileLocation.network,
  //         size: file.size,
  //         modifiedDate: DateTime.fromMillisecondsSinceEpoch(file.lastModified),
  //       ));
  //     }

  //     // Sort: folders first, then files
  //     items.sort((a, b) {
  //       if (a.type == b.type) {
  //         return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  //       }
  //       return a.type == FileItemType.folder ? -1 : 1;
  //     });

  //     logger.i('✅ Listed ${items.length} SMB items');
  //     return items;
  //   } catch (e) {
  //     logger.e('❌ Error listing SMB files: $e');
  //     return [];
  //   }
  // }

Future<bool> downloadFile(
    String remotePath,
    String localPath, {
    Function(int, int)? onProgress,
  }) async {
    if (_smbConnect == null || _currentProfile == null) {
      logger.e('❌ Not connected to SMB server');
      return false;
    }

    try {
      logger.d('⬇️ Starting download: $remotePath');
      final cleanPath = remotePath.startsWith('/') ? remotePath.substring(1) : remotePath;
      final sharePath = '/${_currentProfile!.shareName}/$cleanPath';
      logger.d('📝 Download SMB path: $sharePath');

      // Ensure parent directory exists
      final localFile = File(localPath);
      final parentDir = Directory(localPath.substring(0, localPath.lastIndexOf('/')));
      
      logger.d('📁 Parent directory: ${parentDir.path}');
      if (!await parentDir.exists()) {
        logger.d('Creating parent directory...');
        await parentDir.create(recursive: true);
        logger.d('✅ Created parent directory: ${parentDir.path}');
      }

      logger.d('🔍 Attempting to open SMB file: $sharePath');
      final smbFile = await _smbConnect!.file(sharePath);
      

      logger.d('📊 SMB File size: ${smbFile.size} bytes');
      logger.d('📝 Local save path: $localPath');

      // Try to open file for reading
      logger.d('📖 Opening SMB file for reading...');
      final reader = await _smbConnect!.openRead(smbFile);
      
      logger.d('💾 Opening local file for writing...');
      final sink = localFile.openWrite();

      int downloaded = 0;
      final fileSize = smbFile.size;
      logger.d('📥 Starting to download: $fileSize bytes');

      await for (var chunk in reader) {
        sink.add(chunk);
        downloaded += chunk.length;
        logger.d('📊 Downloaded: $downloaded / $fileSize bytes');
        onProgress?.call(downloaded, fileSize);
      }

      logger.d('✅ Download stream complete, flushing...');
      await sink.flush();
      await sink.close();
      
      // Verify file was written
      if (await localFile.exists()) {
        final fileSize = await localFile.length();
        logger.i('✅ Download completed: $remotePath ($fileSize bytes saved)');
        logger.d('💾 File saved to: $localPath');
        return true;
      } else {
        logger.e('❌ File was not saved locally');
        return false;
      }
    } catch (e) {
      logger.e('❌ Error downloading file: $e');
      logger.e('Stack trace: ${StackTrace.current}');
      print('Error downloading file: $e');
      print('Stack trace: ${StackTrace.current}');
      return false;
    }
  }

  Future<bool> uploadFile(
    String localPath,
    String remotePath, {
    Function(int, int)? onProgress,
  }) async {
    if (_smbConnect == null || _currentProfile == null) {
      logger.e('❌ Not connected to SMB server');
      return false;
    }

    try {
      logger.d('⬆️ Starting upload: $localPath → $remotePath');
      final cleanPath = remotePath.startsWith('/') ? remotePath.substring(1) : remotePath;
      final sharePath = '/${_currentProfile!.shareName}/$cleanPath';
      logger.d('📝 Upload SMB path: $sharePath');

      // Check local file exists
      final localFile = File(localPath);
      if (!await localFile.exists()) {
        logger.e('❌ Local file does not exist: $localPath');
        return false;
      }

      final fileSize = await localFile.length();
      logger.d('📊 Local file size: $fileSize bytes');
      logger.d('📝 Local source path: $localPath');

      // Read file into bytes
      logger.d('📖 Reading local file into memory...');
      final bytes = await localFile.readAsBytes();
      logger.d('✅ File read successfully: ${bytes.length} bytes');

      // Try to open SMB file for writing
      logger.d('🔍 Attempting to open SMB file for writing: $sharePath');
      final smbFile = await _smbConnect!.file(sharePath);


      logger.d('📡 Opening SMB file for writing...');
      final writer = await _smbConnect!.openWrite(smbFile);

      const chunkSize = 1024 * 1024; // 1MB chunks
      int uploaded = 0;

      logger.d('📤 Starting to upload: $fileSize bytes in ${(fileSize / chunkSize).ceil()} chunks');

      for (int i = 0; i < bytes.length; i += chunkSize) {
        final end = (i + chunkSize < bytes.length) ? i + chunkSize : bytes.length;
        final chunk = bytes.sublist(i, end);
        writer.add(chunk);
        uploaded += chunk.length;
        
        logger.d('📊 Uploaded: $uploaded / $fileSize bytes');
        onProgress?.call(uploaded, fileSize);
      }

      logger.d('✅ All chunks written, flushing...');
      await writer.flush();
      await writer.close();
      
      logger.i('✅ Upload completed: $remotePath ($fileSize bytes uploaded)');
      logger.d('📤 Uploaded from: $localPath');
      logger.d('📡 Saved to: $sharePath');
      return true;
    } catch (e) {
      logger.e('❌ Error uploading file: $e');
      logger.e('Stack trace: ${StackTrace.current}');
      print('Error uploading file: $e');
      print('Stack trace: ${StackTrace.current}');
      return false;
    }
  }

   Future<bool> deleteFile(String remotePath) async {
    if (_smbConnect == null || _currentProfile == null) {
      logger.e('❌ Not connected to SMB server');
      return false;
    }

    try {
      logger.d('🗑️ Deleting file: $remotePath');
      final cleanPath = _cleanPath(remotePath);
      final sharePath = '/${_currentProfile!.shareName}/$cleanPath';
      logger.d('📝 Delete SMB path: $sharePath');
      
      final smbFile = await _smbConnect!.file(sharePath);
      
      logger.d('🔍 Deleting SMB file...');
      await _smbConnect!.delete(smbFile);
      logger.i('✅ File deleted: $remotePath');
      return true;
    } catch (e) {
      logger.e('❌ Error deleting file: $e');
      print('Error deleting file: $e');
      return false;
    }
  }

  Future<bool> renameFile(String oldPath, String newName) async {
    if (_smbConnect == null || _currentProfile == null) {
      logger.e('❌ Not connected to SMB server');
      return false;
    }

    try {
      logger.d('✏️ Renaming file: $oldPath → $newName');
      final cleanOldPath = _cleanPath(oldPath);
      
      final parentPath = cleanOldPath.contains('/') 
          ? cleanOldPath.substring(0, cleanOldPath.lastIndexOf('/'))
          : '';
      
      final newPath = parentPath.isEmpty ? newName : '$parentPath/$newName';
      final oldSharePath = '/${_currentProfile!.shareName}/$cleanOldPath';
      final newSharePath = '/${_currentProfile!.shareName}/$newPath';

      logger.d('📝 Old SMB path: $oldSharePath');
      logger.d('📝 New SMB path: $newSharePath');
      
      final oldFile = await _smbConnect!.file(oldSharePath);
      
      logger.d('🔍 Renaming SMB file...');
      await _smbConnect!.rename(oldFile, newSharePath);
      logger.i('✅ File renamed successfully');
      return true;
    } catch (e) {
      logger.e('❌ Error renaming file: $e');
      print('Error renaming file: $e');
      return false;
    }
  }

  Future<bool> createFolder(String remotePath, String folderName) async {
    if (_smbConnect == null || _currentProfile == null) {
      logger.e('❌ Not connected to SMB server');
      return false;
    }

    try {
      logger.d('📁 Creating folder: $folderName at $remotePath');
      final cleanPath = _cleanPath(remotePath);
      final folderPath = cleanPath.isEmpty ? folderName : '$cleanPath/$folderName';
      final sharePath = '/${_currentProfile!.shareName}/$folderPath';
      
      logger.d('📝 Create folder SMB path: $sharePath');
      logger.d('🔍 Creating folder on SMB server...');
      await _smbConnect!.createFolder(sharePath);
      logger.i('✅ Folder created: $folderName');
      return true;
    } catch (e) {
      logger.e('❌ Error creating folder: $e');
      print('Error creating folder: $e');
      return false;
    }
  }

  void disconnect() {
    try {
      logger.d('🔌 Disconnecting from SMB server...');
      _smbConnect?.close();
      _smbConnect = null;
      _currentProfile = null;
      logger.i('✅ Disconnected from SMB');
    } catch (e) {
      logger.e('❌ Error disconnecting: $e');
    }
  }
}
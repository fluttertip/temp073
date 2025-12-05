import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:smb_connect/smb_connect.dart';
import 'package:path_provider/path_provider.dart';
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

/// Get a stream for reading file directly (for streaming)
Future<Stream<List<int>>?> getFileStream(String path) async {
  try {
    if (!isConnected || _smbConnect == null) {
      logger.e('❌ Not connected to SMB');
      return null;
    }

    // Clean path and build full SMB path
    var cleanPath = path.replaceAll('//', '/');
    if (cleanPath.startsWith('/')) {
      cleanPath = cleanPath.substring(1);
    }
    final sharePath = '/${_currentProfile!.shareName}/$cleanPath';
    
    logger.d('📖 Opening file stream: $sharePath');

    // Get the SmbFile object first
    final smbFile = await _smbConnect!.file(sharePath);
    
    // Then open the stream
    final stream = await _smbConnect!.openRead(smbFile);
    logger.d('✅ File stream opened');
    
    return stream;
  } catch (e) {
    logger.e('❌ Error opening file stream: $e');
    logger.e('Stack trace: ${StackTrace.current}');
    return null;
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
    // Ensure cleanPath starts with / but listFiles uses it as-is
    if (!cleanPath.startsWith('/')) {
      cleanPath = '/$cleanPath';
    }
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

      final filePath = path == '/' ? '/${file.name}' : '$path/${file.name}';
      
      items.add(FileItem(
        name: file.name,
        path: filePath,
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

// Fix for SMB Service - downloadFile method
// Replace lines 183-260 with this:

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

      // Ensure parent directory exists and delete existing file
      final localFile = File(localPath);
      final parentDir = Directory(localPath.substring(0, localPath.lastIndexOf('/')));
      
      logger.d('📁 Parent directory: ${parentDir.path}');
      if (!await parentDir.exists()) {
        logger.d('Creating parent directory...');
        await parentDir.create(recursive: true);
        logger.d('✅ Created parent directory: ${parentDir.path}');
      }

      // DELETE existing file if it exists (fixes "File exists" error)
      if (await localFile.exists()) {
        logger.d('🗑️ Deleting existing file: $localPath');
        await localFile.delete();
        logger.d('✅ Existing file deleted');
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
        onProgress?.call(downloaded, fileSize);
      }

      logger.d('✅ Download stream complete, flushing...');
      await sink.flush();
      await sink.close();
      
      // Verify file was written
      if (await localFile.exists()) {
        final downloadedFileSize = await localFile.length();
        logger.i('✅ Download completed: $remotePath ($downloadedFileSize bytes saved)');
        logger.d('💾 File saved to: $localPath');
        return true;
      } else {
        logger.e('❌ File was not saved locally');
        return false;
      }
    } catch (e) {
      logger.e('❌ ERROR downloading file: $e');
      logger.e('🐛 Stack trace: ${StackTrace.current}');
      // Try to delete partial file on error
      try {
        final localFile = File(localPath);
        if (await localFile.exists()) {
          await localFile.delete();
          logger.d('🗑️ Deleted partial file on error');
        }
      } catch (cleanupError) {
        logger.e('⚠️ Could not clean up partial file: $cleanupError');
      }
      return false;
    }
  }

Future<Uint8List> getFileBytes(String remotePath) async {
  if (_smbConnect == null || _currentProfile == null) {
    logger.e('❌ Not connected to SMB server');
    throw Exception('Not connected to SMB server');
  }

  try {
    logger.d('📥 Getting file bytes from SMB: $remotePath');
    // Clean path - remove double slashes and leading slash
    var cleanPath = remotePath.replaceAll('//', '/');
    if (cleanPath.startsWith('/')) {
      cleanPath = cleanPath.substring(1);
    }
    final sharePath = '/${_currentProfile!.shareName}/$cleanPath';
    logger.d('📝 Clean SMB path: $sharePath');
    
    final smbFile = await _smbConnect!.file(sharePath);
    final reader = await _smbConnect!.openRead(smbFile);
    
    final chunks = <Uint8List>[];
    int totalBytes = 0;
    
    await for (var chunk in reader) {
      chunks.add(chunk);
      totalBytes += chunk.length;
      logger.d('📊 Read: $totalBytes bytes');
    }
    
    final fileBytes = Uint8List(totalBytes);
    int offset = 0;
    for (var chunk in chunks) {
      fileBytes.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }
    
    logger.i('✅ File bytes retrieved: $remotePath (${fileBytes.length} bytes)');
    return fileBytes;
  } catch (e) {
    logger.e('❌ Error getting file bytes: $e');
    rethrow;
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
      return false;
    }
  }


/// Progressive image loading - get first chunk quickly for preview
Future<Uint8List?> getImagePreviewChunk(String remotePath, int maxBytes) async {
  if (_smbConnect == null || _currentProfile == null) {
    logger.e('❌ Not connected to SMB server');
    return null;
  }

  try {
    logger.d('📥 Getting image preview chunk from SMB: $remotePath (max: $maxBytes bytes)');
    var cleanPath = remotePath.replaceAll('//', '/');
    if (cleanPath.startsWith('/')) {
      cleanPath = cleanPath.substring(1);
    }
    final sharePath = '/${_currentProfile!.shareName}/$cleanPath';
    
    final smbFile = await _smbConnect!.file(sharePath);
    final reader = await _smbConnect!.openRead(smbFile);
    
    final chunks = <Uint8List>[];
    int totalBytes = 0;
    
    await for (var chunk in reader) {
      chunks.add(chunk);
      totalBytes += chunk.length;
      
      if (totalBytes >= maxBytes) {
        logger.d('📊 Preview chunk ready: $totalBytes bytes');
        break;
      }
    }
    
    final previewBytes = Uint8List(totalBytes);
    int offset = 0;
    for (var chunk in chunks) {
      previewBytes.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }
    
    logger.i('✅ Image preview chunk loaded: ${previewBytes.length} bytes');
    return previewBytes;
  } catch (e) {
    logger.e('❌ Error getting image preview: $e');
    return null;
  }
}

/// Get image bytes by downloading to temp file first (more reliable for binary data)
Future<Uint8List> getImageBytesWithProgress(
  String remotePath, {
  Function(int, int)? onProgress,
}) async {
  if (_smbConnect == null || _currentProfile == null) {
    logger.e('❌ Not connected to SMB server');
    throw Exception('Not connected to SMB server');
  }

  try {
    logger.d('📥 Getting full image from SMB: $remotePath');
    var cleanPath = remotePath.replaceAll('//', '/');
    if (cleanPath.startsWith('/')) {
      cleanPath = cleanPath.substring(1);
    }
    final sharePath = '/${_currentProfile!.shareName}/$cleanPath';
    logger.d('📝 Clean SMB path: $sharePath');
    
    final smbFile = await _smbConnect!.file(sharePath);
    final fileSize = smbFile.size;
    logger.d('📊 File size: $fileSize bytes');
    
    // Get temp directory and create temp file
    final tempDir = await getTemporaryDirectory();
    final tempPath = '${tempDir.path}/.temp_image_${DateTime.now().millisecondsSinceEpoch}';
    final tempFile = File(tempPath);
    
    logger.d('💾 Using temp file: $tempPath');
    
    // Download to temp file with progress
    final success = await downloadFile(
      remotePath,
      tempPath,
      onProgress: onProgress,
    );
    
    if (!success) {
      throw Exception('Failed to download image file');
    }
    
    // Read the temp file into memory
    final fileBytes = await tempFile.readAsBytes();
    logger.d('📖 Read from temp file: ${fileBytes.length} bytes');
    
    // Delete temp file
    try {
      await tempFile.delete();
    } catch (e) {
      logger.d('⚠️ Failed to delete temp file: $e');
    }
    
    logger.i('✅ Full image loaded: ${fileBytes.length} bytes');
    return fileBytes;
  } catch (e) {
    logger.e('❌ Error getting image: $e');
    rethrow;
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
import 'package:flutter/material.dart';
import '../models/file_item.dart';
import '../services/local_storage_service.dart';
import '../services/clipboard_manager.dart';
import '../widgets/file_list_item.dart';
import '../widgets/file_operation_dialog.dart';
import '../utils/logger.dart';

class LocalBrowserScreen extends StatefulWidget {
  const LocalBrowserScreen({super.key});

  @override
  State<LocalBrowserScreen> createState() => _LocalBrowserScreenState();
}

class _LocalBrowserScreenState extends State<LocalBrowserScreen> {
  String _currentPath = '/storage/emulated/0';
  List<FileItem> _files = [];
  bool _isLoading = false;
  final _clipboard = ClipboardManager();

  @override
  void initState() {
    super.initState();
    logger.d('🔵 LocalBrowserScreen initialized');
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    logger.d('📂 Loading local files from: $_currentPath');
    setState(() => _isLoading = true);
    final files = await LocalStorageService.listFiles(_currentPath);
    logger.i('✅ Loaded ${files.length} items');
    setState(() {
      _files = files;
      _isLoading = false;
    });
  }

  void _navigateToFolder(String path) {
    logger.d('➡️ Navigating to folder: $path');
    setState(() {
      _currentPath = path;
    });
    _loadFiles();
  }

  void _goBack() {
    if (_currentPath == '/storage/emulated/0') {
      logger.d('Already at root directory');
      return;
    }
    final parentPath = _currentPath.substring(0, _currentPath.lastIndexOf('/'));
    logger.d('⬅️ Going back to: ${parentPath.isEmpty ? "/" : parentPath}');
    _navigateToFolder(parentPath.isEmpty ? '/' : parentPath);
  }

  Future<void> _createFolder() async {
    logger.d('📁 Create folder dialog opened');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => FileOperationDialog.createFolder(),
    );

    if (result != null && result.isNotEmpty) {
      logger.d('Creating folder: $result');
      final success = await LocalStorageService.createFolder(_currentPath, result);
      if (success) {
        logger.i('✅ Folder created: $result');
        _showSnackBar('Folder created successfully');
        _loadFiles();
      } else {
        logger.e('❌ Failed to create folder: $result');
        _showSnackBar('Failed to create folder', isError: true);
      }
    }
  }

  Future<void> _deleteFile(FileItem file) async {
    logger.d('🗑️ Delete dialog opened for: ${file.name}');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => FileOperationDialog.confirmDelete(file.name),
    );

    if (confirmed == true) {
      logger.d('Deleting file: ${file.path}');
      final success = await LocalStorageService.deleteFile(file.path);
      if (success) {
        logger.i('✅ File deleted: ${file.name}');
        _showSnackBar('Deleted successfully');
        _loadFiles();
      } else {
        logger.e('❌ Failed to delete: ${file.name}');
        _showSnackBar('Failed to delete', isError: true);
      }
    }
  }

  Future<void> _renameFile(FileItem file) async {
    logger.d('✏️ Rename dialog opened for: ${file.name}');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => FileOperationDialog.rename(file.name),
    );

    if (result != null && result.isNotEmpty) {
      logger.d('Renaming ${file.name} to $result');
      final success = await LocalStorageService.renameFile(file.path, result);
      if (success) {
        logger.i('✅ File renamed: ${file.name} → $result');
        _showSnackBar('Renamed successfully');
        _loadFiles();
      } else {
        logger.e('❌ Failed to rename: ${file.name}');
        _showSnackBar('Failed to rename', isError: true);
      }
    }
  }

  void _copyFile(FileItem file) {
    logger.d('📋 Copying file: ${file.name}');
    _clipboard.copy([file.path], FileLocation.local);
    logger.i('✅ File copied to clipboard: ${file.name}');
    _showSnackBar('Copied to clipboard');
  }

  void _cutFile(FileItem file) {
    logger.d('✂️ Cutting file: ${file.name}');
    _clipboard.cut([file.path], FileLocation.local);
    logger.i('✅ File cut to clipboard: ${file.name}');
    _showSnackBar('Cut to clipboard');
  }

  Future<void> _pasteFiles() async {
    if (!_clipboard.hasClipboard) {
      logger.w('⚠️ Clipboard is empty');
      return;
    }

    logger.d('📤 Pasting ${_clipboard.paths.length} file(s) to: $_currentPath');
    int successCount = 0;
    int failCount = 0;

    for (var sourcePath in _clipboard.paths) {
      final fileName = sourcePath.split('/').last;
      final destPath = '$_currentPath/$fileName';

      bool success;
      if (_clipboard.isCut) {
        logger.d('Moving: $fileName');
        success = await LocalStorageService.moveFile(sourcePath, destPath);
      } else {
        logger.d('Copying: $fileName');
        success = await LocalStorageService.copyFile(sourcePath, destPath);
      }

      if (success) {
        successCount++;
        logger.i('✅ $fileName pasted successfully');
      } else {
        failCount++;
        logger.e('❌ Failed to paste: $fileName');
      }
    }

    _clipboard.clear();
    logger.d('Clipboard cleared');
    _loadFiles();

    if (failCount == 0) {
      logger.i('✅ Pasted all $successCount file(s) successfully');
      _showSnackBar('Pasted $successCount file(s) successfully');
    } else {
      logger.w('⚠️ Paste completed with errors: $successCount ok, $failCount failed');
      _showSnackBar('Pasted $successCount, failed $failCount', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
      ),
    );
  }

  void _showFileOptions(FileItem file) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.copy),
            title: const Text('Copy'),
            onTap: () {
              Navigator.pop(context);
              _copyFile(file);
            },
          ),
          ListTile(
            leading: const Icon(Icons.content_cut),
            title: const Text('Cut'),
            onTap: () {
              Navigator.pop(context);
              _cutFile(file);
            },
          ),
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Rename'),
            onTap: () {
              Navigator.pop(context);
              _renameFile(file);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('Delete', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(context);
              _deleteFile(file);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Path breadcrumb
          Container(
            padding: const EdgeInsets.all(8),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _currentPath != '/storage/emulated/0' ? _goBack : null,
                ),
                Expanded(
                  child: Text(
                    _currentPath,
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_clipboard.hasClipboard)
                  IconButton(
                    icon: const Icon(Icons.paste),
                    onPressed: _pasteFiles,
                  ),
              ],
            ),
          ),
          // File list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _files.isEmpty
                    ? const Center(child: Text('No files found'))
                    : ListView.builder(
                        itemCount: _files.length,
                        itemBuilder: (context, index) {
                          final file = _files[index];
                          return FileListItem(
                            file: file,
                            onTap: () {
                              if (file.type == FileItemType.folder) {
                                _navigateToFolder(file.path);
                              }
                            },
                            onLongPress: () => _showFileOptions(file),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createFolder,
        child: const Icon(Icons.create_new_folder),
      ),
    );
  }
}
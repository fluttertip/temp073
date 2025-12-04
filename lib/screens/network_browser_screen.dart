import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/file_item.dart';
import '../models/connection_profile.dart';
import '../services/smb_service.dart';
import '../services/local_storage_service.dart';
import '../services/clipboard_manager.dart';
import '../widgets/file_list_item.dart';
import '../widgets/file_operation_dialog.dart';
import 'connection_manager_screen.dart';
import '../utils/logger.dart';



class NetworkBrowserScreen extends StatefulWidget {
  const NetworkBrowserScreen({super.key});

  @override
  State<NetworkBrowserScreen> createState() => _NetworkBrowserScreenState();
}


class _NetworkBrowserScreenState extends State<NetworkBrowserScreen> {
  final _smbService = SmbService();
  final _clipboard = ClipboardManager();
  
  String _currentPath = '/';
  List<FileItem> _files = [];
  bool _isLoading = false;
  List<ConnectionProfile> _savedConnections = [];

  @override
  void initState() {
    super.initState();
    logger.d('🔵 NetworkBrowserScreen initialized');
    _loadAndAutoConnect();
  }

  Future<void> _loadAndAutoConnect() async {
    logger.d('📋 Loading saved connections...');
    
    final prefs = await SharedPreferences.getInstance();
    final profilesJson = prefs.getStringList('connection_profiles') ?? [];
    _savedConnections = profilesJson
        .map((json) => ConnectionProfile.fromJson(json))
        .toList();
    
    final lastUsedId = prefs.getString('last_used_connection_id');
    
    if (lastUsedId != null && _savedConnections.isNotEmpty) {
      try {
        final lastProfile = _savedConnections.firstWhere(
          (p) => p.id == lastUsedId,
          orElse: () => _savedConnections.first,
        );
        
        logger.d('🔌 Auto-connecting to last used: ${lastProfile.name}');
        await _connectToProfile(lastProfile);
      } catch (e) {
        logger.e('❌ Auto-connect failed: $e');
        setState(() {});
      }
    } else {
      setState(() {});
      if (_savedConnections.isEmpty) {
        logger.w('⚠️ No saved connections found');
      }
    }
  }

  Future<void> _connectToProfile(ConnectionProfile profile) async {
    logger.d('🔌 Connecting to ${profile.name} (${profile.ip})...');
    setState(() => _isLoading = true);

    try {
      final connected = await _smbService.connect(profile);
      if (connected) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_used_connection_id', profile.id);
        
        logger.i('✅ Connected to ${profile.name}');
        setState(() {
          _currentPath = '/';
          _isLoading = false;
        });
        await _loadFiles();
      } else {
        logger.e('❌ Failed to connect to ${profile.name}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to connect to ${profile.name}'),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() => _isLoading = false);
      }
    } catch (e) {
      logger.e('❌ Connection error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadFiles() async {
    if (!_smbService.isConnected) {
      logger.w('⚠️ Not connected to SMB server');
      return;
    }

    logger.d('📂 Loading network files from: $_currentPath');
    setState(() => _isLoading = true);

    try {
      final files = await _smbService.listFiles(_currentPath);
      if (mounted) {
        setState(() {
          _files = files;
          logger.i('✅ Loaded ${files.length} network items');
          _isLoading = false;
        });
      }
    } catch (e) {
      logger.e('❌ Error loading files: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading files: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

    void _handleFileTap(FileItem file) {
   logger.d('🔹 Tapped on: ${file.name} (${file.type})');
  
  if (file.type == FileItemType.folder) {
    logger.d('📁 Opening folder: ${file.name}');
    _navigateToFolder(file.path);
  } else {
    logger.d('📄 File tapped (no action) - long press for options');
    _showSnackBar('Long press for options');
  }
  }

  void _navigateToFolder(String path) {
  logger.d('➡️ Navigating to folder: $path');
  
  // Clean the path - remove double slashes
  var cleanPath = path.replaceAll('//', '/');
  
  setState(() {
    _currentPath = cleanPath;
  });
  _loadFiles();
}

  // void _navigateToFolder(String path) {
  //   logger.d('➡️ Navigating to folder: $path');
  //   setState(() => _currentPath = path);
  //   _loadFiles();
  // }

  void _goBack() {
    if (_currentPath != '/') {
      final newPath = _currentPath.substring(0, _currentPath.lastIndexOf('/'));
      logger.d('⬅️ Going back to: ${newPath.isEmpty ? "/" : newPath}');
      _navigateToFolder(newPath.isEmpty ? '/' : newPath);
    }
  }

    Future<void> _createFolder() async {
    logger.d('📁 Create folder dialog opened');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => FileOperationDialog.createFolder(),
    );

    if (result != null && result.isNotEmpty) {
      logger.d('Creating folder: $result at $_currentPath');
      final success = await _smbService.createFolder(_currentPath, result);
      if (success) {
        logger.i('✅ Folder created: $result');
        _showSnackBar('Folder created successfully');
        await _loadFiles();
      } else {
        logger.e('❌ Failed to create folder: $result');
        _showSnackBar('Failed to create folder', isError: true);
      }
    }
  }


// transfer file from pc to local phone : download

Future<void> _downloadFile(FileItem file) async {
    logger.d('⬇️ Downloading file: ${file.name}');
    logger.d('File path: ${file.path}');
    logger.d('File size: ${file.size} bytes');
    
    final downloadsPath = await LocalStorageService.getDownloadsPath();
    final localPath = '$downloadsPath/${file.name}';
    
    logger.d('📥 Download destination: $localPath');
    
    final controller = ProgressDialogController();
    
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => FileOperationDialog.progressWithController(
          'Downloading to local storage...',
          controller,
        ),
      );
    }

    try {
      controller.updateProgress(0, file.name, 1, 1);
      
      logger.d('🚀 Starting download via SMB service...');
      // FIX: Remove double slashes
      var remotePath = _currentPath == '/' ? '/${file.name}' : '$_currentPath/${file.name}';
      // Remove any double slashes
      remotePath = remotePath.replaceAll('//', '/');
      logger.d('📡 Remote path: $remotePath');
      
      final success = await _smbService.downloadFile(
        remotePath,
        localPath,
        onProgress: (downloaded, total) {
          if (total > 0) {
            controller.updateProgress(
              downloaded / total,
              file.name,
              1,
              1,
            );
          }
        },
      );

      if (mounted) {
        Navigator.pop(context);
        if (success) {
          logger.i('✅ Download completed: ${file.name}');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Downloaded: ${file.name}'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          logger.e('❌ Download returned false');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Download failed - please check logs'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      logger.e('❌ Download exception: $e');
      logger.e('Stack: ${StackTrace.current}');
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }


  Future<void> _uploadFiles() async {
    if (!_clipboard.hasClipboard) {
      logger.w('⚠️ Clipboard is empty');
      _showSnackBar('Nothing to upload', isError: true);
      return;
    }

    if (_clipboard.sourceLocation != FileLocation.local) {
      logger.w('⚠️ Can only upload files from local storage');
      _showSnackBar('Can only upload files from local storage', isError: true);
      return;
    }

    logger.d('⬆️ Uploading ${_clipboard.paths.length} file(s) to: $_currentPath');

    final controller = ProgressDialogController();
    
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => FileOperationDialog.progressWithController(
          'Uploading to shared network storage...',
          controller,
        ),
      );
    }

    int successCount = 0;
    int failCount = 0;
    final totalFiles = _clipboard.paths.length;

    for (int i = 0; i < _clipboard.paths.length; i++) {
      final sourcePath = _clipboard.paths[i];
      final fileName = sourcePath.split('/').last;
      
      // FIX: Remove double slashes in remote path
      var remotePath = _currentPath == '/' 
          ? '/$fileName' 
          : '$_currentPath/$fileName';
      remotePath = remotePath.replaceAll('//', '/');

      logger.d('📤 Uploading file ${i + 1}/$totalFiles: $fileName');
      logger.d('📝 Local path: $sourcePath');
      logger.d('📡 Remote path: $remotePath');
      
      controller.updateProgress(0, fileName, i + 1, totalFiles);

      try {
        final success = await _smbService.uploadFile(
          sourcePath,
          remotePath,
          onProgress: (uploaded, total) {
            if (total > 0) {
              logger.d('📊 Upload progress: $uploaded / $total bytes');
              controller.updateProgress(
                uploaded / total,
                fileName,
                i + 1,
                totalFiles,
              );
            }
          },
        );

        if (success) {
          successCount++;
          logger.i('✅ File uploaded successfully: $fileName');
        } else {
          failCount++;
          logger.e('❌ Failed to upload: $fileName');
        }
      } catch (e) {
        failCount++;
        logger.e('❌ Upload error for $fileName: $e');
        logger.e('Stack: ${StackTrace.current}');
      }
    }

    _clipboard.clear();
    logger.d('Clipboard cleared');

    if (mounted) {
      Navigator.pop(context);
      
      // Refresh file list to show newly uploaded files
      await _loadFiles();

      if (failCount == 0) {
        logger.i('✅ Uploaded all $successCount file(s) successfully');
        _showSnackBar('Uploaded $successCount file(s) successfully');
      } else {
        logger.w('⚠️ Upload completed: $successCount ok, $failCount failed');
        _showSnackBar('Uploaded $successCount, failed $failCount', isError: true);
      }
    }
  }


  Future<void> _deleteFile(FileItem file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => FileOperationDialog.confirmDelete(file.name),
    );

    if (confirmed == true) {
      final success = await _smbService.deleteFile(file.path);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Deleted successfully')),
        );
        _loadFiles();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete')),
        );
      }
    }
  }

  Future<void> _renameFile(FileItem file) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => FileOperationDialog.rename(file.name),
    );

    if (result != null && result.isNotEmpty) {
      final success = await _smbService.renameFile(file.path, result);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Renamed successfully')),
        );
        _loadFiles();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to rename')),
        );
      }
    }
  }

  void _showFileOptions(FileItem file) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (file.type == FileItemType.file)
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('Download'),
              onTap: () {
                Navigator.pop(context);
                _downloadFile(file);
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


  void _showConnectionSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,  // Allow scrolling if needed
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 24.0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Select Connection',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 20),
                ..._savedConnections.map((profile) => ListTile(
                  leading: const Icon(Icons.computer),
                  title: Text(profile.name),
                  subtitle: Text('${profile.ip} - ${profile.shareName}'),
                  onTap: () {
                    Navigator.pop(context);
                    _connectToProfile(profile);
                  },
                )),
                const Divider(height: 24),
                ListTile(
                  leading: const Icon(Icons.add),
                  title: const Text('Manage Connections'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ConnectionManagerScreen(),
                      ),
                    ).then((_) {
                      _loadAndAutoConnect();
                    });
                  },
                ),
                // Bottom gesture area
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // void _showConnectionSelector() {
  //   showModalBottomSheet(
  //     context: context,
  //     builder: (context) => Column(
  //       mainAxisSize: MainAxisSize.min,
  //       children: [
  //         Padding(
  //           padding: const EdgeInsets.all(16.0),
  //           child: Text(
  //             'Select Connection',
  //             style: Theme.of(context).textTheme.titleLarge,
  //           ),
  //         ),
  //         ..._savedConnections.map((profile) => ListTile(
  //           leading: const Icon(Icons.computer),
  //           title: Text(profile.name),
  //           subtitle: Text('${profile.ip} - ${profile.shareName}'),
  //           onTap: () {
  //             Navigator.pop(context);
  //             _connectToProfile(profile);
  //           },
  //         )),
  //         const Divider(),
  //         ListTile(
  //           leading: const Icon(Icons.add),
  //           title: const Text('Manage Connections'),
  //           onTap: () {
  //             Navigator.pop(context);
  //             Navigator.push(
  //               context,
  //               MaterialPageRoute(
  //                 builder: (context) => const ConnectionManagerScreen(),
  //               ),
  //             ).then((_) {
  //               _loadAndAutoConnect();
  //             });
  //           },
  //         ),
  //       ],
  //     ),
  //   );
  // }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
      ),
    );
  }

   @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : !_smbService.isConnected
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.cloud_off, size: 64),
                      const SizedBox(height: 16),
                      const Text('Not connected to any network share'),
                      const SizedBox(height: 16),
                      if (_savedConnections.isNotEmpty)
                        ElevatedButton(
                          onPressed: _showConnectionSelector,
                          child: const Text('Select Connection'),
                        )
                      else
                        ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const ConnectionManagerScreen(),
                              ),
                            ).then((_) {
                              _loadAndAutoConnect();
                            });
                          },
                          child: const Text('Add Connection'),
                        ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Path bar with paste button
                    Container(
                      padding: const EdgeInsets.all(8),
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back),
                            onPressed: _currentPath != '/' ? _goBack : null,
                          ),
                          Expanded(
                            child: Text(
                              _currentPath,
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Paste/Upload button
                          if (_clipboard.hasClipboard && _clipboard.sourceLocation == FileLocation.local)
                            IconButton(
                              icon: const Icon(Icons.paste),
                              tooltip: 'paste ${_clipboard.itemCount} file(s)',
                              onPressed: _uploadFiles,
                            ),
                        ],
                      ),
                    ),
                    // Files list
                    Expanded(
                      child: _files.isEmpty
                          ? const Center(child: Text('No files found'))
                          : ListView.builder(
                              itemCount: _files.length,
                              itemBuilder: (context, index) {
                                final file = _files[index];
                                return FileListItem(
                                  file: file,
                                  onTap: () => _handleFileTap(file), // CHANGED: Use new handler
                                  onLongPress: () =>
                                      _showFileOptions(file),
                                );
                              },
                            ),
                    ),
                  ],
                ),
      floatingActionButton: _smbService.isConnected
          ? FloatingActionButton(
              onPressed: _createFolder,
              tooltip: 'Create Folder',
              child: const Icon(Icons.create_new_folder),
            )
          : null,
    );
  }
}

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: _isLoading
//           ? const Center(child: CircularProgressIndicator())
//           : !_smbService.isConnected
//               ? Center(
//                   child: Column(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       const Icon(Icons.cloud_off, size: 64),
//                       const SizedBox(height: 16),
//                       const Text('Not connected to any network share'),
//                       const SizedBox(height: 16),
//                       if (_savedConnections.isNotEmpty)
//                         ElevatedButton(
//                           onPressed: _showConnectionSelector,
//                           child: const Text('Select Connection'),
//                         )
//                       else
//                         ElevatedButton(
//                           onPressed: () {
//                             Navigator.push(
//                               context,
//                               MaterialPageRoute(
//                                 builder: (context) =>
//                                     const ConnectionManagerScreen(),
//                               ),
//                             ).then((_) {
//                               _loadAndAutoConnect();
//                             });
//                           },
//                           child: const Text('Add Connection'),
//                         ),
//                     ],
//                   ),
//                 )
//               : Column(
//                   children: [
//                     // Path bar with paste button
//                     Container(
//                       padding: const EdgeInsets.all(8),
//                       color: Theme.of(context).colorScheme.surfaceContainerHighest,
//                       child: Row(
//                         children: [
//                           IconButton(
//                             icon: const Icon(Icons.arrow_back),
//                             onPressed: _currentPath != '/' ? _goBack : null,
//                           ),
//                           Expanded(
//                             child: Text(
//                               _currentPath,
//                               style: const TextStyle(fontSize: 12),
//                               overflow: TextOverflow.ellipsis,
//                             ),
//                           ),
//                           // Paste/Upload button
//                           if (_clipboard.hasClipboard && _clipboard.sourceLocation == FileLocation.local)
//                             IconButton(
//                               icon: const Icon(Icons.paste),
//                               tooltip: 'paste ${_clipboard.itemCount} file(s)',
//                               onPressed: _uploadFiles,
//                             ),
//                         ],
//                       ),
//                     ),
//                     // Files list
//                     Expanded(
//                       child: _files.isEmpty
//                           ? const Center(child: Text('No files found'))
//                           : ListView.builder(
//                               itemCount: _files.length,
//                               itemBuilder: (context, index) {
//                                 final file = _files[index];
//                                 return FileListItem(
//                                   file: file,
//                                   onTap: () {
//                                     if (file.type == FileItemType.folder) {
//                                       _navigateToFolder(file.path);
//                                     } else {
//                                       _downloadFile(file);
//                                     }
//                                   },
//                                   onLongPress: () =>
//                                       _showFileOptions(file),
//                                 );
//                               },
//                             ),
//                     ),
//                   ],
//                 ),
//                 floatingActionButton: _smbService.isConnected
//           ? FloatingActionButton(
//               onPressed: _createFolder,
//               tooltip: 'Create Folder',
//               child: const Icon(Icons.create_new_folder),
//             )
//           : null,
//     );
//   }
// }
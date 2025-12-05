import 'package:flutter/material.dart';
import 'package:fileshareapp/models/file_item.dart';
import 'package:fileshareapp/services/smb_service.dart';
import 'package:fileshareapp/utils/logger.dart';

class TextPreviewScreen extends StatefulWidget {
  final FileItem file;

  const TextPreviewScreen({super.key, required this.file});

  @override
  State<TextPreviewScreen> createState() => _TextPreviewScreenState();
}

class _TextPreviewScreenState extends State<TextPreviewScreen> {
  final _smbService = SmbService();
  late Future<String> _textFuture;

  @override
  void initState() {
    super.initState();
    logger.d('📄 TextPreviewScreen initialized for: ${widget.file.name}');
    _textFuture = _loadText();
  }

  Future<String> _loadText() async {
    try {
      logger.d('📥 Loading text file from SMB: ${widget.file.path}');
      final bytes = await _smbService.getFileBytes(widget.file.path);
      final text = String.fromCharCodes(bytes);
      logger.i('✅ Text file loaded: ${widget.file.name}');
      return text;
    } catch (e) {
      logger.e('❌ Error loading text: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.file.name),
        elevation: 0,
      ),
      body: FutureBuilder<String>(
        future: _textFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(strokeWidth: 2),
                  SizedBox(height: 16),
                  Text('Loading text...', style: TextStyle(fontSize: 14)),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            logger.e('❌ Text load error: ${snapshot.error}');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Error loading text:\n${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() {
                      _textFuture = _loadText();
                    }),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: Text('No data'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SelectableText(
              snapshot.data!,
              style: const TextStyle(
                fontSize: 14,
                fontFamily: 'monospace',
                height: 1.5,
              ),
            ),
          );
        },
      ),
    );
  }
}
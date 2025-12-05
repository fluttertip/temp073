import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:fileshareapp/models/file_item.dart';
import 'package:fileshareapp/services/smb_service.dart';
import 'package:fileshareapp/utils/logger.dart';

class ProgressiveImagePreviewScreen extends StatefulWidget {
  final FileItem file;

  const ProgressiveImagePreviewScreen({super.key, required this.file});

  @override
  State<ProgressiveImagePreviewScreen> createState() =>
      _ProgressiveImagePreviewScreenState();
}

class _ProgressiveImagePreviewScreenState
    extends State<ProgressiveImagePreviewScreen> {
  final _smbService = SmbService();
  Uint8List? _imageData;
  int _downloadProgress = 0;
  int _fileSize = 0;
  bool _isReady = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    logger.d('🖼️ ProgressiveImagePreviewScreen initialized for: ${widget.file.name}');
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      _fileSize = widget.file.size;
      logger.d('📊 File size: $_fileSize bytes');
      logger.d('📥 Loading image with progress...');

      final imageBytes = await _smbService.getImageBytesWithProgress(
        widget.file.path,
        onProgress: (downloaded, total) {
          if (mounted) {
            setState(() {
              _downloadProgress = downloaded;
              _fileSize = total;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _imageData = imageBytes;
          _isReady = true;
          _downloadProgress = imageBytes.length;
          logger.i('✅ Image ready: ${imageBytes.length} bytes');
        });
      }
    } catch (e) {
      logger.e('❌ Error loading image: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.file.name),
        elevation: 0,
      ),
      body: _error != null
          ? _buildErrorView()
          : !_isReady
              ? _buildLoadingView()
              : _buildImageView(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Error loading image:\n$_error',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _error = null;
                _imageData = null;
                _isReady = false;
              });
              _loadImage();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(strokeWidth: 2),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                const Text(
                  'Loading image...',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: _fileSize > 0 ? _downloadProgress / _fileSize : 0,
                ),
                const SizedBox(height: 8),
                Text(
                  '${(_downloadProgress / (1024 * 1024)).toStringAsFixed(2)} / ${(_fileSize / (1024 * 1024)).toStringAsFixed(2)} MB',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageView() {
    if (_imageData == null) {
      return const Center(child: Text('No image data'));
    }

    return Stack(
      children: [
        InteractiveViewer(
          child: Image.memory(
            _imageData!,
            fit: BoxFit.contain,
          ),
        ),
        Positioned(
          top: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${(_fileSize / (1024 * 1024)).toStringAsFixed(2)} MB',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }
}
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:pdfrx/pdfrx.dart';
import 'package:fileshareapp/models/file_item.dart';
import 'package:fileshareapp/services/smb_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:fileshareapp/utils/logger.dart';

class PdfPreviewScreen extends StatefulWidget {
  final FileItem file;

  const PdfPreviewScreen({super.key, required this.file});

  @override
  State<PdfPreviewScreen> createState() => _PdfPreviewScreenState();
}

class _PdfPreviewScreenState extends State<PdfPreviewScreen> {
  final _smbService = SmbService();
  String? _tempPath;
  String? _error;
  int _downloadProgress = 0;
  int _fileSize = 0;
  bool _isDownloaded = false;

  @override
  void initState() {
    super.initState();
    logger.d('📕 PdfPreviewScreen initialized for: ${widget.file.name}');
    _downloadPdf();
  }

  Future<void> _downloadPdf() async {
    try {
      _fileSize = widget.file.size;
      logger.d('📥 Downloading PDF: ${widget.file.path} (${_fileSize ~/ (1024 * 1024)} MB)');

      final tempDir = await getTemporaryDirectory();
      _tempPath = '${tempDir.path}/${widget.file.name}';

      final tempFile = File(_tempPath!);
      if (await tempFile.exists()) {
        logger.d('📦 Using cached PDF');
        if (mounted) {
          setState(() {
            _isDownloaded = true;
          });
        }
        return;
      }

      final success = await _smbService.downloadFile(
        widget.file.path,
        _tempPath!,
        onProgress: (downloaded, total) {
          if (mounted) {
            setState(() {
              _downloadProgress = downloaded;
              _fileSize = total;
            });
          }
        },
      );

      if (!success) {
        throw Exception('Failed to download PDF');
      }

      logger.i('✅ PDF downloaded successfully');
      if (mounted) {
        setState(() {
          _isDownloaded = true;
        });
      }
    } catch (e) {
      logger.e('❌ Error downloading PDF: $e');
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
          : !_isDownloaded
              ? _buildDownloadingView()
              : _buildPdfView(),
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
              'Error: $_error',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _error = null;
                _tempPath = null;
                _isDownloaded = false;
                _downloadProgress = 0;
              });
              _downloadPdf();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadingView() {
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
                  'Downloading PDF...',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: _fileSize > 0 ? _downloadProgress / _fileSize : 0,
                ),
                const SizedBox(height: 8),
                Text(
                  '${(_downloadProgress / (1024 * 1024)).toStringAsFixed(1)} / ${(_fileSize / (1024 * 1024)).toStringAsFixed(1)} MB',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPdfView() {
  if (_tempPath == null) {
    return const Center(child: Text('PDF file not found'));
  }

  return PdfViewer.file(
    _tempPath!,
    params: PdfViewerParams(
      loadingBannerBuilder: (context, bytesDownloaded, totalBytes) {
        // Handle null totalBytes
        if (totalBytes == null || totalBytes == 0) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }
        
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                value: bytesDownloaded / totalBytes,
              ),
              const SizedBox(height: 8),
              Text(
                '${(bytesDownloaded / (1024 * 1024)).toStringAsFixed(1)} / ${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        );
      },
    ),
  );
}
}
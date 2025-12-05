import 'dart:io';
import 'package:fileshareapp/services/smb_service.dart';
import 'package:fileshareapp/utils/logger.dart';


class MediaStreamService {
  static final MediaStreamService _instance = MediaStreamService._internal();
  
  factory MediaStreamService() {
    return _instance;
  }
  
  MediaStreamService._internal();

  final _smbService = SmbService();
  HttpServer? _server;
  int? _serverPort;
  
  // Use port 0 for automatic assignment (more reliable)
  static const _defaultPort = 0;

  /// Start the local HTTP streaming server
  Future<String?> startStreamingServer() async {
    try {
      if (_server != null) {
        logger.d('📡 Server already running on port $_serverPort');
        return 'http://127.0.0.1:$_serverPort';
      }

      logger.d('🚀 Starting HTTP streaming server...');
      
      // Port 0 = let OS assign an available port
      _server = await HttpServer.bind('127.0.0.1', _defaultPort);
      _serverPort = _server!.port;
      
      logger.i('✅ HTTP server started on http://127.0.0.1:$_serverPort');
      
      // Listen for incoming requests
      _server!.listen((request) async {
        await _handleRequest(request);
      });
      
      return 'http://127.0.0.1:$_serverPort';
    } catch (e) {
      logger.e('❌ Failed to start streaming server: $e');
      return null;
    }
  }

  /// Get the streaming URL for a file
  Future<String?> getStreamUrl(String filePath) async {
    try {
      // Ensure server is running
      final baseUrl = await startStreamingServer();
      if (baseUrl == null) return null;
      
      // URL encode the file path
      final encoded = Uri.encodeComponent(filePath);
      final url = '$baseUrl/stream?file=$encoded';
      
      logger.d('📺 Stream URL: $url');
      return url;
    } catch (e) {
      logger.e('❌ Error generating stream URL: $e');
      return null;
    }
  }

  /// Handle incoming HTTP requests
  Future<void> _handleRequest(HttpRequest request) async {
    try {
      final path = request.uri.path;
      
      if (path == '/stream') {
        await _handleStreamRequest(request);
      } else if (path == '/health') {
        request.response
          ..statusCode = 200
          ..headers.set('Content-Type', 'text/plain')
          ..write('OK')
          ..close();
      } else {
        request.response
          ..statusCode = 404
          ..write('Not Found')
          ..close();
      }
    } catch (e) {
      logger.e('❌ Error handling request: $e');
      try {
        request.response
          ..statusCode = 500
          ..write('Server Error')
          ..close();
      } catch (e) {
        logger.d('⚠️ Could not send error response: $e');
      }
    }
  }

/// Handle stream requests with range support
Future<void> _handleStreamRequest(HttpRequest request) async {
  try {
    final filePath = request.uri.queryParameters['file'];
    if (filePath == null || filePath.isEmpty) {
      request.response
        ..statusCode = 400
        ..write('Missing file parameter')
        ..close();
      return;
    }

    logger.d('📥 Streaming request for: $filePath');

    // Get file stream from SMB (now async)
    final fileStream = await _smbService.getFileStream(filePath);
    if (fileStream == null) {
      throw Exception('Failed to open file stream');
    }

    // Set response headers for streaming
    request.response
      ..headers.set('Content-Type', 'video/mp4') // or appropriate MIME type
      ..headers.set('Accept-Ranges', 'bytes')
      ..headers.set('Cache-Control', 'no-cache')
      ..statusCode = 200;

    logger.d('📡 Streaming file: $filePath');

    // Stream the file
    await request.response.addStream(fileStream);
    await request.response.close();

    logger.i('✅ Stream completed: $filePath');
  } catch (e) {
    logger.e('❌ Stream error: $e');
    logger.e('Stack trace: ${StackTrace.current}');
    try {
      request.response
        ..statusCode = 500
        ..write('Streaming Error')
        ..close();
    } catch (e) {
      logger.d('⚠️ Could not close response: $e');
    }
  }
}

  /// Stop the streaming server
  Future<void> stopStreamingServer() async {
    try {
      if (_server != null) {
        logger.d('🛑 Stopping HTTP streaming server...');
        await _server!.close(force: true);
        _server = null;
        _serverPort = null;
        logger.i('✅ Streaming server stopped');
      }
    } catch (e) {
      logger.e('❌ Error stopping server: $e');
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    await stopStreamingServer();
  }
}
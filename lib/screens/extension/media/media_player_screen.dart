import 'package:fileshareapp/services/media/media_stream_service.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import 'package:video_player/video_player.dart';
import 'package:fileshareapp/models/file_item.dart';
import 'package:fileshareapp/services/smb_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:fileshareapp/utils/logger.dart';

class MediaPlayerScreen extends StatefulWidget {
  final FileItem file;
  final bool isVideo;

  const MediaPlayerScreen({
    super.key,
    required this.file,
    required this.isVideo,
  });

  @override
  State<MediaPlayerScreen> createState() => _MediaPlayerScreenState();
}

class _MediaPlayerScreenState extends State<MediaPlayerScreen> {
  final _smbService = SmbService();
  final _streamService = MediaStreamService();
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  String? _error;
  bool _isStreaming = true;
  bool _showControls = true;
  
  // Use ValueNotifier to avoid setState() rebuilds that interrupt playback
  late ValueNotifier<Duration> _positionNotifier;
  late ValueNotifier<Duration> _durationNotifier;
  late ValueNotifier<bool> _isPlayingNotifier;

    // Store listener function for proper cleanup
  late VoidCallback _playerListener;

  @override
  void initState() {
    super.initState();
    logger.d('🎬 MediaPlayerScreen initialized for: ${widget.file.name}');
    _positionNotifier = ValueNotifier(Duration.zero);
    _durationNotifier = ValueNotifier(Duration.zero);
    _isPlayingNotifier = ValueNotifier(false);
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      logger.d('🔧 Initializing ${widget.isVideo ? 'video' : 'audio'} player...');
      
      if (_isStreaming) {
        await _initializeStreaming();
      } else {
        await _initializeDownload();
      }
    } catch (e) {
      logger.e('❌ Error initializing player: $e');
      logger.e('Stack: ${StackTrace.current}');
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _initializeStreaming() async {
    logger.d('📡 Initializing streaming mode...');
    
    final baseUrl = await _streamService.startStreamingServer();
    if (baseUrl == null) {
      throw Exception('Failed to start streaming server');
    }
    
    final streamUrl = await _streamService.getStreamUrl(widget.file.path);
    if (streamUrl == null) {
      throw Exception('Failed to generate stream URL');
    }
    
    logger.d('🎬 Creating VideoPlayerController for stream: $streamUrl');
    _controller = VideoPlayerController.networkUrl(Uri.parse(streamUrl));
    
    logger.d('⏳ Initializing controller...');
    await _controller!.initialize();
    
    // Setup listeners INSTEAD of timer
    _setupControllerListeners();
    
    if (mounted) {
      setState(() {
        _isInitialized = true;
        _durationNotifier.value = _controller!.value.duration;
      });
      logger.d('▶️ Starting playback...');
      _controller!.play();
    }
    
    logger.i('✅ Streaming initialized successfully');
  }

  Future<void> _initializeDownload() async {
    logger.d('💾 Initializing download mode...');
    
    final tempDir = await getTemporaryDirectory();
    final tempPath = '${tempDir.path}/${widget.file.name}';
    
    logger.d('💾 Temp file path: $tempPath');
    
    final tempFile = File(tempPath);
    if (await tempFile.exists()) {
      logger.d('🗑️ Deleting stale cached file');
      try {
        await tempFile.delete();
      } catch (e) {
        logger.w('⚠️ Failed to delete old cache: $e');
      }
    }
    
    logger.d('📥 Downloading media file to temp...');
    
    final success = await _smbService.downloadFile(
      widget.file.path,
      tempPath,
      onProgress: (downloaded, total) {
        // Don't call setState during download
      },
    );
    
    if (!success) {
      throw Exception('Failed to download media file');
    }
    
    logger.i('✅ Media file downloaded: $tempPath');
    
    if (!await tempFile.exists()) {
      throw Exception('Temp file does not exist after download');
    }
    
    final fileSize = await tempFile.length();
    if (fileSize == 0) {
      throw Exception('Downloaded file is empty');
    }
    
    logger.d('🎬 Creating VideoPlayerController for local file');
    _controller = VideoPlayerController.file(File(tempPath));
    
    await _controller!.initialize();
    
    // Setup listeners INSTEAD of timer
    _setupControllerListeners();
    
    if (mounted) {
      setState(() {
        _isInitialized = true;
        _durationNotifier.value = _controller!.value.duration;
      });
      _controller!.play();
    }
    
    logger.i('✅ Download mode initialized successfully');
  }

void _setupControllerListeners() {
  if (_controller == null) return;
  
  // Create and store listener for proper cleanup on dispose
  _playerListener = () {
    _positionNotifier.value = _controller!.value.position;
    _isPlayingNotifier.value = _controller!.value.isPlaying;
  };
  
  // Add the stored listener
  _controller!.addListener(_playerListener);
}



@override
void dispose() {
  logger.d('🛑 Disposing media player...');
  
  // Properly remove the listener before disposing controller
  if (_controller != null) {
    _controller!.removeListener(_playerListener);
    _controller!.dispose();
  }
  
  _positionNotifier.dispose();
  _durationNotifier.dispose();
  _isPlayingNotifier.dispose();
  super.dispose();
}

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _seekTo(Duration duration) {
    if (_controller != null) {
      _controller!.seekTo(duration);
      logger.d('⏩ Seeking to: ${_formatDuration(duration)}');
    }
  }

  void _skipForward(int seconds) {
    if (_controller == null) return;
    final newPosition = _controller!.value.position + Duration(seconds: seconds);
    final maxDuration = _controller!.value.duration;
    
    if (newPosition > maxDuration) {
      _seekTo(maxDuration);
    } else {
      _seekTo(newPosition);
    }
  }

  void _skipBackward(int seconds) {
    if (_controller == null) return;
    final newPosition = _controller!.value.position - Duration(seconds: seconds);
    
    if (newPosition < Duration.zero) {
      _seekTo(Duration.zero);
    } else {
      _seekTo(newPosition);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.file.name),
        elevation: 0,
        backgroundColor: Colors.black87,
      ),
      body: _error != null
          ? _buildErrorView()
          : !_isInitialized
              ? _buildLoadingView()
              : widget.isVideo
                  ? _buildVideoPlayer()
                  : _buildAudioPlayer(),
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
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _error = null;
                    _isInitialized = false;
                    _isStreaming = true;
                  });
                  _initializePlayer();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry Streaming'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _error = null;
                    _isInitialized = false;
                    _isStreaming = false;
                  });
                  _initializePlayer();
                },
                icon: const Icon(Icons.download),
                label: const Text('Download Instead'),
              ),
            ],
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
                Text(
                  'Preparing ${_isStreaming ? 'stream' : 'download'}...',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 8),
                Chip(
                  label: Text(_isStreaming ? '📡 Streaming Mode' : '💾 Download Mode'),
                  avatar: Icon(_isStreaming ? Icons.stream : Icons.download),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPlayer() {
    if (_controller == null) {
      return const Center(child: Text('Video player not initialized'));
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _showControls = !_showControls;
        });
      },
      child: Container(
        color: Colors.black,
        child: Stack(
          children: [
            // Video display
            Center(
              child: AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: VideoPlayer(_controller!),
              ),
            ),
            
            // Top status bar
            if (_showControls)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black54, Colors.transparent],
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Chip(
                        label: Text(_isStreaming ? '📡 Streaming' : '💾 Downloaded'),
                        backgroundColor: _isStreaming ? Colors.blue.withOpacity(0.7) : Colors.orange.withOpacity(0.7),
                        labelStyle: const TextStyle(color: Colors.white, fontSize: 11),
                      ),
                      const Spacer(),
                      ValueListenableBuilder<Duration>(
                        valueListenable: _durationNotifier,
                        builder: (context, duration, _) {
                          return Text(
                            _formatDuration(duration),
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            
            // Bottom controls
            if (_showControls)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.black87, Colors.transparent],
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Progress bar with seek
                      _buildProgressBar(),
                      const SizedBox(height: 12),
                      // Time display
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            ValueListenableBuilder<Duration>(
                              valueListenable: _positionNotifier,
                              builder: (context, position, _) {
                                return Text(
                                  _formatDuration(position),
                                  style: const TextStyle(color: Colors.white, fontSize: 14),
                                );
                              },
                            ),
                            ValueListenableBuilder<Duration>(
                              valueListenable: _durationNotifier,
                              builder: (context, duration, _) {
                                return Text(
                                  _formatDuration(duration),
                                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Player controls
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.replay_10),
                              iconSize: 28,
                              color: Colors.white,
                              onPressed: () => _skipBackward(10),
                              tooltip: 'Rewind 10s',
                            ),
                            IconButton(
                              icon: const Icon(Icons.replay_5),
                              iconSize: 24,
                              color: Colors.white70,
                              onPressed: () => _skipBackward(5),
                              tooltip: 'Rewind 5s',
                            ),
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.blue.withOpacity(0.3),
                              ),
                              child: ValueListenableBuilder<bool>(
                                valueListenable: _isPlayingNotifier,
                                builder: (context, isPlaying, _) {
                                  return IconButton(
                                    icon: Icon(
                                      isPlaying ? Icons.pause : Icons.play_arrow,
                                      size: 32,
                                    ),
                                    iconSize: 40,
                                    color: Colors.white,
                                    onPressed: () {
                                      if (_controller!.value.isPlaying) {
                                        _controller!.pause();
                                      } else {
                                        _controller!.play();
                                      }
                                    },
                                  );
                                },
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.forward_5),
                              iconSize: 24,
                              color: Colors.white70,
                              onPressed: () => _skipForward(5),
                              tooltip: 'Forward 5s',
                            ),
                            IconButton(
                              icon: const Icon(Icons.forward_10),
                              iconSize: 28,
                              color: Colors.white,
                              onPressed: () => _skipForward(10),
                              tooltip: 'Forward 10s',
                            ),
                          ],
                        ),
                      ),
                      // Fullscreen button
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: IconButton(
                            icon: const Icon(Icons.fullscreen),
                            iconSize: 28,
                            color: Colors.white,
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => _FullScreenVideoPlayer(
                                    controller: _controller!,
                                    onSkipBackward: _skipBackward,
                                    onSkipForward: _skipForward,
                                    onSeekTo: _seekTo,
                                    positionNotifier: _positionNotifier,
                                    durationNotifier: _durationNotifier,
                                    isPlayingNotifier: _isPlayingNotifier,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ValueListenableBuilder<Duration>(
        valueListenable: _positionNotifier,
        builder: (context, position, _) {
          return ValueListenableBuilder<Duration>(
            valueListenable: _durationNotifier,
            builder: (context, duration, _) {
              return SliderTheme(
                data: SliderThemeData(
                  trackHeight: 4,
                  thumbShape: RoundSliderThumbShape(enabledThumbRadius: 8),
                  overlayShape: RoundSliderOverlayShape(overlayRadius: 12),
                ),
                child: Slider(
                  value: position.inMilliseconds.toDouble(),
                  max: duration.inMilliseconds.toDouble(),
                  onChanged: (value) {
                    _seekTo(Duration(milliseconds: value.toInt()));
                  },
                  activeColor: Colors.blue,
                  inactiveColor: Colors.white30,
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildAudioPlayer() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Chip(
          label: Text(_isStreaming ? '📡 Streaming' : '💾 Downloaded'),
          avatar: Icon(_isStreaming ? Icons.stream : Icons.download),
        ),
        const SizedBox(height: 24),
        const Icon(Icons.music_note, size: 80, color: Colors.blue),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            widget.file.name,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 24),
        _buildAudioControls(),
      ],
    );
  }

  Widget _buildAudioControls() {
    if (_controller == null) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: _buildProgressBar(),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ValueListenableBuilder<Duration>(
                valueListenable: _positionNotifier,
                builder: (context, position, _) {
                  return Text(
                    _formatDuration(position),
                    style: const TextStyle(fontSize: 14),
                  );
                },
              ),
              ValueListenableBuilder<Duration>(
                valueListenable: _durationNotifier,
                builder: (context, duration, _) {
                  return Text(
                    _formatDuration(duration),
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              icon: const Icon(Icons.replay_5),
              iconSize: 32,
              onPressed: () => _skipBackward(5),
            ),
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue.withOpacity(0.2),
              ),
              child: ValueListenableBuilder<bool>(
                valueListenable: _isPlayingNotifier,
                builder: (context, isPlaying, _) {
                  return IconButton(
                    icon: Icon(
                      isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                      size: 64,
                      color: Colors.blue,
                    ),
                    onPressed: () {
                      if (_controller!.value.isPlaying) {
                        _controller!.pause();
                      } else {
                        _controller!.play();
                      }
                    },
                  );
                },
              ),
            ),
            IconButton(
              icon: const Icon(Icons.forward_5),
              iconSize: 32,
              onPressed: () => _skipForward(5),
            ),
          ],
        ),
      ],
    );
  }
}

class _FullScreenVideoPlayer extends StatefulWidget {
  final VideoPlayerController controller;
  final Function(int) onSkipBackward;
  final Function(int) onSkipForward;
  final Function(Duration) onSeekTo;
  final ValueNotifier<Duration> positionNotifier;
  final ValueNotifier<Duration> durationNotifier;
  final ValueNotifier<bool> isPlayingNotifier;

  const _FullScreenVideoPlayer({
    required this.controller,
    required this.onSkipBackward,
    required this.onSkipForward,
    required this.onSeekTo,
    required this.positionNotifier,
    required this.durationNotifier,
    required this.isPlayingNotifier,
  });

  @override
  State<_FullScreenVideoPlayer> createState() => _FullScreenVideoPlayerState();
}

class _FullScreenVideoPlayerState extends State<_FullScreenVideoPlayer> {
  bool _showControls = true;
  Timer? _hideControlsTimer;

  void _resetControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context);
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onTap: () {
            setState(() {
              _showControls = !_showControls;
            });
            _resetControlsTimer();
          },
          child: Stack(
            children: [
              Center(
                child: AspectRatio(
                  aspectRatio: widget.controller.value.aspectRatio,
                  child: VideoPlayer(widget.controller),
                ),
              ),
              if (_showControls)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black54, Colors.transparent],
                      ),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          color: Colors.white,
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Spacer(),
                        ValueListenableBuilder<Duration>(
                          valueListenable: widget.durationNotifier,
                          builder: (context, duration, _) {
                            return Text(
                              _formatDuration(duration),
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              if (_showControls)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Colors.black87, Colors.transparent],
                      ),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ValueListenableBuilder<Duration>(
                          valueListenable: widget.positionNotifier,
                          builder: (context, position, _) {
                            return ValueListenableBuilder<Duration>(
                              valueListenable: widget.durationNotifier,
                              builder: (context, duration, _) {
                                return SliderTheme(
                                  data: SliderThemeData(
                                    trackHeight: 6,
                                    thumbShape: RoundSliderThumbShape(enabledThumbRadius: 10),
                                    overlayShape: RoundSliderOverlayShape(overlayRadius: 14),
                                  ),
                                  child: Slider(
                                    value: position.inMilliseconds.toDouble(),
                                    max: duration.inMilliseconds.toDouble(),
                                    onChanged: (value) {
                                      widget.onSeekTo(Duration(milliseconds: value.toInt()));
                                    },
                                    activeColor: Colors.blue,
                                    inactiveColor: Colors.white30,
                                  ),
                                );
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            ValueListenableBuilder<Duration>(
                              valueListenable: widget.positionNotifier,
                              builder: (context, position, _) {
                                return Text(
                                  _formatDuration(position),
                                  style: const TextStyle(color: Colors.white, fontSize: 14),
                                );
                              },
                            ),
                            ValueListenableBuilder<Duration>(
                              valueListenable: widget.durationNotifier,
                              builder: (context, duration, _) {
                                return Text(
                                  _formatDuration(duration),
                                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.replay_10),
                              iconSize: 32,
                              color: Colors.white,
                              onPressed: () {
                                widget.onSkipBackward(10);
                                _resetControlsTimer();
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.replay_5),
                              iconSize: 28,
                              color: Colors.white70,
                              onPressed: () {
                                widget.onSkipBackward(5);
                                _resetControlsTimer();
                              },
                            ),
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.blue.withOpacity(0.3),
                              ),
                              child: ValueListenableBuilder<bool>(
                                valueListenable: widget.isPlayingNotifier,
                                builder: (context, isPlaying, _) {
                                  return IconButton(
                                    icon: Icon(
                                      isPlaying ? Icons.pause : Icons.play_arrow,
                                      size: 32,
                                    ),
                                    iconSize: 48,
                                    color: Colors.white,
                                    onPressed: () {
                                      if (widget.controller.value.isPlaying) {
                                        widget.controller.pause();
                                      } else {
                                        widget.controller.play();
                                      }
                                      _resetControlsTimer();
                                    },
                                  );
                                },
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.forward_5),
                              iconSize: 28,
                              color: Colors.white70,
                              onPressed: () {
                                widget.onSkipForward(5);
                                _resetControlsTimer();
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.forward_10),
                              iconSize: 32,
                              color: Colors.white,
                              onPressed: () {
                                widget.onSkipForward(10);
                                _resetControlsTimer();
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

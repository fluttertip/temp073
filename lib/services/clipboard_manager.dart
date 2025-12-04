import 'package:fileshareapp/models/file_item.dart';

class ClipboardManager {
  static final ClipboardManager _instance = ClipboardManager._internal();
  factory ClipboardManager() => _instance;
  ClipboardManager._internal();

  List<String> _copiedPaths = [];
  List<String> _cutPaths = [];
  bool _isCut = false;
  FileLocation? _sourceLocation;
  String? _sourceShare;

  bool get hasClipboard => _copiedPaths.isNotEmpty || _cutPaths.isNotEmpty;
  bool get isCut => _isCut;
  List<String> get paths => _isCut ? _cutPaths : _copiedPaths;
  FileLocation? get sourceLocation => _sourceLocation;
  String? get sourceShare => _sourceShare;

  void copy(List<String> paths, FileLocation location, {String? shareId}) {
    _copiedPaths = List.from(paths);
    _cutPaths = [];
    _isCut = false;
    _sourceLocation = location;
    _sourceShare = shareId;
  }

  void cut(List<String> paths, FileLocation location, {String? shareId}) {
    _cutPaths = List.from(paths);
    _copiedPaths = [];
    _isCut = true;
    _sourceLocation = location;
    _sourceShare = shareId;
  }

  void clear() {
    _copiedPaths = [];
    _cutPaths = [];
    _isCut = false;
    _sourceLocation = null;
    _sourceShare = null;
  }

  int get itemCount => paths.length;
}
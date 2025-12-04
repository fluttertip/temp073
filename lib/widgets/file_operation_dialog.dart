import 'package:flutter/material.dart';


class ProgressDialogController {
  Function(double progress, String fileName, int current, int total)? _updateCallback;

  void updateProgress(double progress, String fileName, int current, int total) {
    // Only call if callback has been initialized
    if (_updateCallback != null) {
      _updateCallback!(progress, fileName, current, total);
    }
  }

  void _setCallback(Function(double, String, int, int) callback) {
    _updateCallback = callback;
  }
}


class FileOperationDialog {
  static Widget createFolder() {
    return _CreateFolderDialog();
  }

  static Widget rename(String currentName) {
    return _RenameDialog(currentName: currentName);
  }

  static Widget confirmDelete(String fileName) {
    return _ConfirmDeleteDialog(fileName: fileName);
  }

  static Widget progressWithController(
    String message,
    ProgressDialogController controller,
  ) {
    return _ProgressDialogWithController(
      message: message,
      controller: controller,
    );
  }
}

class _CreateFolderDialog extends StatefulWidget {
  const _CreateFolderDialog();

  @override
  State<_CreateFolderDialog> createState() => _CreateFolderDialogState();
}

class _CreateFolderDialogState extends State<_CreateFolderDialog> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Folder'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Folder Name',
            hintText: 'Enter folder name',
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a folder name';
            }
            if (value.contains('/') || value.contains('\\')) {
              return 'Folder name cannot contain / or \\';
            }
            return null;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, _controller.text);
            }
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}

class _RenameDialog extends StatefulWidget {
  final String currentName;

  const _RenameDialog({required this.currentName});

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _controller;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'New Name',
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a name';
            }
            if (value.contains('/') || value.contains('\\')) {
              return 'Name cannot contain / or \\';
            }
            return null;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, _controller.text);
            }
          },
          child: const Text('Rename'),
        ),
      ],
    );
  }
}

class _ConfirmDeleteDialog extends StatelessWidget {
  final String fileName;

  const _ConfirmDeleteDialog({required this.fileName});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Delete File'),
      content: Text('Are you sure you want to delete "$fileName"?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: const Text('Delete'),
        ),
      ],
    );
  }
}

// Progress dialog with percentage support
class _ProgressDialogWithController extends StatefulWidget {
  final String message;
  final ProgressDialogController controller;

  const _ProgressDialogWithController({
    required this.message,
    required this.controller,
  });

  @override
  State<_ProgressDialogWithController> createState() =>
      _ProgressDialogWithControllerState();
}

class _ProgressDialogWithControllerState
    extends State<_ProgressDialogWithController> {
  double _progress = 0.0;
  String _currentFile = '';
  int _currentIndex = 0;
  int _totalFiles = 0;

  @override
  void initState() {
    super.initState();
    // NOW set the callback AFTER state is initialized
    widget.controller._setCallback(
      (progress, fileName, current, total) {
        if (mounted) {
          setState(() {
            _progress = progress.clamp(0.0, 1.0);
            _currentFile = fileName;
            _currentIndex = current;
            _totalFiles = total;
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final percentage = (_progress * 100).toStringAsFixed(1);
    final showMultipleFiles = _totalFiles > 1;

    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text(widget.message),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // File count info
            if (showMultipleFiles)
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Text(
                  'File $_currentIndex of $_totalFiles',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),

            // File name
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Text(
                _currentFile.isNotEmpty ? _currentFile : 'Processing...',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _progress,
                minHeight: 10,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).primaryColor,
                ),
              ),
            ),

            // Percentage display
            Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$percentage%',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  if (showMultipleFiles)
                    Text(
                      '${(_currentIndex / _totalFiles * 100).toStringAsFixed(0)}% overall',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/connection_profile.dart';
import '../services/smb_service.dart';
import '../utils/logger.dart';

class ConnectionManagerScreen extends StatefulWidget {
  final bool selectMode;
  
  const ConnectionManagerScreen({
    super.key,
    this.selectMode = false,
  });

  @override
  State<ConnectionManagerScreen> createState() => _ConnectionManagerScreenState();
}

class _ConnectionManagerScreenState extends State<ConnectionManagerScreen> {
  List<ConnectionProfile> _profiles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    logger.d('🔌 ConnectionManagerScreen initialized (selectMode: ${widget.selectMode})');
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    logger.d('📋 Loading saved connection profiles...');
    final prefs = await SharedPreferences.getInstance();
    final profilesJson = prefs.getStringList('connection_profiles') ?? [];
    
    setState(() {
      _profiles = profilesJson
          .map((json) => ConnectionProfile.fromJson(json))
          .toList();
      _isLoading = false;
    });
    logger.i('✅ Loaded ${_profiles.length} connection profiles');
  }

  Future<void> _saveProfiles() async {
    logger.d('💾 Saving ${_profiles.length} connection profiles...');
    final prefs = await SharedPreferences.getInstance();
    final profilesJson = _profiles.map((p) => p.toJson()).toList();
    await prefs.setStringList('connection_profiles', profilesJson);
    logger.i('✅ Profiles saved');
  }

  Future<void> _addConnection() async {
    logger.d('➕ Add connection dialog opened');
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => const _AddConnectionDialog(),
    );

    if (result != null) {
      logger.d('Creating new profile: ${result['name']} (${result['ip']})');
      final profile = ConnectionProfile(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: result['name']!,
        ip: result['ip']!,
        shareName: result['share']!,
        username: result['username']!,
        password: result['password']!,
      );

      // Test connection
      logger.d('🧪 Testing connection before saving...');
      final smbService = SmbService();
      final success = await smbService.testConnection(profile);
      
      if (success) {
        logger.i('✅ Connection test passed, saving profile');
        setState(() {
          _profiles.add(profile);
        });
        await _saveProfiles();
        _showSnackBar('Connection added successfully');
      } else {
        logger.e('❌ Connection test failed');
        _showSnackBar('Connection test failed', isError: true);
      }
    }
  }

  Future<void> _deleteConnection(ConnectionProfile profile) async {
    logger.d('🗑️ Delete dialog opened for: ${profile.name}');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Connection'),
        content: Text('Delete connection to ${profile.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      logger.d('Deleting profile: ${profile.name}');
      setState(() {
        _profiles.remove(profile);
      });
      await _saveProfiles();
      logger.i('✅ Connection deleted: ${profile.name}');
      _showSnackBar('Connection deleted');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.selectMode ? 'Select Connection' : 'Manage Connections'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _profiles.isEmpty
              ? const Center(
                  child: Text('No connections saved.\nTap + to add one.'),
                )
              : ListView.builder(
                  itemCount: _profiles.length,
                  itemBuilder: (context, index) {
                    final profile = _profiles[index];
                    return ListTile(
                      leading: const Icon(Icons.computer),
                      title: Text(profile.name),
                      subtitle: Text('${profile.ip} - ${profile.shareName}'),
                      trailing: widget.selectMode
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteConnection(profile),
                            ),
                      onTap: () {
                        if (widget.selectMode) {
                          Navigator.pop(context, profile);
                        }
                      },
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addConnection,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _AddConnectionDialog extends StatefulWidget {
  const _AddConnectionDialog();

  @override
  State<_AddConnectionDialog> createState() => _AddConnectionDialogState();
}

class _AddConnectionDialogState extends State<_AddConnectionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ipController = TextEditingController();
  final _shareController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _ipController.dispose();
    _shareController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Connection'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Connection Name'),
                validator: (v) => v?.isEmpty == true ? 'Required' : null,
              ),
              TextFormField(
                controller: _ipController,
                decoration: const InputDecoration(labelText: 'PC IP Address'),
                validator: (v) => v?.isEmpty == true ? 'Required' : null,
              ),
              TextFormField(
                controller: _shareController,
                decoration: const InputDecoration(labelText: 'Share Name'),
                validator: (v) => v?.isEmpty == true ? 'Required' : null,
              ),
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: 'Username'),
                // validator: (v) => v?.isEmpty == true ? 'Required' : null,
              ),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                // validator: (v) => v?.isEmpty == true ? 'Required' : null,
              ),
            ],
          ),
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
              Navigator.pop(context, {
                'name': _nameController.text,
                'ip': _ipController.text,
                'share': _shareController.text,
                'username': _usernameController.text,
                'password': _passwordController.text,
              });
            }
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
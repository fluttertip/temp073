import 'dart:io';

import 'package:flutter/material.dart';
import 'local_browser_screen.dart';
import 'network_browser_screen.dart';
import '../services/permission_service.dart';
import '../utils/logger.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  bool _permissionsGranted = false;

  @override
  void initState() {
    super.initState();
    logger.d('HomeScreen initialized');
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    logger.d('🔐 Checking storage permissions...');
    final granted = await PermissionService.requestStoragePermissions();
    logger.i('✅ Permissions granted: $granted');
    setState(() {
      _permissionsGranted = granted;
    });

    if (!granted) {
      logger.w('⚠️ Storage permissions denied');
      _showPermissionDialog();
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permissions Required'),
        content: const Text(
          'FileShareApp needs storage permissions to manage files. '
          'Please grant permissions in app settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              PermissionService.openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

   Future<bool> _onWillPop() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit App?'),
        content: const Text('Do you want to exit FileShareApp?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text(
              'Exit',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    
    if (shouldExit ?? false) {
      logger.i('👋 Exiting app...');
      exit(0);
    }
    
    return false; // Prevent default back navigation
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      const LocalBrowserScreen(),
      const NetworkBrowserScreen(),
    ];

    return PopScope(
       canPop: false,
      onPopInvoked: (didPop) async {
        if (!didPop) {
          await _onWillPop();
        }
      },
      child: Scaffold(
      
        body: _permissionsGranted
            ? screens[_currentIndex]
            : Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.warning, size: 64, color: Colors.orange),
                    const SizedBox(height: 16),
                    const Text(
                      'Storage permissions required',
                      style: TextStyle(fontSize: 18),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _checkPermissions,
                      child: const Text('Grant Permissions'),
                    ),
                  ],
                ),
              ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            logger.d('📍 Navigation changed to tab: $index');
            setState(() {
              _currentIndex = index;
            });
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.phone_android),
              label: 'Local Storage',
            ),
            NavigationDestination(
              icon: Icon(Icons.computer),
              label: 'Network',
            ),
          ],
        ),
      ),
    );
  }
}

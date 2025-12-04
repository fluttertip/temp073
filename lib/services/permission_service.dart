import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static Future<bool> requestStoragePermissions() async {
    final status = await Permission.storage.status;
    
    if (status.isGranted) return true;
    
    final result = await Permission.storage.request();
    if (result.isGranted) return true;
    
    // For Android 11+
    if (await Permission.manageExternalStorage.request().isGranted) {
      return true;
    }
    
    return false;
  }

  static Future<bool> checkStoragePermissions() async {
    return await Permission.storage.isGranted ||
        await Permission.manageExternalStorage.isGranted;
  }

  static Future<void> openAppSettings() async {
    await openAppSettings();
  }
}
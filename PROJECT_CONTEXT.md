# FileShareApp - Network File Transfer Application

## Project Overview

**FileShareApp** is a Flutter-based mobile file manager that enables bidirectional file transfer between Android devices and Windows/Linux PCs over a local WiFi network using SMB (Server Message Block) protocol. It's similar to **CX Explorer** from the Play Store but focuses on network file sharing functionality.

### Core Philosophy
- **Mobile-Centric Operations**: All file operations (copy, cut, paste, rename, delete) happen on the Android device
- **PC as Storage Server**: PC acts as a passive storage server by sharing a folder
- **Local Network Only**: All transfers happen over WiFi LAN without internet dependency
- **Zero Server Setup on PC**: Only requires native OS folder sharing (no special software needed)

---

## Architecture Overview

### Technology Stack
- **Frontend**: Flutter (Dart) - Cross-platform UI
- **Backend Protocol**: SMB/CIFS (Server Message Block) via `smb_connect` package
- **Storage**: Android device's internal/external storage + PC shared folder
- **Local Storage**: SharedPreferences for saving connection profiles
- **File Handling**: Dart's `io`, `file_picker`, `path_provider` packages
- **Permissions**: `permission_handler` for Android storage access

### System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    ANDROID DEVICE (Mobile)                   │
│  ┌────────────────────────────────────────────────────────┐  │
│  │           FileShareApp (Flutter)                       │  │
│  │  ┌─────────────────────────────────────────────────┐  │  │
│  │  │ • Connection Manager                            │  │  │
│  │  │ • File Browser (Local Storage)                 │  │  │
│  │  │ • Network File Browser (PC Shared Folder)      │  │  │
│  │  │ • Clipboard (Copy/Cut/Paste Operations)        │  │  │
│  │  │ • File Operations (Cut, Copy, Paste, Delete)   │  │  │
│  │  └─────────────────────────────────────────────────┘  │  │
│  └────────────────────────────────────────────────────────┘  │
│  ┌────────────────────────────────────────────────────────┐  │
│  │     Local Storage Controller                           │  │
│  │  (Internal Storage + External SD Card)                │  │
│  └────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                            │
                    WiFi LAN │ SMB Protocol
                            │
┌─────────────────────────────────────────────────────────────┐
│         PC (Windows / Linux)                                │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  Shared Folder (e.g., C:\SharedFolder or ~/shared)     │  │
│  │  • Read Access: Mobile can view & download files       │  │
│  │  • Write Access: Mobile can upload & paste files       │  │
│  │  • Delete Access: Mobile can delete files              │  │
│  │  • Modify Access: Mobile can rename & modify files     │  │
│  └────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

---

## Key Features & Use Cases

### 1. PC-to-Mobile File Transfer
**Scenario**: User wants to transfer files from their computer to mobile device

**Process**:
```
Step 1: User places files in SharedFolder on PC
        └─ C:\SharedFolder\Documents\Report.pdf
        └─ C:\SharedFolder\Images\photo.jpg
        
Step 2: Open FileShareApp on mobile
        └─ Navigate to "Network" tab
        └─ Select saved PC connection
        
Step 3: Browse files in PC's SharedFolder
        └─ See all files from PC
        
Step 4: Download files to mobile storage
        └─ Tap download icon on file
        └─ Files saved to: /storage/emulated/0/Download/
        
Step 5: (Optional) Mobile Cut/Copy files
        └─ Can copy files within mobile storage
        └─ Can move files between folders
```

### 2. Mobile-to-PC File Transfer
**Scenario**: User wants to transfer photos/files from mobile to their computer

**Process**:
```
Step 1: User selects files on mobile device
        └─ Photos from Gallery
        └─ Documents from Files app
        
Step 2: Open FileShareApp
        └─ Navigate to "Local Storage" tab
        └─ Browse to files to transfer
        
Step 3: Copy or Cut files in app
        └─ Long-press file → "Copy" or "Cut"
        └─ File stored in app's internal clipboard
        
Step 4: Navigate to PC's shared folder
        └─ Switch to "Network" tab
        └─ Select PC connection
        └─ Browse to destination folder
        
Step 5: Paste files to PC
        └─ Paste operation uploads files
        └─ Files now available on PC
```

### 3. Advanced File Operations (ALL on Mobile)
All these operations happen within the mobile app - PC is only a storage provider:

#### Cut Operation
```
Mobile: Long-press file → "Cut"
        └─ File marked for moving (in app memory)
        └─ Navigate to destination
        └─ Paste → File moved (deleted from source)
```

#### Copy Operation
```
Mobile: Long-press file → "Copy"
        └─ File copied to clipboard (in app memory)
        └─ Navigate to destination
        └─ Paste → File duplicated at new location
```

#### Paste Operation
```
Mobile: After Copy/Cut → "Paste"
        └─ If source is local: Copies/moves to local storage
        └─ If source is PC: Downloads from PC → pastes to PC (copies)
        └─ If destination is PC: Uploads from mobile to PC
```

#### Rename
```
Mobile: Long-press file → "Rename"
        └─ Edit name locally or on PC
```

#### Delete
```
Mobile: Long-press file → "Delete"
        └─ File deleted from source (local or PC)
```

---

## Detailed System Components

### Component 1: Connection Manager
**Purpose**: Manage saved SMB connections to PC shares

**Responsibilities**:
- Store connection profiles (IP, Share name, Username, Password)
- Test connection validity before saving
- Maintain connection history using SharedPreferences
- Handle connection authentication

**Connection Profile Structure**:
```dart
{
  'name': 'My Home PC',           // User-friendly name
  'ip': '192.168.1.100',         // PC IP address on LAN
  'share': 'SharedFolder',       // Share name on PC
  'username': 'user123',         // Windows/Linux username
  'password': 'pass123',         // Windows/Linux password
}
```

### Component 2: Local File Browser
**Purpose**: Browse and manage files in Android device storage

**Key Areas**:
- `/storage/emulated/0/` - Main internal storage
- `/storage/emulated/0/Download/` - Default download folder
- `/storage/emulated/0/Documents/` - Documents folder
- `/storage/emulated/0/Pictures/` - Media folder
- External SD Card (if available)

**Operations Supported**:
- List files and folders
- Create new folders
- Rename files/folders
- Copy files
- Cut files
- Delete files

### Component 3: Network File Browser
**Purpose**: Browse PC's shared folder via SMB protocol

**Key Features**:
- Connect to PC using SMB credentials
- Navigate directory tree
- Download files
- Upload files
- Create folders on PC
- Delete files on PC
- Rename files on PC

### Component 4: Clipboard Manager (Internal)
**Purpose**: Manage cut/copy operations within the app

**Implementation**:
```dart
class ClipboardManager {
  List<String> copiedPaths = [];  // Paths of copied files
  List<String> cutPaths = [];     // Paths of cut files
  bool isCut = false;             // Whether operation is cut or copy
  String? sourceLocation;         // 'local' or 'network'
}
```

---

## Use Case Workflows

### Workflow 1: Download Multiple Photos from PC to Mobile

```
[Home Screen]
  ↓ (Add PC Connection)
[Enter PC IP: 192.168.1.100]
[Enter Share: Photos]
[Test & Save]
  ↓
[Navigate to PC Photos folder]
  ├─ vacation_2024/
  ├─ family_pics.zip
  └─ beach_sunset.jpg
  ↓
[Tap vacation_2024 folder]
  ├─ photo1.jpg
  ├─ photo2.jpg
  └─ photo3.jpg
  ↓
[Long-press photo1.jpg → Copy]
  ↓
[Navigate to Local Storage → Pictures]
  ↓
[Paste → Download starts]
  ↓
[Files appear in Pictures folder]
```

### Workflow 2: Transfer Selfies from Mobile to PC

```
[Home Screen → Local Storage]
  ↓
[Navigate to Pictures/Selfies]
  ├─ selfie_01.jpg
  ├─ selfie_02.jpg
  └─ selfie_03.jpg
  ↓
[Long-press selfie_01.jpg → Cut]
  ↓
[Navigate to Network]
  ↓
[Select PC Connection → Photos/Selfies folder]
  ↓
[Paste → Upload starts]
  ↓
[File uploaded to PC, deleted from mobile]
```

### Workflow 3: Organize Files with Cut/Copy/Paste

```
Local Storage:
├─ Downloads/
│  ├─ document.pdf
│  ├─ image.png
│  └─ video.mp4
├─ Documents/
├─ Pictures/

Workflow:
[Navigate to Downloads]
[Select: document.pdf]
[Long-press → Cut]
[Navigate to Documents]
[Paste]
└─ document.pdf moved to Documents/
```

---

## PC Setup Instructions

### Windows PC Setup

**Step 1: Create Shared Folder**
```
1. Create new folder: C:\SharedFolder
2. Right-click folder → Properties → Sharing tab
3. Click "Share..." button
4. Add your Windows user account
5. Set permissions to "Read/Write"
6. Click "Share"
```

**Step 2: Find PC IP Address**
```
1. Open Command Prompt (cmd)
2. Type: ipconfig
3. Look for "IPv4 Address" under "Ethernet adapter" or "Wireless LAN adapter"
   └─ Example: 192.168.1.100
```

**Step 3: Enable Network Discovery**
```
1. Open Settings
2. Network & Internet → Advanced network options
3. Enable "Network discovery"
4. Enable "File and printer sharing"
```

### Linux PC Setup

**Step 1: Create Shared Folder**
```bash
mkdir -p ~/shared_folder
chmod 777 ~/shared_folder
```

**Step 2: Install and Configure Samba**
```bash
sudo apt-get install samba samba-common smbclient
sudo nano /etc/samba/smb.conf
```

**Add to smb.conf**:
```ini
[shared]
  path = /home/username/shared_folder
  public = no
  writable = yes
  browseable = yes
  force user = username
```

**Step 3: Restart Samba**
```bash
sudo systemctl restart smbd
sudo systemctl restart nmbd
```

**Step 4: Find IP Address**
```bash
hostname -I
```

---

## Technical Implementation Details

### SMB Connection Flow

```dart
// 1. Initialize connection
final smbConnect = await SmbConnect.connectAuth(
  host: '192.168.1.100',      // PC IP
  domain: '',                  // Leave empty for workgroup
  username: 'pcusername',     // Windows/Linux username
  password: 'password',        // Windows/Linux password
);

// 2. Access shared folder
final share = 'SharedFolder';
final path = '/$share/';

// 3. List files
final folder = await smbConnect.file(path);
final files = await smbConnect.listFiles(folder);

// 4. Download file
final reader = await smbConnect.openRead(smbFile);
final localFile = File('/storage/emulated/0/Downloads/file.pdf');
final sink = localFile.openWrite();
await reader.pipe(sink);

// 5. Upload file
final writer = await smbConnect.openWrite(remoteSmbFile);
final bytes = await localFile.readAsBytes();
writer.add(bytes);
await writer.flush();
await writer.close();

// 6. Close connection
await smbConnect.close();
```

### File Operations Structure

```dart
// File Operation Command
abstract class FileOperation {
  String sourcePath;
  String destinationPath;
  bool isNetwork; // true if on PC, false if local
  
  Future<void> execute();
}

class CopyOperation extends FileOperation {
  // Copies file from source to destination
}

class CutOperation extends FileOperation {
  // Moves file from source to destination
}

class DeleteOperation extends FileOperation {
  // Deletes file from source
}
```

### Clipboard State Management

```dart
class AppClipboardManager {
  static final AppClipboardManager _instance = AppClipboardManager._internal();
  
  List<String> copiedFiles = [];
  List<String> cutFiles = [];
  bool isCut = false;
  String? sourceType; // 'local' or 'network'
  String? sourceShare; // For network operations
  
  void copy(List<String> paths, {String? source}) {
    copiedFiles = paths;
    cutFiles = [];
    isCut = false;
    sourceType = source;
  }
  
  void cut(List<String> paths, {String? source}) {
    cutFiles = paths;
    copiedFiles = [];
    isCut = true;
    sourceType = source;
  }
  
  void clear() {
    copiedFiles.clear();
    cutFiles.clear();
    isCut = false;
  }
}
```

---

## Permission Requirements (Android)

### Required Permissions in AndroidManifest.xml

```xml
<!-- File Storage Access -->
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.MANAGE_EXTERNAL_STORAGE" />

<!-- Network Access -->
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />

<!-- Device Information (for network discovery) -->
<uses-permission android:name="android.permission.ACCESS_LOCAL_NETWORK" />
```

### Runtime Permissions Required

```dart
[
  Permission.storage,                // Read/Write files
  Permission.manageExternalStorage,  // Manage all files (Android 11+)
  Permission.internet,               // Network access
  Permission.accessWifiState,        // Get WiFi info
]
```

---

## Data Flow Examples

### Flow 1: PC → Mobile (Download)

```
User Action: Tap Download on PC file
       ↓
Check SMB connection status
       ↓
Validate file exists on PC
       ↓
Request file size from PC
       ↓
Open SMB read stream
       ↓
Create local file in Downloads
       ↓
Stream bytes from PC → Local file
       ↓
Update progress indicator
       ↓
Close stream when complete
       ↓
Verify file hash (optional)
       ↓
Show success notification
```

### Flow 2: Mobile → PC (Upload via Paste)

```
User Action: Paste in network folder
       ↓
Check if clipboard has cut/copy files
       ↓
Validate source files exist
       ↓
Connect to PC SMB share
       ↓
For each file in clipboard:
  ├─ Read local file bytes
  ├─ Open SMB write stream for remote file
  ├─ Write bytes to remote
  ├─ Close stream
  └─ Update progress
       ↓
If CUT operation:
  └─ Delete original files from mobile
       ↓
Clear clipboard
       ↓
Refresh PC folder view
       ↓
Show success notification
```

### Flow 3: Cut/Copy Within Local Storage

```
User Action: Long-press file → Cut
       ↓
Store file path in internal clipboard
       ↓
Mark as CUT (not COPY)
       ↓
Show toast: "File cut to clipboard"
       ↓
User navigates to destination folder
       ↓
User taps Paste
       ↓
Check if destination differs from source
       ↓
Copy file to destination using File API
       ↓
Delete source file
       ↓
Clear clipboard
       ↓
Show success notification
```

---

## File Size & Performance Considerations

### Optimizations Implemented

1. **Chunked Transfer**: Large files streamed in chunks (not loaded entirely in memory)
2. **Progress Indicators**: Show real-time progress for large transfers
3. **Connection Pooling**: Reuse SMB connections for multiple operations
4. **Async Operations**: All I/O operations non-blocking
5. **Cancel Support**: Users can cancel ongoing transfers

### Typical Transfer Speeds (LAN)

```
Local Storage Copy:        50-500 MB/s (depends on device)
WiFi 5GHz SMB Transfer:    20-100 MB/s (depends on PC/router)
WiFi 2.4GHz SMB Transfer:  10-50 MB/s
```

---

## Error Handling Strategy

### Connection Errors
- **No Network**: Show "WiFi not connected" dialog
- **Wrong IP**: "PC not found on network" 
- **Wrong Credentials**: "Authentication failed"
- **Share Not Found**: "Shared folder not accessible"

### File Operation Errors
- **Insufficient Storage**: "Not enough space on device"
- **File in Use**: "File is locked by another process"
- **Permission Denied**: "You don't have permission"
- **File Corrupted**: "Error reading file"

### Recovery Mechanisms
- Retry logic for network errors
- Fallback to alternative network interfaces
- Local caching of successful connections
- Transaction-like operations (rollback on failure)

---

## Future Enhancement Possibilities

1. **Network Discovery**: Auto-discover PC on network (mDNS/Bonjour)
2. **Batch Operations**: Transfer multiple files simultaneously
3. **Compression**: ZIP files before transfer for faster speeds
4. **Sync Folder**: Auto-sync designated folders (like cloud backup)
5. **File Versioning**: Keep version history of files
6. **Search Functionality**: Search files across both local and network storage
7. **Multi-PC Support**: Connect to multiple PCs simultaneously
8. **File Preview**: Preview images/documents before download
9. **Favorite Locations**: Bookmark frequently used folders
10. **Activity Log**: Track all file operations with timestamps

---

## Summary

**FileShareApp** transforms Android into a powerful network file manager that treats a PC's shared folder as extended storage. Unlike cloud services, everything stays local on your WiFi network, ensuring:

✅ **Privacy**: No cloud uploads  
✅ **Speed**: Direct LAN transfers  
✅ **Control**: Mobile manages all operations  
✅ **Simplicity**: PC just needs folder sharing enabled  
✅ **Compatibility**: Works with Windows, Mac, Linux  

The app handles all complexity while keeping the PC setup minimal - just create a folder and share it!

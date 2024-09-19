import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WhatsApp Status Saver',
      theme: ThemeData(
        primarySwatch: Colors.green,
      ),
      home: const StatusSaverHome(),
    );
  }
}

class StatusSaverHome extends StatefulWidget {
  const StatusSaverHome({super.key});

  @override
  _StatusSaverHomeState createState() => _StatusSaverHomeState();
}

class _StatusSaverHomeState extends State<StatusSaverHome> {
  List<FileSystemEntity> _statusFiles = [];
  bool _loading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _checkPermissionsAndLoadStatuses();
  }

  Future<void> _checkPermissionsAndLoadStatuses() async {
    setState(() {
      _loading = true;
      _errorMessage = '';
    });

    PermissionStatus storageStatus = await Permission.storage.status;
    if (storageStatus.isDenied) {
      storageStatus = await Permission.storage.request();
    }

    PermissionStatus manageExternalStorageStatus = await Permission.manageExternalStorage.status;
    if (manageExternalStorageStatus.isDenied) {
      manageExternalStorageStatus = await Permission.manageExternalStorage.request();
    }

    if (storageStatus.isGranted && (manageExternalStorageStatus.isGranted || await Permission.manageExternalStorage.isRestricted)) {
      await _getStatuses();
    } else {
      setState(() {
        _loading = false;
        _errorMessage = 'Storage permission not granted. Please grant permission in app settings.';
      });
    }
  }

  Future<void> _getStatuses() async {
    try {
      List<String> possiblePaths = [
        "/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/.Statuses",
        "/storage/emulated/0/WhatsApp/Media/.Statuses",
        "/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/.Statuses"
        "/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Video/.Statuses"
      ];

      for (String path in possiblePaths) {
        Directory directory = Directory(path);
        if (await directory.exists()) {
          final files = directory.listSync();
          setState(() {
            _statusFiles = files.where((file) => 
              file.path.endsWith('.jpg') || 
              file.path.endsWith('.mp4') ||
              file.path.endsWith('.png') ||
              file.path.endsWith('.gif')
            ).toList();
            _loading = false;
          });
          if (_statusFiles.isNotEmpty) {
            return;
          }
        }
      }

      if (_statusFiles.isEmpty) {
        setState(() {
          _loading = false;
          _errorMessage = 'No status files found. Please check if you have any statuses.';
        });
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _errorMessage = 'Error: ${e.toString()}';
      });
    }
  }

  Future<void> _saveStatus(FileSystemEntity file) async {
    try {
      final appDir = await getExternalStorageDirectory();
      final savedDir = Directory('${appDir!.path}/SavedStatuses');
      if (!await savedDir.exists()) {
        await savedDir.create();
      }

      final fileName = file.path.split('/').last;
      final savedFile = File('${savedDir.path}/$fileName');
      await File(file.path).copy(savedFile.path);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Status saved successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving status: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WhatsApp Status Saver'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_errorMessage),
                      ElevatedButton(
                        onPressed: () => openAppSettings(),
                        child: const Text('Open App Settings'),
                      ),
                    ],
                  ),
                )
              : _statusFiles.isEmpty
                  ? const Center(child: Text('No statuses found'))
                  : GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.8,
                      ),
                      itemCount: _statusFiles.length,
                      itemBuilder: (context, index) {
                        final file = _statusFiles[index];
                        return Card(
                          child: Column(
                            children: [
                              Expanded(
                                child: file.path.endsWith('.jpg') || file.path.endsWith('.png')
                                    ? Image.file(File(file.path), fit: BoxFit.cover)
                                    : const Center(child: Icon(Icons.video_library)),
                              ),
                              ElevatedButton(
                                onPressed: () => _saveStatus(file),
                                child: const Text('Save'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
      floatingActionButton: FloatingActionButton(
        onPressed: _checkPermissionsAndLoadStatuses,
        child: const Icon(Icons.refresh),
      ),
    );
  }
}
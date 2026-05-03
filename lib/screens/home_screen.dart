import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:photo_manager/photo_manager.dart';

import '../services/video_service.dart';
import '../services/storage_service.dart';
import '../widgets/video_tile.dart';
import 'player_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<AssetEntity> videos = [];
  List<String> manualVideos = [];
  bool isLoading = true;
  bool permissionDenied = false; // FIX: track permission state

  @override
  void initState() {
    super.initState();
    loadAll();
  }

  Future<void> loadAll() async {
    setState(() {
      isLoading = true;
      permissionDenied = false;
    });

    try {
      // FIX: check permission result before loading
      final permission = await PhotoManager.requestPermissionExtend();
      if (permission == PermissionState.denied ||
          permission == PermissionState.restricted) {
        setState(() {
          permissionDenied = true;
          videos = [];
        });
      } else {
        videos = await VideoService.loadVideos();
      }
    } catch (_) {
      videos = [];
    }

    manualVideos = await StorageService.loadVideos();
    setState(() => isLoading = false);
  }

  Future<void> pickVideo() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.video);

    if (result != null) {
      final rawPath = result.files.single.path!;
      final normalizedPath = File(rawPath).absolute.path;

      final alreadyExists = manualVideos.any(
            (existing) => File(existing).absolute.path == normalizedPath,
      );

      if (!alreadyExists) {
        manualVideos.add(normalizedPath);
        await StorageService.saveVideos(manualVideos);
        setState(() {});
      }
    }
  }

  void openVideo(String path) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PlayerScreen(videoPath: path)),
    );
  }

  Future<void> openAsset(AssetEntity video) async {
    final file = await video.file;
    // FIX: show message if file is null instead of silently doing nothing
    if (file == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open video file')),
        );
      }
      return;
    }
    openVideo(file.path);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Player'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: loadAll),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : permissionDenied
          ? _buildPermissionDenied()
          : (videos.isEmpty && manualVideos.isEmpty)
          ? _buildEmpty()
          : _buildList(),
    );
  }

  // FIX: show permission denied state clearly
  Widget _buildPermissionDenied() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.no_photography, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Storage permission denied',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Grant permission in Settings to see your videos, or browse a file manually.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => PhotoManager.openSetting(),
              child: const Text('Open Settings'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: pickVideo,
              child: const Text('Browse Video'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.video_library, size: 80, color: Colors.grey),
          const SizedBox(height: 10),
          const Text('No videos found'),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: pickVideo,
            child: const Text('Browse Video'),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    final total = videos.length + manualVideos.length;

    return ListView.builder(
      itemCount: total + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.all(10),
            child: ElevatedButton(
              onPressed: pickVideo,
              child: const Text('Browse Video'),
            ),
          );
        }

        final i = index - 1;
        if (i < videos.length) {
          return VideoTile(
              video: videos[i], onTap: () => openAsset(videos[i]));
        } else {
          final path = manualVideos[i - videos.length];
          return VideoTile(manualPath: path, onTap: () => openVideo(path));
        }
      },
    );
  }
}

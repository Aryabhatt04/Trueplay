import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../utils/format.dart';

class VideoTile extends StatelessWidget {
  final AssetEntity? video;
  final String? manualPath;
  final VoidCallback onTap;

  const VideoTile({
    super.key,
    this.video,
    this.manualPath,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              // 🔥 THUMBNAIL
              _buildThumbnail(),

              const SizedBox(width: 10),

              // 📄 INFO
              Expanded(child: _buildInfo()),
            ],
          ),
        ),
      ),
    );
  }

  // ================= THUMB =================
  Widget _buildThumbnail() {
    if (video != null) {
      return FutureBuilder<Uint8List?>(
        future: video!.thumbnailDataWithSize(const ThumbnailSize(200, 200)),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return _placeholder();
          }

          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(
                  snapshot.data!,
                  width: 130,
                  height: 80,
                  fit: BoxFit.cover,
                ),
              ),

              // ⏱ DURATION OVERLAY
              Positioned(
                bottom: 5,
                right: 5,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  color: Colors.black87,
                  child: Text(
                    formatDuration(video!.videoDuration),
                    style: const TextStyle(fontSize: 12, color: Colors.white),
                  ),
                ),
              ),
            ],
          );
        },
      );
    }

    // 🔥 MANUAL FILE THUMB
    return Container(
      width: 130,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.video_file, size: 40),
    );
  }

  // ================= INFO =================
  Widget _buildInfo() {
    if (video != null) {
      return FutureBuilder<File?>(
        future: video!.file,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Text("Error loading file");
          }

          if (!snapshot.hasData) {
            return const Text("Loading...");
          }

          try {
            final file = snapshot.data!;
            final name = file.path.split('/').last;
            final size = (file.lengthSync() / (1024 * 1024)).toStringAsFixed(1);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 5),
                Text(
                  "$size MB",
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            );
          } catch (e) {
            return const Text("Error reading file");
          }
        },
      );
    }

    // 🔥 MANUAL FILE INFO
    try {
      final file = File(manualPath!);
      final name = file.path.split('/').last;

      // Check if file exists
      if (!file.existsSync()) {
        return const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "File not found",
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        );
      }

      final size = (file.lengthSync() / (1024 * 1024)).toStringAsFixed(1);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 5),
          Text("$size MB", style: const TextStyle(color: Colors.grey)),
        ],
      );
    } catch (e) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Error reading file",
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      );
    }
  }

  // ================= PLACEHOLDER =================
  Widget _placeholder() {
    return Container(
      width: 130,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

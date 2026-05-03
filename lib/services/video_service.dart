import 'package:photo_manager/photo_manager.dart';

class VideoService {
  static Future<List<AssetEntity>> loadVideos() async {
    final permission = await PhotoManager.requestPermissionExtend();

    if (permission == PermissionState.denied ||
        permission == PermissionState.restricted) {
      return [];
    }

    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.video,
      filterOption: FilterOptionGroup(
        videoOption: const FilterOption(
          durationConstraint:
          DurationConstraint(min: Duration(seconds: 1)),
        ),
      ),
    );

    final seen = <String>{};
    final allVideos = <AssetEntity>[];

    for (var album in albums) {
      final media = await album.getAssetListPaged(page: 0, size: 500);
      for (var asset in media) {
        // FIX: deduplicate by asset id — multiple albums return same video
        if (seen.add(asset.id)) {
          allVideos.add(asset);
        }
      }
    }

    return allVideos;
  }
}

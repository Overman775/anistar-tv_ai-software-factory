import '../../../core/services/preferences_service.dart';
import '../../home/models/video_model.dart';
import '../../home/services/video_service.dart';

/// Service for managing favorite videos
class FavoritesService {
  final PreferencesService _preferencesService;

  /// Constructor
  FavoritesService(this._preferencesService);

  /// Get list of favorite videos
  List<String> getFavoriteIds() {
    return _preferencesService.getFavoriteVideos();
  }

  /// Get list of favorite video objects
  List<VideoModel> getFavoriteVideos(VideoService videoService) {
    final favoriteIds = getFavoriteIds();
    final List<VideoModel> favoriteVideos = [];

    for (final id in favoriteIds) {
      final video = videoService.getVideoById(id);
      if (video != null) {
        favoriteVideos.add(video);
      }
    }

    return favoriteVideos;
  }

  /// Add a video to favorites
  Future<bool> addToFavorites(String videoId) {
    return _preferencesService.addToFavorites(videoId);
  }

  /// Remove a video from favorites
  Future<bool> removeFromFavorites(String videoId) {
    return _preferencesService.removeFromFavorites(videoId);
  }

  /// Check if a video is in favorites
  bool isFavorite(String videoId) {
    return _preferencesService.isFavorite(videoId);
  }

  /// Toggle favorite status of a video
  Future<bool> toggleFavorite(String videoId) {
    if (isFavorite(videoId)) {
      return removeFromFavorites(videoId);
    } else {
      return addToFavorites(videoId);
    }
  }
}

import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing application preferences
class PreferencesService {
  final SharedPreferences _preferences;

  /// Keys for preferences
  static const String _favoriteVideosKey = 'favorite_videos';

  /// Constructor
  PreferencesService(this._preferences);

  /// Get list of favorite video IDs
  List<String> getFavoriteVideos() {
    return _preferences.getStringList(_favoriteVideosKey) ?? [];
  }

  /// Add a video to favorites
  Future<bool> addToFavorites(String videoId) async {
    final favorites = getFavoriteVideos();
    if (!favorites.contains(videoId)) {
      favorites.add(videoId);
      return await _preferences.setStringList(_favoriteVideosKey, favorites);
    }
    return true;
  }

  /// Remove a video from favorites
  Future<bool> removeFromFavorites(String videoId) async {
    final favorites = getFavoriteVideos();
    if (favorites.contains(videoId)) {
      favorites.remove(videoId);
      return await _preferences.setStringList(_favoriteVideosKey, favorites);
    }
    return true;
  }

  /// Check if a video is in favorites
  bool isFavorite(String videoId) {
    return getFavoriteVideos().contains(videoId);
  }
}

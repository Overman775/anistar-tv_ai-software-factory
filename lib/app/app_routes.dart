/// Routes for the application
class AppRoutes {
  /// Home screen route
  static const String home = '/home'; // Updated path

  /// Favorites screen route
  static const String favorites = '/favorites'; // Path remains the same

  /// Movie screen route, relative to its parent (e.g., home or favorites)
  static const String movie = 'movie'; // Now expects MovieModel as extra, relative path

  /// Player screen route, relative to its parent (e.g., home or favorites)
  static const String player = 'player'; // Path for the player, relative path
}

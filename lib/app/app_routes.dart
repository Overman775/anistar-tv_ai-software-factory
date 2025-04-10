/// Routes for the application
class AppRoutes {
  /// Home screen route
  static const String home = '/home'; // Updated path

  /// Favorites screen route
  static const String favorites = '/favorites'; // Path remains the same

  /// Movie screen route with movieId parameter
  static const String movie = '/movie/:movieId'; // New route

  /// Player screen route
  static const String player = '/player'; // Path for the player

  /// Video list screen route (expects dataUrl as extra)
  static const String videoList = '/videos';

  /// Series list screen route (expects anime page url as extra)
  static const String seriesList = '/series';
}

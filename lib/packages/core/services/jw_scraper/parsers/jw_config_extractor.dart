import '../models/jw_video_info.dart';

/// Extracts video and poster URLs from JW Player config/script blocks.
class JwConfigExtractor {
  /// Parses JW Player config scripts and returns a list of [JwVideoInfo].
  ///
  /// Handles both direct file/poster fields and playlist arrays.
  List<JwVideoInfo> extractVideoInfos(List<String> jwConfigs) {
    final results = <JwVideoInfo>[];

    for (final config in jwConfigs) {
      // Try to extract the setup({ ... }) object using regex.
      final setupRegExp = RegExp(r'setup\s*\(\s*({.*?})\s*\)', dotAll: true);
      final setupMatch = setupRegExp.firstMatch(config);
      if (setupMatch == null) continue;

      final configJsonLike = setupMatch.group(1)!;

      // Use triple quotes for RegExp to avoid quote confusion.
      final fileRegExp = RegExp(r"""file\s*:\s*['"]([^'"]+)['"]""");
      final fileMatch = fileRegExp.firstMatch(configJsonLike);

      final posterRegExp = RegExp(r"""(image|poster)\s*:\s*['"]([^'"]+)['"]""");
      final posterMatch = posterRegExp.firstMatch(configJsonLike);

      if (fileMatch != null) {
        results.add(JwVideoInfo(videoUrl: fileMatch.group(1)!, posterUrl: posterMatch?.group(2)));
        continue;
      }

      // Try to extract from playlist: [{file:..., image:...}]
      final playlistRegExp = RegExp(r'playlist\s*:\s*\[(.*?)\]', dotAll: true);
      final playlistMatch = playlistRegExp.firstMatch(configJsonLike);
      if (playlistMatch != null) {
        final playlistContent = playlistMatch.group(1)!;
        final fileInPlaylistRegExp = RegExp(r"""file\s*:\s*['"]([^'"]+)['"]""");
        final fileInPlaylist = fileInPlaylistRegExp.firstMatch(playlistContent);

        final posterInPlaylistRegExp = RegExp(r"""(image|poster)\s*:\s*['"]([^'"]+)['"]""");
        final posterInPlaylist = posterInPlaylistRegExp.firstMatch(playlistContent);

        if (fileInPlaylist != null) {
          results.add(JwVideoInfo(videoUrl: fileInPlaylist.group(1)!, posterUrl: posterInPlaylist?.group(2)));
        }
      }
    }

    return results;
  }
}

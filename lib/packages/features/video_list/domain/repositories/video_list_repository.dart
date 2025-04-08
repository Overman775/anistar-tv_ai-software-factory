import '../models/page_model.dart';

/// Abstract repository for fetching video list data.
abstract class VideoListRepository {
  /// Fetches a paginated list of videos from the specified [url].
  ///
  /// The [page] parameter indicates the page number to fetch (starting from 1).
  /// The actual URL construction based on the base [url] and [page]
  /// will be handled by the implementation.
  ///
  /// Returns a [PageModel] containing the videos and pagination info,
  /// or null/throws an error if fetching fails.
  Future<PageModel?> getVideosPaginated(String url, int page);
}

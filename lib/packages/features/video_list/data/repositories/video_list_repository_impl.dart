import 'package:logger/logger.dart';

import '../../domain/models/page_model.dart';
import '../../domain/repositories/video_list_repository.dart';
import '../datasources/video_list_remote_datasource.dart';

/// Implementation of [VideoListRepository] that uses a remote data source.
class VideoListRepositoryImpl implements VideoListRepository {
  final VideoListRemoteDataSource _remoteDataSource;
  final Logger _logger;

  VideoListRepositoryImpl({required VideoListRemoteDataSource remoteDataSource, Logger? logger})
    : _remoteDataSource = remoteDataSource,
      _logger = logger ?? Logger();

  @override
  Future<PageModel?> getVideosPaginated(String url, int page) async {
    _logger.d('Repository: Fetching videos for URL: $url, Page: $page');
    try {
      // Delegate the call to the remote data source
      final pageModel = await _remoteDataSource.fetchVideoPage(url, page);
      if (pageModel != null) {
        _logger.d('Repository: Successfully fetched ${pageModel.videos.length} videos for page $page.');
      } else {
        _logger.w('Repository: Remote data source returned null for page $page.');
      }
      return pageModel;
    } catch (e, stackTrace) {
      _logger.e('Repository: Error fetching videos for page $page', error: e, stackTrace: stackTrace);
      // Re-throw the error or handle it as per the application's error strategy
      // For now, re-throwing allows higher layers (use case, BLoC) to handle it.
      rethrow;
    }
  }
}

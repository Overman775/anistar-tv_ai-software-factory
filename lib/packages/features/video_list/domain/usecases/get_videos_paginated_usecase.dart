import 'package:logger/logger.dart';

import '../models/page_model.dart';
import '../repositories/video_list_repository.dart';

/// Use case for fetching a paginated list of videos.
class GetVideosPaginatedUseCase {
  final VideoListRepository _repository;
  final Logger _logger;

  GetVideosPaginatedUseCase({required VideoListRepository repository, Logger? logger})
    : _repository = repository,
      _logger = logger ?? Logger();

  /// Executes the use case.
  ///
  /// Fetches videos from the given [url] for the specified [page].
  Future<PageModel?> call(String url, int page) async {
    _logger.d('UseCase: Executing GetVideosPaginated for URL: $url, Page: $page');
    try {
      final result = await _repository.getVideosPaginated(url, page);
      _logger.d('UseCase: Received result for page $page.');

      return result;
    } catch (e, stackTrace) {
      _logger.e('UseCase: Error executing GetVideosPaginated for page $page', error: e, stackTrace: stackTrace);
      // Re-throw to allow BLoC to handle the error state
      rethrow;
    }
  }
}

import 'package:dio/dio.dart'; // Import DioException
import 'package:html/parser.dart' show parse;
import 'package:logger/logger.dart'; // Assuming you have a logger setup

import '../packages/core/services/network_service.dart'; // Import NetworkService

/// Fetches the HTML content from the given [url] and parses the title tag.
///
/// Returns the text content of the <title> tag, or null if the request fails,
/// the content is not valid HTML, or the title tag is not found.
Future<String?> fetchHtmlTitle(String url, {Logger? logger}) async {
  try {
    // Get NetworkService instance
    final networkService = NetworkService();

    // Make request using NetworkService. Expecting HTML as String.
    // Pass the full URL directly. Dio ignores baseUrl if the path is a full URL.
    final response = await networkService.get<String>(url);

    // Dio throws DioException for non-2xx status codes by default,
    // so we can assume success if we reach here.
    final document = parse(response.data); // Use response.data for Dio
    final titleElement = document.querySelector('title');
    return titleElement?.text.trim();
  } on DioException catch (e, stackTrace) {
    // Log Dio-specific errors
    logger?.e(
      'DioError fetching HTML title for URL: $url - ${e.response?.statusCode ?? 'No Status Code'}',
      error: e,
      stackTrace: stackTrace,
    );
    return null; // Return null on Dio error
  } catch (e, stackTrace) {
    // Catch other potential errors (parsing, etc.)
    logger?.e('Error fetching or parsing HTML title for URL: $url', error: e, stackTrace: stackTrace);
    return null;
  }
}

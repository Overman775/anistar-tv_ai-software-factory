import 'package:anistar_tv/packages/core/services/html_parser_service.dart';
import 'package:html/parser.dart' show parse;
import 'package:logger/logger.dart';

import '../models/video_model.dart';

/// Service for managing videos
class VideoService {
  final HtmlParserService parser;
  final Logger logger;

  VideoService(this.parser, {Logger? logger}) : logger = logger ?? Logger();

  // Sample video data
  final List<VideoModel> _allVideos = [
    VideoModel(
      id: '1',
      title: 'Big Buck Bunny',
      description: 'Big Buck Bunny tells the story of a giant rabbit with a heart bigger than himself.',
      thumbnailUrl: Uri.parse('https://i.imgur.com/1qRXO3c.jpg'),
      videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
      duration: const Duration(minutes: 9, seconds: 56),
      category: 'Animation',
    ),
    VideoModel(
      id: '2',
      title: 'Elephant Dream',
      description: 'The first Blender Open Movie from 2006.',
      thumbnailUrl: Uri.parse('https://i.imgur.com/LoZZqLP.jpg'),
      videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
      duration: const Duration(minutes: 10, seconds: 53),
      category: 'Animation',
    ),
    VideoModel(
      id: '3',
      title: 'Sintel',
      description: 'Sintel is a fantasy computer animated short film.',
      thumbnailUrl: Uri.parse('https://i.imgur.com/J96ldqI.jpg'),
      videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4',
      duration: const Duration(minutes: 14, seconds: 48),
      category: 'Animation',
    ),
    VideoModel(
      id: '4',
      title: 'Tears of Steel',
      description:
          'Tears of Steel was realized with crowd-funding by users of the open source 3D creation tool Blender.',
      thumbnailUrl: Uri.parse('https://i.imgur.com/AmzWxXh.jpg'),
      videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/TearsOfSteel.mp4',
      duration: const Duration(minutes: 12, seconds: 14),
      category: 'Sci-Fi',
    ),
    VideoModel(
      id: '5',
      title: 'For Bigger Blazes',
      description: 'HBO GO now works with Chromecast -- get it here.',
      thumbnailUrl: Uri.parse('https://i.imgur.com/f9N0L4q.jpg'),
      videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
      duration: const Duration(minutes: 0, seconds: 15),
      category: 'Commercial',
    ),
    VideoModel(
      id: '6',
      title: 'For Bigger Escape',
      description: 'Introducing Chromecast. The easiest way to enjoy online video and music on your TV.',
      thumbnailUrl: Uri.parse('https://i.imgur.com/sohWhy9.jpg'),
      videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4',
      duration: const Duration(minutes: 0, seconds: 15),
      category: 'Commercial',
    ),
    VideoModel(
      id: '7',
      title: 'For Bigger Fun',
      description: 'Introducing Chromecast. The easiest way to enjoy online video and music on your TV.',
      thumbnailUrl: Uri.parse('https://i.imgur.com/N9Ld9W7.jpg'),
      videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4',
      duration: const Duration(minutes: 1, seconds: 0),
      category: 'Commercial',
    ),
    VideoModel(
      id: '8',
      title: 'For Bigger Joyrides',
      description: 'Introducing Chromecast. The easiest way to enjoy online video and music on your TV.',
      thumbnailUrl: Uri.parse('https://i.imgur.com/8L4qZzF.jpg'),
      videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4',
      duration: const Duration(minutes: 0, seconds: 15),
      category: 'Commercial',
    ),
    VideoModel(
      id: '9',
      title: 'For Bigger Meltdowns',
      description: 'Introducing Chromecast. The easiest way to enjoy online video and music on your TV.',
      thumbnailUrl: Uri.parse('https://i.imgur.com/UNoffsG.jpg'),
      videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerMeltdowns.mp4',
      duration: const Duration(minutes: 0, seconds: 15),
      category: 'Commercial',
    ),
    VideoModel(
      id: '10',
      title: 'Subaru Outback On Street And Dirt',
      description:
          'Smoking Tire takes the all-new Subaru Outback to the highest point we can find in hopes our customer-appreciation Balloon Launch will get some free advertising.',
      thumbnailUrl: Uri.parse('https://i.imgur.com/9z6aXyq.jpg'),
      videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/SubaruOutbackOnStreetAndDirt.mp4',
      duration: const Duration(minutes: 9, seconds: 57),
      category: 'Cars',
    ),
    VideoModel(
      id: '11',
      title: 'Volkswagen GTI Review',
      description:
          'The Smoking Tire is obsessed with the Volkswagen GTI. They take the Standard and Autobahn models with DSG and Manual transmissions to figure out which one is the best.',
      thumbnailUrl: Uri.parse('https://i.imgur.com/6dztq5f.jpg'),
      videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/VolkswagenGTIReview.mp4',
      duration: const Duration(minutes: 17, seconds: 7),
      category: 'Cars',
    ),
    VideoModel(
      id: '12',
      title: 'We Are Going On Bullrun',
      description:
          'The Smoking Tire is going on the 2010 Bullrun Live Rally in a 2011 Shelby GT500, and posting a video from the road every single day! Follow along with us @smokintire and www.thesmokingtire.com for updates.',
      thumbnailUrl: Uri.parse('https://i.imgur.com/HpgKf7l.jpg'),
      videoUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/WeAreGoingOnBullrun.mp4',
      duration: const Duration(minutes: 1, seconds: 2),
      category: 'Cars',
    ),
  ];

  /// Get a list of demo videos
  List<VideoModel> getVideos() {
    // In a real app, this would fetch from an API
    return List.from(_allVideos)..addAll(List.from(_allVideos));
  }

  /// Get a paginated list of videos
  /// [page] - The page number (starting from 1)
  /// [pageSize] - Number of videos per page
  Future<List<VideoModel>> getVideosPaginated(int page, int pageSize) async {
    List<VideoModel>? test;
    try {
      logger.i('Attempting to fetch title with Puppeteer for astar.bz...');
      page = await _fetchHtml(
        // Use the new WebView-based function
        'https://v6.astar.bz?action_skin_change=1&skin_name=new36',
        logger: logger, // Pass logger to the function for internal logging
      );
      logger.i('Successfully fetched title: ${test.toString()}');
    } catch (e, stackTrace) {
      // Catch any unexpected errors during the call itself
      logger.e('Error calling fetchHtmlTitleWithPuppeteer in VideoService', error: e, stackTrace: stackTrace);
      test = null; // Ensure test is null on error
    }

    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 800));

    // In a real app, this would fetch from an API with pagination
    final allVideos = getVideos();

    final startIndex = (page - 1) * pageSize;
    if (startIndex >= allVideos.length) {
      return [];
    }

    final endIndex = startIndex + pageSize;
    final actualEndIndex = endIndex > allVideos.length ? allVideos.length : endIndex;

    return allVideos.sublist(startIndex, actualEndIndex);
  }

  /// Check if there are more videos to load
  Future<bool> hasMoreVideos(int page, int pageSize) async {
    final allVideos = getVideos();
    return page * pageSize < allVideos.length;
  }

  /// Get a video by ID
  VideoModel? getVideoById(String id) {
    final videos = getVideos();
    try {
      return videos.firstWhere((video) => video.id == id);
    } catch (e) {
      return null;
    }
  }

  // Additional utility for fetching HTML title using HtmlParserService

  /// Fetches the HTML title from the given [url] using HtmlParserService.
  /// This method is designed to parse HTML content directly.
  /// Returns the text content of the <title> tag, or null if the operation fails.
  Future<List<VideoModel>?> _fetchHtml(String url, {Logger? logger}) async {
    final log = logger ?? Logger();
    try {
      final htmlParserService = HtmlParserService();
      final html = await htmlParserService.fetchHtml(url);
      log.i('Successfully fetched title with HtmlParserService url: $url');
      final cards = _extractVideoCardsFromHtml(html ?? '', url);
      return cards;
    } catch (e, stackTrace) {
      log.e('Error fetching title with HtmlParserService for URL: $url', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Extracts video card information from the provided HTML content.
  ///
  /// Parses the HTML string and looks for elements matching the structure
  /// of movie cards on the site (e.g., div.news). Extracts title, image URL,
  /// rating (if available), and the link to the movie page.
  ///
  /// Returns a list of [VideoModel] objects representing the found movie cards.
  /// Returns an empty list if no cards are found or if parsing fails.
  List<VideoModel> _extractVideoCardsFromHtml(String htmlContent, String baseUrl, {Logger? logger}) {
    final log = logger ?? Logger();
    final List<VideoModel> videoCards = [];

    try {
      log.t('Parsing HTML content for video cards...');
      final document = parse(htmlContent);

      // Select all news items - simplified selector for debugging
      final newsElements = document.querySelectorAll('div.news');
      log.t('Found ${newsElements.length} potential video card elements.');

      for (final element in newsElements) {
        try {
          // --- Extract Title and Link ---
          final titleElement = element.querySelector('div.news_header div.title_left a');
          final String? title = titleElement?.text.trim();
          final String? relativeLink = titleElement?.attributes['href'];

          if (title == null || title.isEmpty || relativeLink == null || relativeLink.isEmpty) {
            log.w('Skipping card: Missing title or link.');
            continue; // Skip if essential info is missing
          }
          final String absoluteLink = Uri.parse(baseUrl).resolve(relativeLink).toString();

          // --- Extract Thumbnail ---
          final imgElement = element.querySelector('div.news_avatar img.main-img');
          final String? relativeThumbnailUrl = imgElement?.attributes['src'];
          Uri? thumbnailUrl;
          if (relativeThumbnailUrl != null && relativeThumbnailUrl.isNotEmpty) {
            // Ensure the URL is absolute
            thumbnailUrl = Uri.parse(baseUrl).resolve(relativeThumbnailUrl);
          } else {
            log.w('Missing thumbnail for card: $title');
            // Assign a default/placeholder or skip, here we allow null/default handling later
            // For VideoModel, thumbnailUrl is required, so we need a placeholder or skip.
            // Let's use a placeholder for now, assuming Uri.parse won't fail with an empty string (it might).
            // A better approach might be to skip or use a real placeholder image URL.
            // Using the link itself as a fallback ID if thumbnail is missing.
            // However, VideoModel requires a Uri. Let's skip if thumbnail is missing.
            log.w('Skipping card due to missing thumbnail: $title');
            continue;
          }

          // --- Extract Rating (Optional) ---
          double? rating;
          final ratingElement = element.querySelector('div.title_right div.rating span[itemprop="ratingValue"]');
          final ratingText = ratingElement?.text.trim();
          if (ratingText != null && ratingText.isNotEmpty) {
            rating = double.tryParse(ratingText);
            if (rating == null) {
              log.w('Failed to parse rating "$ratingText" for card: $title');
            }
          }

          // --- Create VideoModel ---
          // Using link as ID and videoUrl for now. Description, duration, category are defaults.
          final video = VideoModel(
            id: absoluteLink, // Use the movie page link as a unique ID
            title: title,
            description: '', // No description available in the card
            thumbnailUrl: thumbnailUrl,
            videoUrl: absoluteLink, // Use the movie page link as the video URL for now
            duration: Duration.zero, // No duration available
            category: '', // No category available in the card
            rating: rating,
          );
          videoCards.add(video);
          log.t('Successfully extracted card: ${video.title}');
        } catch (e, stackTrace) {
          // Log error for a specific card but continue with others
          log.e('Error processing a video card element', error: e, stackTrace: stackTrace);
        }
      }
    } catch (e, stackTrace) {
      log.e('Failed to parse HTML content or extract video cards', error: e, stackTrace: stackTrace);
      // Return empty list on major parsing failure
      return [];
    }

    log.i('Finished extraction. Found ${videoCards.length} video cards.');
    return videoCards;
  }
}

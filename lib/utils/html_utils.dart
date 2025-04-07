import 'dart:async';

import 'package:anistar_tv/packages/core/services/html_parser_service.dart';
import 'package:anistar_tv/packages/core/services/network_service.dart';
import 'package:dio/dio.dart'; // Import DioException
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:html/parser.dart' show parse;
import 'package:logger/logger.dart';

/// Fetches the HTML content from the given [url] using standard HTTP request and parses the title tag.
///
/// This method is likely to be blocked by Cloudflare or similar protections.
/// Returns the text content of the <title> tag, or null if the request fails,
/// the content is not valid HTML, or the title tag is not found.
Future<String?> fetchHtmlTitleDirect(String url, {Logger? logger}) async {
  final log = logger ??= Logger(); // Use provided logger or create a default one
  try {
    // Get NetworkService instance
    final networkService = NetworkService();

    // Make request using NetworkService. Expecting HTML as String.
    log.t('Attempting direct fetch for title: $url');
    final response = await networkService.get<String>(
      url,
      options: Options(
        // Ensure we accept HTML
        headers: {
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
          // Keep the User-Agent from NetworkService or override if needed
        },
        // Set response type to plain text to parse manually
        responseType: ResponseType.plain,
      ),
    );
    log.t('Direct fetch response status: ${response.statusCode}');

    // Dio throws DioException for non-2xx status codes by default,
    // so we can assume success if we reach here.
    final document = parse(response.data); // Use response.data for Dio
    final titleElement = document.querySelector('title');
    final title = titleElement?.text.trim();
    log.t('Direct fetch extracted title: $title');
    return title;
  } on DioException catch (e, stackTrace) {
    // Log Dio-specific errors
    log.e(
      'DioError fetching HTML title directly for URL: $url - ${e.response?.statusCode ?? 'No Status Code'}',
      error: e,
      stackTrace: stackTrace,
    );
    // If it's a 403, specifically mention Cloudflare possibility
    if (e.response?.statusCode == 403) {
      log.w('Received 403 Forbidden, likely Cloudflare blocking direct access.');
    }
    return null; // Return null on Dio error
  } catch (e, stackTrace) {
    // Catch other potential errors (parsing, etc.)
    log.e('Error fetching or parsing HTML title directly for URL: $url', error: e, stackTrace: stackTrace);
    return null;
  }
}
/// Fetches the HTML title from the given [url] using a headless WebView.
/// This method is designed to bypass Cloudflare-like protections by simulating a real browser.
///
/// Returns the text content of the <title> tag, or null if the operation fails or times out.
Future<String?> fetchHtmlTitleWithWebView(
  String url, {
  Logger? logger,
  Duration timeout = const Duration(seconds: 45),
}) async {
  final log = logger ??= Logger();
  try {
    final htmlParserService = HtmlParserService();
    final title = await htmlParserService.fetchHtmlTitleWithWebView(url, timeout: timeout);
    return title;
  } catch (e, stackTrace) {
    log.e('Error fetching HTML title with WebView for URL: $url', error: e, stackTrace: stackTrace);
    return null;
  }
}
}

// Keep the original Puppeteer function commented out or remove it if definitely not needed.
/*
/// Fetches the HTML title from the given [url] using Puppeteer.
///
/// Returns the text content of the <title> tag, or null if the request fails
/// or the browser operation encounters an error.
Future<String?> fetchHtmlTitleWithPuppeteer(String url, {Logger? logger}) async {
  Browser? browser; // Declare browser outside try to ensure it's closable in finally
  final log = logger ?? globalLogger;
  try {
    log.t('Launching Puppeteer browser...');
    // Launch the browser
    // Consider adding executablePath if Chrome/Chromium isn't in the default path
    // You might need to download Chromium separately: await downloadChrome();
    browser = await puppeteer.launch(
      // Example options to potentially make detection harder (use with caution)
      // args: [
      //   '--no-sandbox',
      //   '--disable-setuid-sandbox',
      //   '--disable-infobars',
      //   '--window-position=0,0',
      //   '--ignore-certifcate-errors',
      //   '--ignore-certifcate-errors-spki-list',
      //   '--user-agent="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.114 Safari/537.36"'
      // ],
      // headless: false, // Run in non-headless mode for debugging
    );
    log.t('Puppeteer browser launched.');

    // Open a new page
    final page = await browser.newPage();
    log.t('Puppeteer new page opened.');

    // Optional: Emulate a more realistic environment
    // await page.setUserAgent('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.114 Safari/537.36');
    // await page.setViewport(DeviceViewport(width: 1920, height: 1080));

    // Navigate to the URL
    log.t('Puppeteer navigating to: $url');
    // Add timeout options if needed, e.g., timeout: Duration(seconds: 30)
    await page.goto(url, wait: Until.networkIdle); // networkIdle waits for network activity to cease
    log.t('Puppeteer navigation complete.');


    // Get the page title
    final title = await page.title;
    log.t('Fetched title with Puppeteer: $title');

    // Return the title
    return title?.trim();
  } catch (e, stackTrace) {
    // Catch potential errors (launching browser, navigation, etc.)
    log.e('Error fetching HTML title with Puppeteer for URL: $url', error: e, stackTrace: stackTrace);
    return null;
  } finally {
    // Ensure the browser is closed even if errors occur
    log.t('Closing Puppeteer browser...');
    await browser?.close();
    log.t('Puppeteer browser closed.');
  }
}
*/

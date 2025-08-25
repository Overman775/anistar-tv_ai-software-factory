import 'dart:async';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:logger/logger.dart';

/// A service class for parsing HTML content using a headless WebView.
class HtmlParserService {
  final Logger logger;
  HeadlessInAppWebView? _headlessWebView;

  HtmlParserService({Logger? logger}) : logger = logger ?? Logger();

  Future<HeadlessInAppWebView> getWebView() async {
    if (_headlessWebView == null || !(_headlessWebView?.isRunning() ?? false)) {
      logger.i('Initializing Headless WebView');
      final newWebView = HeadlessInAppWebView(
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true, // Essential for Cloudflare checks
          domStorageEnabled: true,
          databaseEnabled: true,
          clearCache: false, // Start fresh each time
          cacheEnabled: true,
          blockNetworkImage: true,
          blockNetworkLoads: false,
          mediaPlaybackRequiresUserGesture: true,
        ),
        onConsoleMessage: (controller, consoleMessage) {
          logger.d('WebView Console [${consoleMessage.messageLevel}]: ${consoleMessage.message}');
        },
      );
      _headlessWebView = newWebView;
      await newWebView.run();
      logger.t('Headless WebView is running.');
    }
    final webView = _headlessWebView;
    if (webView != null) {
      return webView;
    } else {
      throw StateError('Headless WebView failed to initialize.');
    }
  }

  Future<void> navigate(String url) async {
    final headlessWebView = await getWebView();
    final controller = headlessWebView.webViewController;

    if (controller == null) {
      logger.e('WebView controller is null for URL: $url');

      return;
    }

    logger.i('Loading URL in WebView: $url');
    await controller.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
    logger.i('Finished loading URL in WebView: $url');

    // Wait for the page to load and potential JS challenges to complete
    // This part might need refinement based on specific website behavior
    await Future<void>.delayed(const Duration(seconds: 3));
    logger.i('Waited for 3 seconds for page to load.');
  }

  /// Fetches the HTML from the given [url] using a headless WebView.
  Future<String?> fetchHtml(String url) async {
    logger.i('Attempting to fetch HTML for URL: $url');
    try {
      final headlessWebView = await getWebView();
      final controller = headlessWebView.webViewController;

      if (controller == null) {
        logger.e('WebView controller is null for URL: $url');

        return null;
      }

      await navigate(url);

      logger.i('Attempting to get HTML from WebView.');
      final String? result = await controller.getHtml();
      logger.i('Finished getting HTML from WebView.');

      if (result is String) {
        final text = result.trim();
        if (text.isNotEmpty) {
          logger.i('Successfully fetched HTML for URL: $url');

          return text;
        } else {
          logger.w('Fetched HTML is empty for URL: $url');

          return null;
        }
      } else {
        logger.w('WebView returned non-string result for URL: $url - $result');

        return null;
      }
    } catch (e, stackTrace) {
      logger.e('Error fetching HTML with WebView for URL: $url', error: e, stackTrace: stackTrace);

      return null;
    }
  }

  /// Disposes the headless WebView.
  void dispose() {
    logger.i('Attempting to dispose Headless WebView.');
    if (_headlessWebView?.isRunning() ?? false) {
      _headlessWebView?.dispose();
      _headlessWebView = null;
      logger.t('Headless WebView disposed successfully.');
    } else {
      logger.i('Headless WebView is not running or already disposed.');
    }
  }
}

// lib/packages/core/services/html_parser_service.dart

import 'dart:async';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:logger/logger.dart';

/// A service class for parsing HTML content using a headless WebView.
class HtmlParserService {
  final Logger logger;

  HtmlParserService({Logger? logger}) : logger = logger ?? Logger();

  /// Fetches the HTML from the given [url] using a headless WebView.
  Future<String?> fetchHtml(String url, {Duration timeout = const Duration(seconds: 45)}) async {
    final completer = Completer<String?>();
    HeadlessInAppWebView? headlessWebView;

    // Timeout mechanism
    final timer = Timer(timeout, () {
      if (!completer.isCompleted) {
        logger.w('WebView fetch timed out for URL: $url after ${timeout.inSeconds} seconds.');
        completer.complete(null);
        headlessWebView?.dispose(); // Attempt to clean up
      }
    });

    try {
      logger.i('Initializing Headless WebView for: $url');
      headlessWebView = HeadlessInAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(url)),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true, // Essential for Cloudflare checks
          domStorageEnabled: true,
          databaseEnabled: true,
          clearCache: true, // Start fresh each time
          cacheEnabled: false,
        ),
        onLoadStop: (controller, loadedUrl) async {
          if (completer.isCompleted) return; // Already timed out or completed

          logger.t('WebView finished loading: ${loadedUrl ?? 'unknown URL'}');
          try {
            // Wait a brief moment for potential JS challenges to complete
            await Future.delayed(const Duration(seconds: 3));

            // // Execute JavaScript to get the document content
            // final dynamic result = await controller.evaluateJavascript(source: js);

            final dynamic result = await controller.getHtml();

            if (result is String) {
              final text = result.trim();
              logger.i('Successfully fetched with WebView: $text');
              if (!completer.isCompleted) {
                completer.complete(text.isNotEmpty ? text : null);
              }
            } else {
              logger.w('WebView returned non-string: $result');
              if (!completer.isCompleted) {
                completer.complete(null);
              }
            }
          } catch (e, stackTrace) {
            logger.e('Error evaluating JS in WebView', error: e, stackTrace: stackTrace);
            if (!completer.isCompleted) {
              completer.complete(null);
            }
          } finally {
            headlessWebView?.dispose(); // Clean up after getting title or error
          }
        },
        onLoadError: (controller, uri, code, message) {
          if (completer.isCompleted) return;
          logger.e('WebView onLoadError for $uri: Code $code - $message');
          if (!completer.isCompleted) {
            completer.complete(null);
          }
          headlessWebView?.dispose();
        },
        onReceivedHttpError: (controller, request, errorResponse) async {
          if (completer.isCompleted) return;
          logger.w(
            'WebView received HTTP error for ${request.url}: ${errorResponse.statusCode} ${errorResponse.reasonPhrase}',
          );
        },
        onConsoleMessage: (controller, consoleMessage) {
          logger.d('WebView Console [${consoleMessage.messageLevel}]: ${consoleMessage.message}');
        },
      );

      logger.t('Running Headless WebView...');
      await headlessWebView.run();

      // Wait for the completer (either success, error, or timeout)
      final result = await completer.future;
      return result;
    } catch (e, stackTrace) {
      logger.e('Error initializing or running Headless WebView for URL: $url', error: e, stackTrace: stackTrace);
      if (!completer.isCompleted) {
        completer.complete(null); // Ensure completer finishes on exception
      }
      return null;
    } finally {
      timer.cancel(); // Cancel the timeout timer
      await Future.delayed(const Duration(milliseconds: 100));
      if (headlessWebView?.isRunning() ?? false) {
        headlessWebView?.dispose();
        logger.t('WebView disposed in finally block.');
      }
    }
  }
}

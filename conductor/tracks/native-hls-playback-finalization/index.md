# Native HLS playback finalization

The application has no WebView implementation. Playback exclusively uses the parser's short-lived HLS manifest through Flutter's native `video_player` platform backends. A retry always creates a new parser session, so an expired HLS resource URL is not reused.

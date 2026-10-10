import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

void main() {
  test('unit tests reject HTTP client creation before any socket opens', () {
    expect(HttpClient.new, throwsStateError);
  });

  testWidgets('widget tests keep HTTP isolated and restore their TV view', (tester) async {
    expect(HttpClient.new, throwsStateError);
    await pumpTvApp(tester, const SizedBox.shrink(), size: wideTvSize);
    expect(tester.view.physicalSize, wideTvSize);
    expect(tester.view.devicePixelRatio, 1);
  });
}

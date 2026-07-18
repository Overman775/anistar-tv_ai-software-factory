import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui_kit/ui_kit.dart';

void main() {
  testWidgets('places child content over the TV background', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(body: TvBackdrop(child: Text('Каталог'))),
      ),
    );

    expect(find.text('Каталог'), findsOneWidget);
    expect(find.byType(Stack), findsAtLeastNWidgets(1));
  });
}

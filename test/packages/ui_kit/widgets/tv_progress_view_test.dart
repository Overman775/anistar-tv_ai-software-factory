import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui_kit/ui_kit.dart';

void main() {
  testWidgets('renders the TV progress state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(body: TvProgressView(label: 'Загружаем каталог…')),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Загружаем каталог…'), findsOneWidget);
  });
}

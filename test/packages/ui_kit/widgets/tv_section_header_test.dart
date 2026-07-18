import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui_kit/ui_kit.dart';

void main() {
  testWidgets('renders a title, optional subtitle and trailing content', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(
          body: TvSectionHeader(title: 'Серии', subtitle: 'Все доступные выпуски', trailing: Text('12')),
        ),
      ),
    );

    expect(find.text('Серии'), findsOneWidget);
    expect(find.text('Все доступные выпуски'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
  });
}

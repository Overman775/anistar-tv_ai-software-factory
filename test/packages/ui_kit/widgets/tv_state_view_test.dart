import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui_kit/ui_kit.dart';

void main() {
  testWidgets('renders a polished state and invokes its action', (tester) async {
    var actionCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: TvBackdrop(
            child: TvStateView(
              icon: Icons.cloud_off_rounded,
              title: 'Каталог недоступен',
              message: 'Проверьте подключение',
              actionLabel: 'Попробовать снова',
              onAction: () => actionCalls++,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Каталог недоступен'), findsOneWidget);
    expect(find.text('Проверьте подключение'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);

    await tester.tap(find.text('Попробовать снова'));

    expect(actionCalls, 1);
  });
}

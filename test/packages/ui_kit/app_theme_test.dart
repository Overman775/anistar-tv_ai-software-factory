import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

void main() {
  for (final (name, theme) in [('dark', AppTheme.darkTheme), ('light', AppTheme.lightTheme)]) {
    testWidgets('$name primary buttons retain text contrast in interactive states', (tester) async {
      late ButtonStyle style;
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Builder(
            builder: (context) {
              final button = FilledButton(onPressed: () => fail('Unexpected activation'), child: const Text('Войти'));
              final defaultStyle = button.defaultStyleOf(context);
              style = theme.filledButtonTheme.style?.merge(defaultStyle) ?? defaultStyle;

              return Scaffold(body: button);
            },
          ),
        ),
      );
      for (final states in [
        <WidgetState>{},
        {WidgetState.focused},
        {WidgetState.hovered},
        {WidgetState.pressed},
      ]) {
        final foreground = style.foregroundColor?.resolve(states) ?? (throw StateError('Missing foreground'));
        final background = style.backgroundColor?.resolve(states) ?? (throw StateError('Missing background'));
        final overlay = style.overlayColor?.resolve(states) ?? Colors.transparent;
        final effectiveBackground = Color.alphaBlend(overlay, background);
        final foregroundLuminance = foreground.computeLuminance();
        final backgroundLuminance = effectiveBackground.computeLuminance();
        final contrast = foregroundLuminance > backgroundLuminance
            ? (foregroundLuminance + 0.05) / (backgroundLuminance + 0.05)
            : (backgroundLuminance + 0.05) / (foregroundLuminance + 0.05);
        expect(contrast, greaterThanOrEqualTo(4.5), reason: '$name $states');
        debugPrint('POLISH $name $states primary text contrast: ${contrast.toStringAsFixed(2)}:1');
      }
      // Shared AppFocusBorder owns the outline; native button sides cannot duplicate it.
      expect(style.side?.resolve({WidgetState.focused})?.width, 0);
      expect(tester.takeException(), isNull);
    });
  }
}

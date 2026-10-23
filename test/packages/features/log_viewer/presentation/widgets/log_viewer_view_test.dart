import 'package:anistar_tv/packages/features/log_viewer/presentation/bloc/log_viewer_bloc.dart';
import 'package:anistar_tv/packages/features/log_viewer/presentation/widgets/log_viewer_view.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../../../../mocks/features/log_viewer/fake_log_repository.dart';
import '../../../../../support/test_app.dart';

void main() {
  testWidgets('renders loading, empty and unavailable states from the supplied bloc', (tester) async {
    final loading = LogViewerBloc(repository: FakeLogRepository(loadFiles: () async => <String>[]));
    addTearDown(loading.close);
    await _pumpView(tester, loading);
    expect(find.text('Загружаем логи…'), findsOneWidget);
    loading.add(const LogViewerStartedEvent());
    await tester.pumpAndSettle();
    expect(find.text('Создайте несколько логов'), findsOneWidget);

    var unavailable = true;
    final failed = LogViewerBloc(
      repository: FakeLogRepository(
        loadFiles: () async {
          if (unavailable) {
            throw StateError('unavailable');
          }

          return ['recovered.log'];
        },
      ),
    );
    addTearDown(failed.close);
    await _pumpView(tester, failed);
    failed.add(const LogViewerStartedEvent());
    await tester.pumpAndSettle();
    expect(find.text('Логи недоступны'), findsOneWidget);
    expect(find.widgetWithText(AppButton, 'Обновить'), findsOneWidget);
    unavailable = false;
    await tester.tap(find.widgetWithText(AppButton, 'Обновить'));
    await tester.pumpAndSettle();
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
  });

  testWidgets('selects content, refreshes, scrolls and shares through the platform channel', (tester) async {
    var loads = 0;
    final bloc = LogViewerBloc(
      repository: FakeLogRepository(
        loadFiles: () async {
          loads++;

          return ['latest.log'];
        },
        loadContent: (_) async => List.filled(120, 'line').join('\n'),
      ),
    );
    addTearDown(bloc.close);
    final calls = <MethodCall>[];
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    const channel = MethodChannel('dev.fluttercommunity.plus/share');
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);

      return 'dev.fluttercommunity.plus/share/unavailable';
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    await _pumpView(tester, bloc);
    bloc.add(const LogViewerStartedEvent());
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('latest.log').last);
    await tester.pumpAndSettle();
    final content = List.filled(120, 'line').join('\n');
    final text = tester.widget<SelectableText>(find.byType(SelectableText));
    expect(text.data, content);
    final scroll =
        tester.widget<SingleChildScrollView>(find.byType(SingleChildScrollView)).controller ??
        (throw TestFailure('Log content must own its scroll controller.'));
    expect(scroll.offset, greaterThan(0));
    await tester.tap(find.byTooltip('В начало'));
    await tester.pumpAndSettle();
    expect(scroll.offset, 0);
    await tester.tap(find.byTooltip('В конец'));
    await tester.pumpAndSettle();
    expect(scroll.offset, greaterThan(0));
    await tester.tap(find.byTooltip('Поделиться логом'));
    await tester.pump();
    expect(calls.single.method, 'share');
    expect(calls.single.arguments, containsPair('text', content));
    expect(calls.single.arguments, containsPair('subject', 'Log File: latest.log'));
    await tester.tap(find.byTooltip('Обновить логи'));
    await tester.pumpAndSettle();
    expect(loads, 2);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets('Back leaves the viewer route', (tester) async {
    final bloc = LogViewerBloc(repository: FakeLogRepository());
    addTearDown(bloc.close);
    await pumpTvApp(
      tester,
      Builder(
        builder: (context) => AppButton(
          label: 'Open logs',
          onPressed: () => Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => BlocProvider.value(value: bloc, child: const LogViewerView()),
            ),
          ),
        ),
      ),
      wrapInScaffold: false,
    );
    await tester.tap(find.text('Open logs'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byTooltip('Назад'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Open logs'), findsOneWidget);
  });
}

Future<void> _pumpView(WidgetTester tester, LogViewerBloc bloc) =>
    pumpTvApp(tester, BlocProvider.value(value: bloc, child: const LogViewerView()), wrapInScaffold: false);

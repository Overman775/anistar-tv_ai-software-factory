import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';
import 'package:ui_kit/ui_kit.dart';

import '../bloc/log_viewer_bloc.dart';

class LogViewerView extends StatefulWidget {
  const LogViewerView({super.key});

  @override
  State<LogViewerView> createState() => _LogViewerViewState();
}

class _LogViewerViewState extends State<LogViewerView> {
  final ScrollController _scrollController = ScrollController();

  Widget _buildBody(BuildContext context, LogViewerState state) => switch (state) {
    LogViewerInitialState() || LogViewerLoadingState() => const TvProgressView(label: 'Загружаем логи…'),
    LogViewerLoadedState() => _buildLoadedBody(context, state),
    LogViewerErrorState() => TvStateView(
      icon: Icons.folder_off_outlined,
      title: 'Логи недоступны',
      message: state.message,
      actionLabel: 'Обновить',
      onAction: () => _refreshLogs(context),
    ),
  };

  Widget _buildFloatingActions(BuildContext context, LogViewerState state) {
    if (state is! LogViewerLoadedState || state.logContent == null) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        FloatingActionButton(
          heroTag: 'log-viewer-scroll-top',
          mini: true,
          backgroundColor: AppPalette.surfaceElevated,
          onPressed: _scrollToTop,
          tooltip: 'В начало',
          child: const AppIcon(AppIconType.arrowUp),
        ),
        const SizedBox(height: 8),
        FloatingActionButton(
          heroTag: 'log-viewer-scroll-bottom',
          mini: true,
          backgroundColor: AppPalette.surfaceElevated,
          onPressed: _scrollToBottom,
          tooltip: 'В конец',
          child: const AppIcon(AppIconType.arrowDown),
        ),
      ],
    );
  }

  Widget _buildLoadedBody(BuildContext context, LogViewerLoadedState state) {
    final error = state.error;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.lg),
      child: Column(
        children: [
          if (state.logFiles.isNotEmpty)
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Файл лога', prefixIcon: AppIcon(AppIconType.list)),
              initialValue: state.selectedLogFile,
              hint: const Text('Выберите файл'),
              isExpanded: true,
              items: state.logFiles
                  .map(
                    (value) => DropdownMenuItem<String>(
                      value: value,
                      child: Text(value, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (value) => _selectLog(context, value),
            ),
          if (error != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: AppSpacing.md),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer.withValues(alpha: 0.72),
                borderRadius: AppRadii.medium,
              ),
              child: Text(error, style: TextStyle(color: colorScheme.onErrorContainer)),
            ),
          Expanded(child: _buildLogContent(state)),
        ],
      ),
    );
  }

  Widget _buildLogContent(LogViewerLoadedState state) {
    final content = state.logContent;
    final isLogListEmpty = state.logFiles.isEmpty;
    if (content != null) {
      return Scrollbar(
        thumbVisibility: true,
        controller: _scrollController,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: AppSpacing.md),
          decoration: BoxDecoration(
            color: AppPalette.background,
            borderRadius: AppRadii.large,
            border: Border.fromBorderSide(BorderSide(color: AppPalette.outline.withValues(alpha: 0.72))),
          ),
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: SelectableText(
              content,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                height: 1.55,
                color: AppPalette.textPrimary,
              ),
            ),
          ),
        ),
      );
    }
    if (state.selectedLogFile != null && state.error == null) {
      return const TvProgressView(label: 'Открываем файл…');
    }

    return TvStateView(
      icon: Icons.description_outlined,
      title: isLogListEmpty ? 'Создайте несколько логов' : 'Выберите файл',
      message: isLogListEmpty ? null : 'Содержимое выбранного лога появится здесь.',
    );
  }

  Widget _buildShareAction(BuildContext context, LogViewerState state) {
    if (state is! LogViewerLoadedState || state.selectedLogFile == null || state.logContent == null) {
      return const SizedBox.shrink();
    }

    return IconButton(
      icon: const AppIcon(AppIconType.share),
      tooltip: 'Поделиться логом',
      onPressed: () => _shareLog(context, state),
    );
  }

  void _handleStateChanged(BuildContext context, LogViewerState state) {
    if (state is LogViewerLoadedState && state.logContent != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  void _refreshLogs(BuildContext context) {
    context.read<LogViewerBloc>().add(const LogViewerStartedEvent());
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) {
      return;
    }

    unawaited(
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: AppMotion.durationOf(context, AppMotion.fast),
        curve: AppMotion.enterCurve,
      ),
    );
  }

  void _scrollToTop() {
    if (!_scrollController.hasClients) {
      return;
    }

    unawaited(
      _scrollController.animateTo(
        0,
        duration: AppMotion.durationOf(context, AppMotion.fast),
        curve: AppMotion.enterCurve,
      ),
    );
  }

  void _selectLog(BuildContext context, String? fileName) {
    if (fileName != null) {
      context.read<LogViewerBloc>().add(LogFileSelectedEvent(fileName));
    }
  }

  void _shareLog(BuildContext context, LogViewerLoadedState state) {
    final content = state.logContent;
    final fileName = state.selectedLogFile;
    if (content == null || fileName == null) {
      return;
    }

    final renderObject = context.findRenderObject();
    final origin = renderObject is RenderBox ? renderObject.localToGlobal(Offset.zero) & renderObject.size : null;
    unawaited(
      SharePlus.instance.share(ShareParams(text: content, subject: 'Log File: $fileName', sharePositionOrigin: origin)),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      toolbarHeight: 76,
      leading: IconButton(
        tooltip: 'Назад',
        icon: const AppIcon(AppIconType.arrowLeft),
        onPressed: () => unawaited(Navigator.of(context).maybePop()),
      ),
      title: Text('Логи приложения', style: Theme.of(context).textTheme.headlineSmall),
      actions: [
        BlocBuilder<LogViewerBloc, LogViewerState>(
          buildWhen: (previous, current) => previous != current,
          builder: _buildShareAction,
        ),
        IconButton(
          icon: const AppIcon(AppIconType.refresh),
          tooltip: 'Обновить логи',
          onPressed: () => _refreshLogs(context),
        ),
        const SizedBox(width: AppSpacing.md),
      ],
    ),
    body: TvBackdrop(
      child: BlocConsumer<LogViewerBloc, LogViewerState>(
        listenWhen: (previous, current) => previous != current,
        buildWhen: (previous, current) => previous != current,
        listener: _handleStateChanged,
        builder: _buildBody,
      ),
    ),
    floatingActionButton: BlocBuilder<LogViewerBloc, LogViewerState>(
      buildWhen: (previous, current) => previous != current,
      builder: _buildFloatingActions,
    ),
  );
}

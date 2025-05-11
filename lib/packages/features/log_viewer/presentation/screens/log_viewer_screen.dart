import 'package:anistar_tv/packages/features/log_viewer/presentation/cubit/log_viewer_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';

class LogViewerScreen extends StatelessWidget {
  const LogViewerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Assuming LogService is available via Provider or passed to the cubit constructor already
    // If LogService needs to be accessed directly here for sharing, adjust accordingly.
    // For simplicity, we'll assume the cubit handles all LogService interactions.
    return BlocProvider(
      create: (context) => LogViewerCubit(), // LogService is no longer injected
      child: const _LogViewerScreenView(),
    );
  }
}

class _LogViewerScreenView extends StatefulWidget {
  const _LogViewerScreenView();

  @override
  State<_LogViewerScreenView> createState() => _LogViewerScreenViewState();
}

class _LogViewerScreenViewState extends State<_LogViewerScreenView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0.0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log Viewer'),
        actions: [
          BlocBuilder<LogViewerCubit, LogViewerState>(
            builder: (context, state) {
              if (state is LogViewerLoaded && state.selectedLogFile != null && state.logContent != null) {
                return IconButton(
                  icon: const Icon(Icons.share),
                  tooltip: 'Share Log',
                  onPressed: () async {
                    final box = context.findRenderObject() as RenderBox?;
                    // Create a temporary file to share
                    // This part might need path_provider and dart:io if LogService doesn't expose a direct file path
                    // For now, we share the content directly.
                    // If sharing the file is a must, LogService needs to provide file path or File object.
                    await Share.share(
                      state.logContent!,
                      subject: 'Log File: ${state.selectedLogFile}',
                      sharePositionOrigin: box!.localToGlobal(Offset.zero) & box.size,
                    );
                  },
                );
              }
              return const SizedBox.shrink();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Logs',
            onPressed: () {
              context.read<LogViewerCubit>().fetchLogFiles();
            },
          ),
        ],
      ),
      body: BlocConsumer<LogViewerCubit, LogViewerState>(
        listener: (context, state) {
          if (state is LogViewerLoaded && state.logContent != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
          }
        },
        builder: (context, state) {
          if (state is LogViewerInitial || state is LogViewerLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is LogViewerLoaded) {
            return Column(
              children: [
                if (state.logFiles.isEmpty && state.error == null)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: Text('No log files found or accessible.')),
                  ),
                if (state.logFiles.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Select Log File', border: OutlineInputBorder()),
                      value: state.selectedLogFile,
                      hint: const Text('Select a log file'),
                      isExpanded: true,
                      items:
                          state.logFiles.map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value, overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          context.read<LogViewerCubit>().loadLogContent(newValue);
                        }
                      },
                    ),
                  ),
                if (state.error != null)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(state.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ),
                Expanded(
                  child:
                      (state.selectedLogFile != null && state.logContent != null)
                          ? Scrollbar(
                            thumbVisibility: true,
                            controller: _scrollController,
                            child: SingleChildScrollView(
                              controller: _scrollController,
                              padding: const EdgeInsets.all(16.0),
                              child: SelectableText(
                                state.logContent!,
                                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                              ),
                            ),
                          )
                          : (state.selectedLogFile != null && state.logContent == null && state.error == null)
                          ? const Center(child: Text('Loading log content...'))
                          : Center(
                            child: Text(
                              state.logFiles.isEmpty
                                  ? 'Create some logs first.'
                                  : 'Select a log file to view its content.',
                            ),
                          ),
                ),
              ],
            );
          } else if (state is LogViewerError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Error: ${state.message}', style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            );
          }
          return const Center(child: Text('Something went wrong.'));
        },
      ),
      floatingActionButton: BlocBuilder<LogViewerCubit, LogViewerState>(
        builder: (context, state) {
          if (state is LogViewerLoaded && state.logContent != null) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FloatingActionButton(
                  mini: true,
                  onPressed: _scrollToTop,
                  tooltip: 'Scroll to Top',
                  child: const Icon(Icons.arrow_upward),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  mini: true,
                  onPressed: _scrollToBottom,
                  tooltip: 'Scroll to Bottom',
                  child: const Icon(Icons.arrow_downward),
                ),
              ],
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

import 'package:anistar_tv/packages/features/log_viewer/data/repositories/file_log_repository.dart';
import 'package:anistar_tv/packages/features/log_viewer/presentation/bloc/log_viewer_bloc.dart';
import 'package:anistar_tv/packages/features/log_viewer/presentation/widgets/log_viewer_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class LogViewerScreen extends StatelessWidget {
  const LogViewerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LogViewerBloc(repository: const FileLogRepository())..add(const LogViewerStartedEvent()),
      child: const LogViewerView(),
    );
  }
}

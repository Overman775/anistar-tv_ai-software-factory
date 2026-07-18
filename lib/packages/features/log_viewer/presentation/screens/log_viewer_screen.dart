import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/repositories/file_log_repository.dart';
import '../bloc/log_viewer_bloc.dart';
import '../widgets/log_viewer_view.dart';

class LogViewerScreen extends StatelessWidget {
  const LogViewerScreen({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => LogViewerBloc(repository: const FileLogRepository())..add(const LogViewerStartedEvent()),
    child: const LogViewerView(),
  );
}

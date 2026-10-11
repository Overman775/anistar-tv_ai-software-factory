import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../log_viewer_providers.dart';
import '../bloc/log_viewer_bloc.dart';
import '../widgets/log_viewer_view.dart';

class LogViewerScreen extends ConsumerWidget {
  const LogViewerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => BlocProvider(
    create: (_) => LogViewerBloc(repository: ref.watch(logRepositoryProvider))..add(const LogViewerStartedEvent()),
    child: const LogViewerView(),
  );
}

import 'package:app_logging/app_logging.dart';

final class CapturingLogOutput extends LogOutput {
  final messages = <Object?>[];
  final errors = <Object?>[];

  @override
  void output(OutputEvent event) {
    messages.add(event.origin.message);
    errors.add(event.origin.error);
  }
}

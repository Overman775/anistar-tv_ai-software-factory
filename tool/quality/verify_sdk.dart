import 'dart:convert';
import 'dart:io';

/// Keeps local and CI checks on the same SDK, including golden generation.
Future<void> main() async {
  final Object? config = jsonDecode(File('.fvmrc').readAsStringSync());
  final Object? sdk = jsonDecode(await stdin.transform(utf8.decoder).join());
  if (config is! Map<String, Object?> || sdk is! Map<String, Object?>) {
    stderr.writeln('Invalid FVM configuration or Flutter version output.');
    exitCode = 1;

    return;
  }
  final expected = config['flutter'];
  final actual = sdk['frameworkVersion'];
  if (expected is! String || expected != actual) {
    stderr.writeln('Flutter SDK mismatch: expected $expected, found $actual. Run fvm install.');
    exitCode = 1;

    return;
  }
  stdout.writeln('Quality checks: Flutter $actual');
}

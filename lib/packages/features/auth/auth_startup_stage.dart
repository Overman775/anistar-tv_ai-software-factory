import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AuthStartupStage { site, session, complete }

final authStartupStageProvider = NotifierProvider<AuthStartupProgress, AuthStartupStage>(AuthStartupProgress.new);

/// Tracks restoration separately from a submitted login attempt.
final class AuthStartupProgress extends Notifier<AuthStartupStage> {
  AuthStartupStage get stage => state;
  set stage(AuthStartupStage value) => state = value;

  @override
  AuthStartupStage build() => AuthStartupStage.site;
}

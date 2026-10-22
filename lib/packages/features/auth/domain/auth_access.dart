import 'package:core/data.dart';
import 'package:meta/meta.dart';

/// Mutually exclusive access modes. A missing account is not a guest choice.
sealed class AuthAccess {
  String? get account => null;
  bool get canBrowse => this is AnonymousAccess || this is AuthenticatedAccess;
  bool get canUseAccount => this is AuthenticatedAccess;

  const AuthAccess();
}

final class UnknownAccess extends AuthAccess {
  const UnknownAccess();
}

final class UnauthenticatedAccess extends AuthAccess {
  const UnauthenticatedAccess();
}

final class AnonymousAccess extends AuthAccess {
  const AnonymousAccess();
}

final class AuthenticatedAccess extends AuthAccess {
  @override
  final String account;

  const AuthenticatedAccess(this.account);
}

/// Navigation intent belongs to the same owner as access, while AsyncValue
/// describes the operation lifecycle independently of these access modes.
enum AuthOperation { idle, signingIn, cancellingSignIn, cancellationFailed }

@immutable
final class AuthSessionState {
  final AuthAccess access;
  final bool loginRequested;
  final AuthOperation operation;
  final Failure? signInFailure;
  final Failure? cancellationFailure;

  bool get isSigningIn => operation == AuthOperation.signingIn;
  bool get isCancellingSignIn => operation == AuthOperation.cancellingSignIn;
  bool get requiresCancellation => isCancellingSignIn || operation == AuthOperation.cancellationFailed;

  const AuthSessionState(
    this.access, {
    this.loginRequested = false,
    this.operation = AuthOperation.idle,
    this.signInFailure,
    this.cancellationFailure,
  });
}

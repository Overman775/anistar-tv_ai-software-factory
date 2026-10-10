/// A safe, user-facing error at a repository boundary.
abstract class Failure implements Exception {
  final Object? cause;
  final String message;
  final StackTrace? stackTrace;

  const Failure(this.message, {this.cause, this.stackTrace});

  @override
  String toString() => message;
}

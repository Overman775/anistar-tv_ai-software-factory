sealed class Failure implements Exception {
  final Object? cause;
  final String message;
  final StackTrace? stackTrace;

  const Failure(this.message, {this.cause, this.stackTrace});

  @override
  String toString() => message;
}

final class TimeoutFailure extends Failure {
  const TimeoutFailure({super.cause, super.stackTrace}) : super('Превышено время ожидания ответа сервера.');
}

final class ConnectionFailure extends Failure {
  const ConnectionFailure({super.cause, super.stackTrace}) : super('Не удалось подключиться к серверу.');
}

final class RequestFailure extends Failure {
  const RequestFailure({required String message, super.cause, super.stackTrace}) : super(message);
}

final class ServerFailure extends Failure {
  const ServerFailure({super.cause, super.stackTrace}) : super('Сервер временно недоступен.');
}

final class UnknownFailure extends Failure {
  const UnknownFailure({super.cause, super.stackTrace}) : super('Не удалось выполнить запрос.');
}

import 'package:core/data.dart';

sealed class NetworkFailure extends Failure {
  const NetworkFailure(super.message, {super.cause, super.stackTrace});
}

final class TimeoutFailure extends NetworkFailure {
  const TimeoutFailure({super.cause, super.stackTrace}) : super('Превышено время ожидания ответа сервера.');
}

final class ConnectionFailure extends NetworkFailure {
  const ConnectionFailure({super.cause, super.stackTrace}) : super('Не удалось подключиться к серверу.');
}

final class RequestFailure extends NetworkFailure {
  const RequestFailure({required String message, super.cause, super.stackTrace}) : super(message);
}

final class ServerFailure extends NetworkFailure {
  const ServerFailure({super.cause, super.stackTrace}) : super('Сервер временно недоступен.');
}

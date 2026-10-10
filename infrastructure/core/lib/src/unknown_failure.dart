import 'failure.dart';

final class UnknownFailure extends Failure {
  const UnknownFailure({super.cause, super.stackTrace}) : super('Не удалось выполнить запрос.');
}

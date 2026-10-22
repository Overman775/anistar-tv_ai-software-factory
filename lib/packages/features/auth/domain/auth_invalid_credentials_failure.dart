import 'package:core/data.dart';

/// The site explicitly rejected the submitted login and password.
final class AuthInvalidCredentialsFailure extends Failure {
  const AuthInvalidCredentialsFailure({super.stackTrace}) : super('Вход не выполнен. Проверьте логин и пароль.');
}

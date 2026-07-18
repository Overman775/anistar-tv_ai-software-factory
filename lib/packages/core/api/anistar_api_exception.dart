import 'package:dio/dio.dart';

final class AnistarApiException implements Exception {
  final String message;
  final int? retryAfter;
  final int? statusCode;

  const AnistarApiException({required this.message, this.statusCode, this.retryAfter});

  factory AnistarApiException.fromDio(DioException error) {
    final response = error.response;
    final data = response?.data;
    final detail = data is Map<String, Object?> ? data['detail'] : null;
    final retryAfterValue = response?.headers.value('retry-after');

    return AnistarApiException(
      message: detail is String && detail.isNotEmpty ? detail : _fallbackMessage(response?.statusCode),
      statusCode: response?.statusCode,
      retryAfter: int.tryParse(retryAfterValue ?? ''),
    );
  }

  @override
  String toString() => message;

  static String _fallbackMessage(int? statusCode) => switch (statusCode) {
    400 => 'Сессия просмотра устарела. Запустите серию ещё раз.',
    404 => 'Аниме или серия больше недоступны.',
    429 => 'Слишком много запросов. Попробуйте немного позже.',
    502 => 'AniStar временно не отвечает.',
    503 => 'Сервис пока не готов. Попробуйте позже.',
    _ => 'Не удалось связаться с AniStar Parser.',
  };
}

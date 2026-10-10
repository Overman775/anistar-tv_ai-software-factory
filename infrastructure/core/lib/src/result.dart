// Factories and operations describe one sealed result; DCM's ordering rules
// require conflicting positions for its redirecting factories and fields.
// ignore_for_file: member-ordering

import 'failure.dart';

/// Repositories return a value or a domain failure, never a transport exception.
sealed class Result<S, F extends Failure> {
  const Result();

  const factory Result.success(S value) = ResultSuccess<S, F>;
  const factory Result.failure(F error) = ResultFailed<S, F>;

  bool get isSuccess => this is ResultSuccess<S, F>;
  bool get isFailure => !isSuccess;

  S? get successOrNull => switch (this) {
    ResultSuccess(:final value) => value,
    ResultFailed() => null,
  };

  F? get failureOrNull => switch (this) {
    ResultSuccess() => null,
    ResultFailed(:final error) => error,
  };

  T when<T>({required T Function(S value) success, required T Function(F error) failure}) => switch (this) {
    ResultSuccess(:final value) => success(value),
    ResultFailed(:final error) => failure(error),
  };
}

final class ResultSuccess<S, F extends Failure> extends Result<S, F> {
  final S value;

  const ResultSuccess(this.value);
}

final class ResultFailed<S, F extends Failure> extends Result<S, F> {
  final F error;

  const ResultFailed(this.error);
}

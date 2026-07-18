// The sealed result type needs both factory constructors and public operations.
// DCM's member-ordering rule has conflicting order requirements for this shape.
// ignore_for_file: member-ordering

sealed class Either<L, R> {
  const Either();

  R? get rightOrNull;

  T fold<T>({required T Function(L left) onLeft, required T Function(R right) onRight});

  const factory Either.left(L value) = Left<L, R>;
  const factory Either.right(R value) = Right<L, R>;
}

final class Left<L, R> extends Either<L, R> {
  final L value;

  const Left(this.value);

  @override
  R? get rightOrNull => null;

  @override
  T fold<T>({required T Function(L left) onLeft, required T Function(R right) onRight}) => onLeft(value);
}

final class Right<L, R> extends Either<L, R> {
  final R value;

  const Right(this.value);

  @override
  R get rightOrNull => value;

  @override
  T fold<T>({required T Function(L left) onLeft, required T Function(R right) onRight}) => onRight(value);
}

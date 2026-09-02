typedef Lazy<T> = T Function();

/// Represents a value of one of two possible types.
/// Instances of [Either] are either an instance of [Left] or [Right].
///
/// [Left] is used for "failure".
/// [Right] is used for "success".
sealed class Either<L, R> {
  const Either();

  /// True if this is a Left (failure).
  bool get isLeft => this is Left<L, R>;

  /// True if this is a Right (success).
  bool get isRight => this is Right<L, R>;

  /// Get Left value (throws if Right).
  L get left => fold(
    (l) => l,
    (_) => throw StateError('Tried to access Left on a Right'),
  );

  /// Get Right value (throws if Left).
  R get right => fold(
    (_) => throw StateError('Tried to access Right on a Left'),
    (r) => r,
  );

  /// Apply fnL if Left, fnR if Right.
  T fold<T>(T Function(L l) fnL, T Function(R r) fnR);

  /// Map Right value.
  Either<L, R2> mapRight<R2>(R2 Function(R r) f) =>
      fold((l) => Left(l), (r) => Right(f(r)));

  /// Map Left value.
  Either<L2, R> mapLeft<L2>(L2 Function(L l) f) =>
      fold((l) => Left(f(l)), (r) => Right(r));

  /// Chain computations, avoids nested Eithers.
  Either<L, R2> flatMap<R2>(Either<L, R2> Function(R r) f) =>
      fold((l) => Left(l), (r) => f(r));

  /// Transform both Left and Right.
  Either<L2, R2> either<L2, R2>(L2 Function(L l) fnL, R2 Function(R r) fnR) =>
      fold((l) => Left(fnL(l)), (r) => Right(fnR(r)));

  /// Swap Left and Right.
  Either<R, L> swap() => fold((l) => Right(l), (r) => Left(r));

  /// Construct Either from try-catch.
  static Either<L, R> tryCatch<L, R, E extends Object>(
    L Function(E e) onError,
    R Function() fn,
  ) {
    try {
      return Right(fn());
    } on E catch (e) {
      return Left(onError(e));
    }
  }

  /// Simplified try-catch (error type is Left).
  static Either<E, R> tryExcept<E extends Object, R>(R Function() fn) {
    try {
      return Right(fn());
    } on E catch (e) {
      return Left(e);
    }
  }

  /// Conditional Either.
  static Either<L, R> cond<L, R>(bool test, L l, R r) =>
      test ? Right(r) : Left(l);

  static Either<L, R> condLazy<L, R>(bool test, Lazy<L> l, Lazy<R> r) =>
      test ? Right(r()) : Left(l());

  @override
  bool operator ==(Object other) => fold(
    (l) => other is Left && l == other.value,
    (r) => other is Right && r == other.value,
  );

  @override
  int get hashCode => fold((l) => l.hashCode, (r) => r.hashCode);
}

/// Failure.
final class Left<L, R> extends Either<L, R> {
  final L value;

  const Left(this.value);

  @override
  T fold<T>(T Function(L l) fnL, T Function(R r) fnR) => fnL(value);
}

/// Success.
final class Right<L, R> extends Either<L, R> {
  final R value;

  const Right(this.value);

  @override
  T fold<T>(T Function(L l) fnL, T Function(R r) fnR) => fnR(value);
}

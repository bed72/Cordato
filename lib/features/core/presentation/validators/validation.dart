sealed class ValidationResult<T> {
  const ValidationResult();
}

final class const Valid<T>(final T value) extends ValidationResult<T> {}

final class const Invalid<T>(final String message)
    extends ValidationResult<T> {}

abstract interface class Validation<T> {
  ValidationResult<T> call(T value);
}

sealed class ValidationResult<T> {
  const ValidationResult();
}

final class Valid<T> extends ValidationResult<T> {
  final T value;

  const Valid(this.value);
}

final class Invalid<T> extends ValidationResult<T> {
  final String message;

  const Invalid(this.message);
}

abstract interface class Validation<T> {
  ValidationResult<T> call(T value);
}

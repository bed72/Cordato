import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';

final class const AmountValueObject._({required final int cents}) {
  static Either<ErrorsEntity, AmountValueObject> create({required int cents}) {
    if (cents <= 0) {
      return const Left(
        ErrorsEntity(
          errors: [
            ErrorEntity(
              title: 'Valor inválido',
              detail: 'O valor da despesa deve ser maior que zero.',
            ),
          ],
        ),
      );
    }

    return Right(AmountValueObject._(cents: cents));
  }

  @override
  int get hashCode => cents.hashCode;

  @override
  bool operator ==(Object other) =>
      other is AmountValueObject && cents == other.cents;
}

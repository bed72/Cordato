import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/presentation/validators/validation.dart';

import 'package:cordato/features/expense/presentation/screens/create_expense/validators/expense_date_validation.dart';
import 'package:cordato/features/expense/presentation/screens/create_expense/validators/expense_cents_validation.dart';
import 'package:cordato/features/expense/presentation/screens/create_expense/validators/create_expense_form_validator.dart';
import 'package:cordato/features/expense/presentation/screens/create_expense/validators/expense_description_validation.dart';

void main() {
  const validator = CreateExpenseFormValidator(
    dateValidation: ExpenseDateValidation(),
    centsValidation: ExpenseCentsValidation(),
    descriptionValidation: ExpenseDescriptionValidation(),
  );

  test('returns validated data for each field of a complete form', () {
    final date = DateTime(2026, 10, 5);

    final data = validator(
      cents: 300,
      occurredOn: date,
      description: '  Game  ',
    );

    expect(
      data.cents,
      isA<Valid<int>>().having((field) => field.value, 'value', 300),
    );
    expect(
      data.description,
      isA<Valid<String>>().having((field) => field.value, 'value', 'Game'),
    );
    expect(
      data.occurredOn,
      isA<Valid<DateTime?>>().having(
        (field) => field.value,
        'value',
        same(date),
      ),
    );
  });

  test('reports all invalid fields in a single validation', () {
    final data = validator(cents: 0, description: '   ', occurredOn: null);

    expect(
      data.cents,
      isA<Invalid<int>>().having(
        (field) => field.message,
        'message',
        'Informe um valor maior que zero',
      ),
    );
    expect(
      data.description,
      isA<Invalid<String>>().having(
        (field) => field.message,
        'message',
        'Informe uma descrição',
      ),
    );
    expect(
      data.occurredOn,
      isA<Invalid<DateTime?>>().having(
        (field) => field.message,
        'message',
        'Selecione a data',
      ),
    );
  });

  test('keeps valid fields when only the description is invalid', () {
    final data = validator(
      cents: 1,
      description: 'a',
      occurredOn: DateTime(2026, 10, 5),
    );

    expect(data.cents, isA<Valid<int>>());
    expect(data.description, isA<Invalid<String>>());
    expect(data.occurredOn, isA<Valid<DateTime?>>());
  });

  test('allows correcting invalid fields and validating the form again', () {
    final invalid = validator(cents: -1, description: '', occurredOn: null);
    final valid = validator(
      cents: 300,
      description: 'Game',
      occurredOn: DateTime(2026, 10, 5),
    );

    expect(invalid.cents, isA<Invalid<int>>());
    expect(invalid.description, isA<Invalid<String>>());
    expect(invalid.occurredOn, isA<Invalid<DateTime?>>());
    expect(valid.cents, isA<Valid<int>>());
    expect(valid.description, isA<Valid<String>>());
    expect(valid.occurredOn, isA<Valid<DateTime?>>());
  });
}

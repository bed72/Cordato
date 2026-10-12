import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/expense/domain/enums/expense_category_enum.dart';
import 'package:cordato/features/expense/presentation/extensions/expense_category_extension.dart';

void main() {
  group('ExpenseCategoryExtension', () {
    final labels = <ExpenseCategoryEnum, String>{
      .health: 'Saúde',
      .leisure: 'Lazer',
      .taxes: 'Impostos',
      .travel: 'Viagens',
      .housing: 'Moradia',
      .shopping: 'Compras',
      .food: 'Alimentação',
      .insurance: 'Seguros',
      .services: 'Serviços',
      .education: 'Educação',
      .transport: 'Transporte',
      .financing: 'Financiamentos',
      .subscriptions: 'Assinaturas',
      .pets: 'Animais de estimação',
      .investments: 'Investimentos',
      .personalCare: 'Cuidados pessoais',
      .giftsAndDonations: 'Presentes e doações',
      .other: 'Outros',
    };

    for (final category in ExpenseCategoryEnum.values) {
      test('displays ${category.name} in Brazilian Portuguese', () {
        expect(category.label, labels[category]);
      });
    }
  });
}

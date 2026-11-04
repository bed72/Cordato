import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

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

  group('Expense category Material icons', () {
    const icons = {
      ExpenseCategoryEnum.pets: Icons.pets_outlined,
      ExpenseCategoryEnum.housing: Icons.home_outlined,
      ExpenseCategoryEnum.leisure: Icons.play_circle_outline,
      ExpenseCategoryEnum.travel: Icons.flight_outlined,
      ExpenseCategoryEnum.health: Icons.favorite_border,
      ExpenseCategoryEnum.food: Icons.restaurant_outlined,
      ExpenseCategoryEnum.insurance: Icons.verified_user_outlined,
      ExpenseCategoryEnum.education: Icons.menu_book_outlined,
      ExpenseCategoryEnum.personalCare: Icons.auto_awesome_outlined,
      ExpenseCategoryEnum.services: Icons.build_outlined,
      ExpenseCategoryEnum.financing: Icons.payments_outlined,
      ExpenseCategoryEnum.taxes: Icons.task_outlined,
      ExpenseCategoryEnum.shopping: Icons.shopping_cart_outlined,
      ExpenseCategoryEnum.subscriptions: Icons.refresh,
      ExpenseCategoryEnum.investments: Icons.trending_up,
      ExpenseCategoryEnum.transport: Icons.local_shipping_outlined,
      ExpenseCategoryEnum.giftsAndDonations: Icons.volunteer_activism_outlined,
      ExpenseCategoryEnum.other: Icons.receipt_long_outlined,
    };

    test('covers every expense category', () {
      expect(icons.keys, unorderedEquals(ExpenseCategoryEnum.values));
    });

    for (final entry in icons.entries) {
      test('maps ${entry.key.name} to a static Material icon', () {
        final icon = entry.key.icon;

        expect(icon, same(entry.value));
        expect(icon.fontFamily, 'MaterialIcons');
      });
    }
  });

  group('Category selection catalog', () {
    test('includes each domain category exactly once with Others last', () {
      final categories = ExpenseCategoryExtension.orderedValues;

      expect(categories, hasLength(ExpenseCategoryEnum.values.length));
      expect(categories.toSet(), ExpenseCategoryEnum.values.toSet());
      expect(categories.last, ExpenseCategoryEnum.other);
      expect(() => categories.add(.food), throwsUnsupportedError);
    });

    test('uses Portuguese alphabetical labels before Others', () {
      expect(
        ExpenseCategoryExtension.orderedValues.map(
          (category) => category.label,
        ),
        [
          'Alimentação',
          'Animais de estimação',
          'Assinaturas',
          'Compras',
          'Cuidados pessoais',
          'Educação',
          'Financiamentos',
          'Impostos',
          'Investimentos',
          'Lazer',
          'Moradia',
          'Presentes e doações',
          'Saúde',
          'Seguros',
          'Serviços',
          'Transporte',
          'Viagens',
          'Outros',
        ],
      );
    });

    for (final category in ExpenseCategoryEnum.values) {
      test('${category.value} has a description of five or six words', () {
        final description = category.description;

        expect(description, description.trim());
        expect(description, isNot(contains('\n')));
        expect(
          description.split(RegExp(r'\s+')).length,
          inInclusiveRange(5, 6),
        );
      });
    }
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/themes/color_theme.dart';
import 'package:cordato/features/expense/domain/enums/category_enum.dart';
import 'package:cordato/features/expense/presentation/extensions/expense_category_extension.dart';

void main() {
  group('Category icon contrast', () {
    final schemes = [lightColorScheme, darkColorScheme];
    const categories = [
      CategoryEnum.pets,
      CategoryEnum.investments,
      CategoryEnum.giftsAndDonations,
    ];

    for (final scheme in schemes) {
      for (final category in categories) {
        test('${category.name} is visible in ${scheme.brightness.name}', () {
          final foreground = category.colorForScheme(scheme);
          final background = Color.alphaBlend(
            foreground.withValues(alpha: 0.12),
            scheme.surface,
          );
          final foregroundLuminance = foreground.computeLuminance();
          final backgroundLuminance = background.computeLuminance();
          final lighter = foregroundLuminance > backgroundLuminance
              ? foregroundLuminance
              : backgroundLuminance;
          final darker = foregroundLuminance < backgroundLuminance
              ? foregroundLuminance
              : backgroundLuminance;

          expect((lighter + 0.05) / (darker + 0.05), greaterThanOrEqualTo(3));
        });
      }
    }
  });

  group('ExpenseCategoryExtension', () {
    final labels = <CategoryEnum, String>{
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

    for (final category in CategoryEnum.values) {
      test('displays ${category.name} in Brazilian Portuguese', () {
        expect(category.label, labels[category]);
      });
    }
  });

  group('Expense category Material icons', () {
    const icons = {
      CategoryEnum.pets: Icons.pets_outlined,
      CategoryEnum.housing: Icons.home_outlined,
      CategoryEnum.leisure: Icons.play_circle_outline,
      CategoryEnum.travel: Icons.flight_outlined,
      CategoryEnum.health: Icons.favorite_border,
      CategoryEnum.food: Icons.restaurant_outlined,
      CategoryEnum.insurance: Icons.verified_user_outlined,
      CategoryEnum.education: Icons.menu_book_outlined,
      CategoryEnum.personalCare: Icons.auto_awesome_outlined,
      CategoryEnum.services: Icons.build_outlined,
      CategoryEnum.financing: Icons.payments_outlined,
      CategoryEnum.taxes: Icons.task_outlined,
      CategoryEnum.shopping: Icons.shopping_cart_outlined,
      CategoryEnum.subscriptions: Icons.refresh,
      CategoryEnum.investments: Icons.trending_up,
      CategoryEnum.transport: Icons.local_shipping_outlined,
      CategoryEnum.giftsAndDonations: Icons.volunteer_activism_outlined,
      CategoryEnum.other: Icons.receipt_long_outlined,
    };

    test('covers every expense category', () {
      expect(icons.keys, unorderedEquals(CategoryEnum.values));
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

      expect(categories, hasLength(CategoryEnum.values.length));
      expect(categories.toSet(), CategoryEnum.values.toSet());
      expect(categories.last, CategoryEnum.other);
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

    for (final category in CategoryEnum.values) {
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

import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/root/infrastructure/serializers/widget_launch_serializer.dart';

void main() {
  test('accepts only the native add-expense action', () {
    expect(
      isWidgetExpenseLaunch(
        Uri.parse('cordato://widget/add-expense?homeWidget=true'),
      ),
      isTrue,
    );
  });

  for (final address in [
    null,
    'https://widget/add-expense?homeWidget=true',
    'cordato://other/add-expense?homeWidget=true',
    'cordato://widget/edit-expense?homeWidget=true',
    'cordato://widget/add-expense',
    'cordato://widget/add-expense?homeWidget=false',
    'cordato://widget/add-expense?homeWidget=true&homeWidget=true',
    'cordato://widget/add-expense?homeWidget=true&token=untrusted',
    'cordato://user@widget/add-expense?homeWidget=true',
    'cordato://widget:123/add-expense?homeWidget=true',
    'cordato://widget/add-expense?homeWidget=true#extra',
  ]) {
    test('ignores $address', () {
      expect(
        isWidgetExpenseLaunch(address == null ? null : Uri.parse(address)),
        isFalse,
      );
    });
  }
}

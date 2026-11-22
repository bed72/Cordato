import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/root/infrastructure/repositories/widget_launch_repository.dart';

import '../../../../support/core/mocks/widget_client_mock.dart';

void main() {
  final launch = Uri.parse('cordato://widget/add-expense?homeWidget=true');

  test('initial launch returns a typed decision, not the native URI', () async {
    final client = WidgetClientMock();
    when(client.initialLaunch).thenAnswer((_) async => launch);
    final repository = WidgetLaunchRepository(client: client);

    expect(await repository.initialExpenseLaunch(), isTrue);
  });

  test('ordinary initial launch is not a widget action', () async {
    final client = WidgetClientMock();
    when(client.initialLaunch).thenAnswer((_) async => null);

    expect(
      await WidgetLaunchRepository(client: client).initialExpenseLaunch(),
      isFalse,
    );
  });

  test(
    'warm launch filtering preserves valid repeated actions and cancellation',
    () async {
      final source = StreamController<Uri?>();
      final client = WidgetClientMock();
      when(() => client.launches).thenAnswer((_) => source.stream);
      final repository = WidgetLaunchRepository(client: client);
      var launchCount = 0;
      final delivered = Completer<void>();
      final subscription = repository.expenseLaunches.listen((_) {
        launchCount++;
        if (launchCount == 2) {
          delivered.complete();
        }
      });
      source.add(null);
      source.add(Uri.parse('https://other.example'));
      source.add(launch);
      source.add(launch);
      await delivered.future;

      await subscription.cancel();
      expect(source.hasListener, isFalse);
      expect(launchCount, 2);
      await source.close();
    },
  );

  test(
    'initial native failures are not converted to a normal app launch',
    () async {
      final client = WidgetClientMock();
      final failure = StateError('native failure');
      when(client.initialLaunch).thenThrow(failure);

      await expectLater(
        WidgetLaunchRepository(client: client).initialExpenseLaunch(),
        throwsA(same(failure)),
      );
    },
  );
}

import 'dart:async';

final class EmailCooldown {
  const EmailCooldown._();

  static const duration = Duration(seconds: 60);

  static Stream<int> ticks() => Stream<int>.multi((controller) {
    final timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      controller.add(timer.tick);
      if (timer.tick >= duration.inSeconds) {
        timer.cancel();
        controller.close();
      }
    });
    controller.onCancel = timer.cancel;
  });
}

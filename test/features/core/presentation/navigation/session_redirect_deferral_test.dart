import 'package:flutter_test/flutter_test.dart';
import 'package:cordato/features/core/presentation/navigation/session_redirect_deferral.dart';

void main() {
  test('defers only the held route and releases idempotently', () {
    var released = 0;
    final deferral = SessionRedirectDeferral(onReleased: () => released++);
    expect(deferral.isDeferredFor('/change'), isFalse);
    final release = deferral.hold('/change');
    expect(deferral.isDeferredFor('/change'), isTrue);
    expect(deferral.isDeferredFor('/other'), isFalse);
    release();
    release();
    expect(deferral.isDeferredFor('/change'), isFalse);
    expect(released, 1);
  });

  test('each owner releases only its own hold', () {
    final deferral = SessionRedirectDeferral(onReleased: () {});
    final first = deferral.hold('/change');
    final second = deferral.hold('/change');
    first();
    expect(deferral.isDeferredFor('/change'), isTrue);
    second();
    expect(deferral.isDeferredFor('/change'), isFalse);
  });
}

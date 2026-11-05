import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';

import 'package:cordato/features/core/application/clients/interface_home_widget_client.dart';

final class HomeWidgetClient implements IHomeWidgetClient {
  int _revision = 0;
  bool _sessionActive = false;

  Future<void> _pendingWrite = Future.value();
  final Set<MultiStreamController<void>> _refreshListeners = {};

  bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == .android || defaultTargetPlatform == .iOS);

  @override
  Stream<Uri?> get launches =>
      _supported ? HomeWidget.widgetClicked : const .empty();

  @override
  Future<Uri?> initialLaunch() async =>
      _supported ? await HomeWidget.initiallyLaunchedFromHomeWidget() : null;

  @override
  Stream<void> get monthlyRefreshRequests => Stream.multi((controller) {
    _refreshListeners.add(controller);
    controller.onCancel = () => _refreshListeners.remove(controller);
  }, isBroadcast: true);

  @override
  void requestMonthlyRefresh() {
    _revision++;

    for (final listener in _refreshListeners.toList()) {
      listener.add(null);
    }
  }

  @override
  int beginMonthlyRead() => ++_revision;

  @override
  Future<void> setMonthlySessionActive({required bool active}) {
    if (_sessionActive != active || !active) {
      _revision++;
    }

    _sessionActive = active;
    if (active) return Future.value();

    return _enqueueWrite(() => _writeSummary(null));
  }

  @override
  Future<void> publishMonthlyTotal({
    required int cents,
    required int revision,
    required DateTime month,
  }) => _enqueueWrite(() async {
    if (!_sessionActive || revision != _revision) return;

    final monthKey = '${month.year}-${month.month.toString().padLeft(2, '0')}';
    await _writeSummary(jsonEncode({'month': monthKey, 'cents': cents}));
  });

  Future<void> _enqueueWrite(Future<void> Function() write) {
    final operation = _pendingWrite.then((_) => write());
    _pendingWrite = operation.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );

    return operation;
  }

  Future<void> _writeSummary(String? summary) async {
    if (!_supported) return;

    try {
      if (defaultTargetPlatform == .iOS) {
        await HomeWidget.setAppGroupId('group.com.bed.cordato');
      }

      await HomeWidget.saveWidgetData<String>('monthly_summary', summary);
      await HomeWidget.updateWidget(
        iOSName: 'AddExpenseWidget',
        androidName: 'AddExpenseWidgetProvider',
      );
    } on PlatformException catch (error, stackTrace) {
      _reportError(error, stackTrace);
    } on MissingPluginException catch (error, stackTrace) {
      _reportError(error, stackTrace);
    }
  }

  void _reportError(Object error, StackTrace stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'home widget monthly summary',
      ),
    );
  }
}

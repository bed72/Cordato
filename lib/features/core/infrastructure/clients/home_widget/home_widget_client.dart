import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import 'package:cordato/features/core/application/clients/interface_home_widget_client.dart';

final class HomeWidgetClient implements IHomeWidgetClient {
  bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == .android || defaultTargetPlatform == .iOS);

  @override
  Stream<Uri?> get launches =>
      _supported ? HomeWidget.widgetClicked : const .empty();

  @override
  Future<Uri?> initialLaunch() async =>
      _supported ? await HomeWidget.initiallyLaunchedFromHomeWidget() : null;
}

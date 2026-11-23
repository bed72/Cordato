import 'package:drift/isolate.dart';

final class MetricsRemoteException(
  @override final Object remoteCause,
  @override final StackTrace? remoteStackTrace,
) implements DriftRemoteException;

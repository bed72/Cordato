import 'package:drift/isolate.dart';

final class DatabaseRemoteException(
  @override final Object remoteCause,
  @override final StackTrace? remoteStackTrace,
) implements DriftRemoteException;

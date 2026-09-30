import 'package:talker/talker.dart';
import 'package:flutter/foundation.dart';

abstract interface class ILoggerClient {
  void debug(String message, {Object? error, StackTrace? stackTrace});
  void error(String message, {Object? error, StackTrace? stackTrace});
  void warning(String message, {Object? error, StackTrace? stackTrace});
  void verbose(String message, {Object? error, StackTrace? stackTrace});
  void critical(String message, {Object? error, StackTrace? stackTrace});
  void information(String message, {Object? error, StackTrace? stackTrace});
}

final class LoggerClient implements ILoggerClient {
  final _logger = TalkerLogger(
    settings: TalkerLoggerSettings(
      enableColors: false,
      level: kReleaseMode ? .warning : .verbose,
    ),
  );

  @override
  void debug(String message, {Object? error, StackTrace? stackTrace}) =>
      _logger.debug(message);

  @override
  void information(String message, {Object? error, StackTrace? stackTrace}) =>
      _logger.info(message);

  @override
  void warning(String message, {Object? error, StackTrace? stackTrace}) =>
      _logger.warning(message);

  @override
  void error(String message, {Object? error, StackTrace? stackTrace}) =>
      loggerClient.error(message, error, stackTrace);

  @override
  void verbose(String message, {Object? error, StackTrace? stackTrace}) =>
      _logger.verbose(message);

  @override
  void critical(String message, {Object? error, StackTrace? stackTrace}) =>
      loggerClient.critical(message, error, stackTrace);
}

final loggerClient = Talker(
  logger: TalkerLogger(settings: TalkerLoggerSettings(enableColors: false)),
);

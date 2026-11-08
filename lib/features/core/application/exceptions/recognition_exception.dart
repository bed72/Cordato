import 'package:cordato/features/core/application/enums/recognition_failure_enum.dart';

final class const RecognitionException(final RecognitionFailureEnum failure)
    implements Exception;

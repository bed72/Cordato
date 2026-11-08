import 'package:flutter/foundation.dart';

import 'package:cordato/features/core/application/enums/recognition_failure_enum.dart';

abstract final class RecognitionMapper {
  static RecognitionFailureEnum? failure(String nativeCode) =>
      switch (nativeCode) {
        'error_permission' => .permission,
        'error_language_not_supported' ||
        'error_language_unavailable' => .language,
        'error_speech_timeout' || 'error_no_match' => null,
        _ => .interrupted,
      };

  static double soundLevel({
    required double decibels,
    required TargetPlatform platform,
  }) {
    final normalizedLevel = switch (platform) {
      .iOS || .macOS => (decibels + 60) / 60,
      _ => decibels / 10,
    };

    return !normalizedLevel.isFinite ? 0 : normalizedLevel.clamp(0.0, 1.0);
  }
}

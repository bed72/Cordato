sealed class const SpeechUpdateEvent();

final class const SpeechListeningUpdateEvent() extends SpeechUpdateEvent;

final class const SpeechLevelUpdateEvent(final double level)
    extends SpeechUpdateEvent;

final class const SpeechReadyUpdateEvent() extends SpeechUpdateEvent;

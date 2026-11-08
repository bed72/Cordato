sealed class const SpeechEvent();

final class const SpeechStarted() extends SpeechEvent;

final class const SpeechObserved(final int operation) extends SpeechEvent;

final class const SpeechSubmitted() extends SpeechEvent;

final class const SpeechCancelled({final bool lifecycle = false})
    extends SpeechEvent;

final class const SpeechCollapsed(final int operation) extends SpeechEvent;

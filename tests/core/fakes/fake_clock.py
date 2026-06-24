from datetime import datetime

from trocado.core.application.interfaces.clock_interface import ClockInterface


class FakeClock(ClockInterface):
    """Returns a fixed instant so `created_at` is deterministic in tests."""

    def __init__(self, now: datetime) -> None:
        self._now = now

    async def now(self) -> datetime:
        return self._now

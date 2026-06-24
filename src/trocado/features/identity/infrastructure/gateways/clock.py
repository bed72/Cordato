from __future__ import annotations

from datetime import UTC, datetime

from trocado.features.identity.application.interfaces.clock_interface import ClockInterface


class Clock(ClockInterface):
    """Returns the current timezone-aware (UTC) timestamp."""

    async def now(self) -> datetime:
        return datetime.now(UTC)

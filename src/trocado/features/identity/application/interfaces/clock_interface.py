from abc import ABC, abstractmethod
from datetime import datetime


class ClockInterface(ABC):
    """Port that supplies the current time, so the domain stays deterministic under test."""

    @abstractmethod
    async def now(self) -> datetime:
        """Return the current timezone-aware timestamp."""
        raise NotImplementedError

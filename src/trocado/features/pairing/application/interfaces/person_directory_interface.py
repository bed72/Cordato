from __future__ import annotations

from abc import ABC, abstractmethod


class PersonDirectoryInterface(ABC):
    """Pairing's own port for asking whether a person is active — an anti-corruption seam, not a coupling.

    Why it exists: forming a pair requires both parties to be active people, a fact owned by the
    ``identity`` context. The modular monolith forbids a ``pairing -> identity`` import, so pairing does
    **not** reach into another module; it depends on this abstraction, in its own vocabulary, and the
    concrete adapter that bridges to identity is wired at the composition root — the only layer permitted
    to know both modules. This mirrors how the determinism ports are shared through ``core/`` rather than
    imported across contexts.

    It returns a bare ``bool`` (never raising) so the port stays free of pairing's domain errors; the use
    case translates ``False`` into ``PersonNotActiveError``.

    Implementors (adapters wired at the composition root):
        - MUST report ``True`` only for a person who exists and is active.
        - MUST treat an unknown id as not active (``False``), never an error.
    """

    @abstractmethod
    async def is_active(self, person_id: str) -> bool:
        """Whether the given person exists and is active."""
        raise NotImplementedError

from __future__ import annotations

from abc import ABC, abstractmethod

from trocado.features.pairing.application.data.partner_profile_data import PartnerProfileData


class PersonDirectoryInterface(ABC):
    """Pairing's own port for asking about people in the ``identity`` context — an anti-corruption seam.

    Why it exists: forming a pair requires both parties to be active people, and rendering a pair requires
    the partner's name — facts owned by the ``identity`` context. The modular monolith forbids a
    ``pairing -> identity`` import, so pairing does **not** reach into another module; it depends on this
    abstraction, in its own vocabulary, and the concrete adapter that bridges to identity is wired at the
    composition root — the only layer permitted to know both modules. This mirrors how the determinism
    ports are shared through ``core/`` rather than imported across contexts.

    A *directory* naturally maps an id to person info: ``is_active`` answers the bare active-check used when
    forming a pair, and ``find_active_profile`` broadens the same seam to an id -> profile lookup used when
    reading a pair. Both stay free of pairing's domain errors (never raising); the use cases translate
    their absence (``False`` / ``None``) into the right behavior.

    Implementors (adapters wired at the composition root):
        - ``is_active`` MUST report ``True`` only for a person who exists and is active; an unknown id is
          not active (``False``), never an error.
        - ``find_active_profile`` MUST return the profile only for a person who exists and is active, and
          ``None`` for an unknown or inactive id — never an error.
    """

    @abstractmethod
    async def is_active(self, person_id: str) -> bool:
        """Whether the given person exists and is active."""
        raise NotImplementedError

    @abstractmethod
    async def find_active_profile(self, person_id: str) -> PartnerProfileData | None:
        """The active person's identity (id + name), or ``None`` if unknown or inactive."""
        raise NotImplementedError

from __future__ import annotations

from abc import ABC, abstractmethod

from trocado.features.pairing.application.data.partner_profile_data import PartnerProfileData


class PersonReaderInterface(ABC):
    """Gateway port — a partner's active profile, read in pairing's own terms.

    ``PersonDirectory`` needs a partner's profile to check activeness and render a pair, but people live
    in another context. This port states the need in pairing's **own** vocabulary — ``PartnerProfileData``,
    never the identity module's entity or enum — so pairing depends only on this abstraction and never
    imports a sibling feature. The adapter that actually reads the person lives in
    ``infrastructure/gateways/``: a local stand-in today, a shared-database query once the ORM lands.

    It is a **gateway**, not a repository: it reads data pairing does not own and maps no entity to a
    table of its own.

    Implementors:
        - MUST return the profile only for a person who exists and is active.
        - MUST return ``None`` for an unknown or inactive id — never raise.
    """

    @abstractmethod
    async def find_active_profile(self, person_id: str) -> PartnerProfileData | None:
        """Return the active person's profile, or ``None`` if unknown or inactive."""
        raise NotImplementedError

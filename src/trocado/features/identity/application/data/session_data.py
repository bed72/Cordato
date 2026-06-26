from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime

from trocado.features.identity.application.data.person_data import PersonData


@dataclass(frozen=True, slots=True)
class SessionData:
    """Read-model returned by a successful sign-in: the bearer token, its expiry, and the person.

    The caller (a Flutter app) stores ``token`` in secure storage and sends it on later requests, shows the
    person's profile, and knows from ``expires_at`` when it must sign in again.
    """

    token: str
    person: PersonData
    expires_at: datetime

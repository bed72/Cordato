from __future__ import annotations

from dataclasses import dataclass

from trocado.features.identity.domain.value_objects.password_value_object import PasswordValueObject


@dataclass(frozen=True, slots=True)
class DeleteAccountData:
    """Command input for deleting an account — who is leaving, and the password re-confirming their identity."""

    requester_id: str
    password: PasswordValueObject

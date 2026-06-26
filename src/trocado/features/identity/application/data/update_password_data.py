from __future__ import annotations

from dataclasses import dataclass

from trocado.features.identity.domain.value_objects.password_value_object import PasswordValueObject


@dataclass(frozen=True, slots=True)
class UpdatePasswordData:
    """Command input for rotating a password — who is acting, on which session, and the two passwords.

    `requester_id` is the acting identity resolved upstream from a live session; `current_session_token`
    is that session's bearer token, the one kept alive while every other session is purged. Both passwords
    are `PasswordValueObject` (policy-checked at construction, like `DeleteAccountData.password`): the
    `current_password` re-confirms identity via the hasher, the `new_password` is hashed and stored.
    """

    requester_id: str
    current_session_token: str
    new_password: PasswordValueObject
    current_password: PasswordValueObject

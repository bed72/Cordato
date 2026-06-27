from __future__ import annotations

from dataclasses import dataclass

from trocado.features.identity.domain.value_objects.password_value_object import PasswordValueObject


@dataclass(frozen=True, slots=True)
class UpdateEmailData:
    """Command input for changing an email — who is acting, on which session, the password, and the new email.

    `requester_id` is the acting identity resolved upstream from a live session; `current_session_token` is
    that session's bearer token, the one kept alive while every other session is purged. `current_password`
    is a `PasswordValueObject` (policy-checked at construction, like `UpdatePasswordData`/`DeleteAccountData`):
    it re-confirms identity via the hasher before the email is touched. `new_email` stays a raw `str`; its
    `EmailValueObject` is built (validated and normalized) in the use case.
    """

    new_email: str
    requester_id: str
    current_session_token: str
    current_password: PasswordValueObject

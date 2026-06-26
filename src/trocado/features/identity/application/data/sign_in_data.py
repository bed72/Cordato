from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True, slots=True)
class SignInData:
    """Command input for signing in — raw credentials straight from the caller.

    Stays raw `str` on purpose: building the value objects is the use case's job, and a malformed email or
    a too-short password must fail *as a generic credential rejection*, never as a value-object error that
    would leak which factor was wrong.
    """

    email: str
    password: str

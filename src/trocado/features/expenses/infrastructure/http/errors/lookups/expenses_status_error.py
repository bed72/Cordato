from __future__ import annotations

from http import HTTPStatus

from trocado.features.expenses.domain.errors.expense_not_found_error import ExpenseNotFoundError
from trocado.features.expenses.domain.errors.invalid_amount_error import InvalidAmountError

EXPENSES_STATUS_ERROR: dict[type[Exception], int] = {
    ExpenseNotFoundError: HTTPStatus.NOT_FOUND,
    InvalidAmountError: HTTPStatus.UNPROCESSABLE_ENTITY,
}
"""Expenses-specific domain-error → HTTP-status entries — a pure table (no framework types).

Registered scoped to expenses' own Router (mirroring its scoped DI). Cross-cutting core errors
(``InvalidMoneyError``, ``InvalidSessionError``) are handled at the app layer via ``CORE_STATUS_ERROR`` —
they must not be duplicated here.
"""

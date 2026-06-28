from __future__ import annotations

from http import HTTPStatus

from trocado.features.budgeting.domain.errors.budget_not_found_error import BudgetNotFoundError
from trocado.features.budgeting.domain.errors.invalid_budget_amount_error import InvalidBudgetAmountError
from trocado.features.budgeting.domain.errors.invalid_budget_range_error import InvalidBudgetRangeError
from trocado.features.budgeting.domain.errors.overlapping_budget_error import OverlappingBudgetError

BUDGETING_STATUS_ERROR: dict[type[Exception], int] = {
    BudgetNotFoundError: HTTPStatus.NOT_FOUND,
    OverlappingBudgetError: HTTPStatus.CONFLICT,
    InvalidBudgetRangeError: HTTPStatus.UNPROCESSABLE_ENTITY,
    InvalidBudgetAmountError: HTTPStatus.UNPROCESSABLE_ENTITY,
}
"""Budgeting's domain-error → HTTP-status entries — a pure table (no framework types).

The budgeting factory merges this with the core map and builds the unified-envelope handlers **scoped to
budgeting's own Router** (per route-module, mirroring its scoped DI). Total over the budgeting errors reachable
at the wired boundary, so none surfaces as an unhandled 500.
"""

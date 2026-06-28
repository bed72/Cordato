from __future__ import annotations

from http import HTTPStatus

from trocado.core.domain.errors.invalid_money_error import InvalidMoneyError

CORE_STATUS_ERROR: dict[type[Exception], int] = {
    InvalidMoneyError: HTTPStatus.UNPROCESSABLE_ENTITY,
}
"""Cross-cutting domain-error → HTTP-status entries, shared by every feature.

A pure table (no framework types), merged with each feature's own map inside that feature's router (so shared
errors like this are framed wherever they are raised) and tested in plain Python. ``InvalidMoneyError`` is core
because the money value object lives in the shared kernel.
"""

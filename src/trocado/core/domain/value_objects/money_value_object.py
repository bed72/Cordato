from __future__ import annotations

from dataclasses import dataclass
from decimal import Decimal

from trocado.core.domain.errors.invalid_money_error import InvalidMoneyError

_CENTS = Decimal("0.01")


@dataclass(frozen=True, slots=True)
class MoneyValueObject:
    """An exact-decimal monetary amount in BRL, precise to the centavo (two decimal places).

    Built only from a ``Decimal`` — never a binary float — so no rounding can sneak in. The sign is
    deliberately unconstrained: zero and negative are valid, so the same type can later represent a
    ``remaining`` balance that has gone negative. An amount with more than two decimal places is
    rejected (never silently rounded — losing a centavo is a correctness bug), and a valid amount is
    normalized to exactly two places so equality is reliable (``19.9`` and ``19.90`` are the same money).
    """

    value: Decimal

    def __post_init__(self) -> None:
        if not self.value.is_finite():
            raise InvalidMoneyError()
        # After the finite check the exponent is always an int; the guard also satisfies the type checker.
        exponent = self.value.as_tuple().exponent
        if not isinstance(exponent, int) or exponent < -2:
            raise InvalidMoneyError()
        object.__setattr__(self, "value", self.value.quantize(_CENTS))

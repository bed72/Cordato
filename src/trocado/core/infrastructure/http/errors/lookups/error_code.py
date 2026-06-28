from __future__ import annotations

import re

_CAMEL_BOUNDARY = re.compile(r"(?<!^)(?=[A-Z])")


def error_code(error_type: type[Exception]) -> str:
    """Derive a stable, programmatic error code from an exception class — pure, framework-free.

    The class name is kebab-cased with its ``Error``/``Exception`` suffix dropped, so ``OverlappingBudgetError``
    becomes ``overlapping-budget`` and ``NotFoundException`` becomes ``not-found``. The code is the client's
    stable handle for the error kind (e.g. to branch on), carried in every error envelope.
    """
    name = error_type.__name__.removesuffix("Error").removesuffix("Exception")
    return _CAMEL_BOUNDARY.sub("-", name).lower()

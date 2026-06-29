from __future__ import annotations

from litestar import Request

from trocado.features.identity.application.data.person_data import PersonData
from trocado.features.identity.application.use_cases.validate_session_use_case import ValidateSessionUseCase
from trocado.features.identity.domain.errors.invalid_session_error import InvalidSessionError


class CurrentPersonProvider:
    _BEARER_PREFIX = "Bearer "

    def __init__(
        self,
        request: Request,  # type: ignore[type-arg]
        validate_session: ValidateSessionUseCase,
    ) -> None:
        self._request = request
        self._validate_session = validate_session

    async def data(self) -> PersonData:
        header = self._request.headers.get("Authorization", "")
        if not header.startswith(self._BEARER_PREFIX):
            raise InvalidSessionError()
        token = header[len(self._BEARER_PREFIX) :]
        return await self._validate_session.execute(token)

from __future__ import annotations

from trocado.features.identity.application.data.sign_up_data import SignUpData
from trocado.features.identity.infrastructure.http.requests.sign_up_request import SignUpRequest


class SignUpRequestMapper:
    @staticmethod
    def to_data(request: SignUpRequest) -> SignUpData:
        return SignUpData(name=request.name, email=request.email, password=request.password)

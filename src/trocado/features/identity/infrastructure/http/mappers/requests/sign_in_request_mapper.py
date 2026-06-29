from __future__ import annotations

from trocado.features.identity.application.data.sign_in_data import SignInData
from trocado.features.identity.infrastructure.http.requests.sign_in_request import SignInRequest


class SignInRequestMapper:
    @staticmethod
    def to_data(request: SignInRequest) -> SignInData:
        return SignInData(email=request.email, password=request.password)

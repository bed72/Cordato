from trocado.core.application.interfaces.identifier_provider_interface import (
    IdentifierProviderInterface,
)


class FakeIdentifierProvider(IdentifierProviderInterface):
    """Returns a fixed identifier so tests can assert on the generated id."""

    def __init__(self, value: str = "id-1") -> None:
        self._value = value

    async def generate(self) -> str:
        return self._value

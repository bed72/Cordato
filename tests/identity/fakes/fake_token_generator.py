from trocado.features.identity.application.interfaces.token_generator_interface import (
    TokenGeneratorInterface,
)


class FakeTokenGenerator(TokenGeneratorInterface):
    """Yields a sequence of known tokens so tests can assert on the issued session token.

    Defaults to a single fixed token; pass several to assert that distinct sign-ins get distinct tokens.
    Cycles back to the start once the sequence is exhausted.
    """

    def __init__(self, *tokens: str) -> None:
        self._tokens = list(tokens) or ["token-1"]
        self._index = 0

    async def generate(self) -> str:
        token = self._tokens[self._index % len(self._tokens)]
        self._index += 1
        return token

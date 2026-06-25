import asyncio
import string

from trocado.features.pairing.infrastructure.gateways.token_generator import TokenGenerator

# token_urlsafe yields base64url characters: letters, digits, '-' and '_'.
_URL_SAFE_ALPHABET = set(string.ascii_letters + string.digits + "-_")


def test_generates_a_non_empty_url_safe_token() -> None:
    token = asyncio.run(TokenGenerator().generate())

    assert token
    assert set(token) <= _URL_SAFE_ALPHABET


def test_two_calls_yield_distinct_tokens() -> None:
    generator = TokenGenerator()

    first = asyncio.run(generator.generate())
    second = asyncio.run(generator.generate())

    assert first != second


def test_token_is_short() -> None:
    token = asyncio.run(TokenGenerator().generate())

    # 8 bytes of entropy → ~11 url-safe chars; comfortably short to share.
    assert len(token) <= 16

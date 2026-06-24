import asyncio

from trocado.core.infrastructure.gateways.identifier_provider import IdentifierProvider


def test_generate_returns_distinct_non_empty_identifiers() -> None:
    provider = IdentifierProvider()

    first = asyncio.run(provider.generate())
    second = asyncio.run(provider.generate())

    assert first and second
    assert first != second


def test_generate_returns_canonical_uuid_string() -> None:
    identifier = asyncio.run(IdentifierProvider().generate())

    # Canonical UUID text form: 36 chars, 8-4-4-4-12 hyphen grouping.
    assert len(identifier) == 36
    assert [len(group) for group in identifier.split("-")] == [8, 4, 4, 4, 12]

import asyncio

from trocado.core.infrastructure.gateways.clock import Clock


def test_now_is_timezone_aware() -> None:
    now = asyncio.run(Clock().now())

    # A naive datetime would silently lose the offset; the port contract is tz-aware.
    assert now.tzinfo is not None
    assert now.utcoffset() is not None

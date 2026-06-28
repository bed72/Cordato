from trocado.core.main.core_factory import register_core


def test_core_contributes_only_the_cross_cutting_ports() -> None:
    """The app layer holds the shared kernel and nothing feature-specific."""
    assert set(register_core()) == {"clock", "identifier"}

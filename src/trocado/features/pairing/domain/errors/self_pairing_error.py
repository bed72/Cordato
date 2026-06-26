class SelfPairingError(Exception):
    """Raised when the accepter is the code's own creator — a pair is always between two distinct people."""

    def __init__(self) -> None:
        super().__init__("Você não pode parear consigo mesmo.")

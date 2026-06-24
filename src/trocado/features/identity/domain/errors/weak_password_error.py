class WeakPasswordError(Exception):
    """Raised when a raw password does not satisfy the minimum policy."""

    def __init__(self, minimum_length: int) -> None:
        super().__init__(f"Senha deve ter ao menos {minimum_length} caracteres.")
        self.minimum_length = minimum_length

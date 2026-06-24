class InvalidNameError(Exception):
    """Raised when a person's name is blank after trimming."""

    def __init__(self) -> None:
        super().__init__("Nome não pode ser vazio.")

from __future__ import annotations

_FALLBACK = "Valor inválido."

_VALIDATION_MESSAGES: dict[str, str] = {
    "missing": "Campo obrigatório.",
    "date_type": "Deve ser uma data.",
    "json_type": "Corpo JSON inválido.",
    "float_type": "Deve ser um número.",
    "string_type": "Deve ser um texto.",
    "bool_type": "Deve ser um booleano.",
    "json_invalid": "Corpo JSON inválido.",
    "int_type": "Deve ser um número inteiro.",
    "int_parsing": "Número inteiro inválido.",
    "decimal_type": "Deve ser um número decimal.",
    "decimal_parsing": "Número decimal inválido.",
    "date_parsing": "Data inválida (use o formato AAAA-MM-DD).",
    "date_from_datetime_parsing": "Data inválida (use o formato AAAA-MM-DD).",
}


def message_validation(error_type: str) -> str:
    """Translate a Pydantic validation error ``type`` into a pt-BR message — pure, framework-free.

    Maps stable Pydantic codes (``missing``, ``decimal_type``, ``date_parsing``, …) to short pt-BR text, falling
    back to a generic message for any code not (yet) listed, so the boundary never echoes Pydantic's English.
    """
    return _VALIDATION_MESSAGES.get(error_type, _FALLBACK)

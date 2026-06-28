from trocado.core.infrastructure.http.errors.validations.messages_validation import message_validation


def test_translates_known_pydantic_types_to_pt_br() -> None:
    assert message_validation("missing") == "Campo obrigatório."
    assert message_validation("decimal_type") == "Deve ser um número decimal."
    assert message_validation("date_parsing") == "Data inválida (use o formato AAAA-MM-DD)."


def test_falls_back_to_a_generic_pt_br_message_for_unknown_types() -> None:
    assert message_validation("some_future_pydantic_code") == "Valor inválido."

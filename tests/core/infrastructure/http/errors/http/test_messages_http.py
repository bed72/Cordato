from http import HTTPStatus

from trocado.core.infrastructure.http.errors.http.messages_http import http_message


def test_translates_known_statuses_to_pt_br() -> None:
    assert http_message(HTTPStatus.BAD_REQUEST) == "Requisição inválida."
    assert http_message(HTTPStatus.NOT_FOUND) == "Recurso não encontrado."
    assert http_message(HTTPStatus.METHOD_NOT_ALLOWED) == "Método não permitido."


def test_falls_back_to_a_generic_pt_br_message_for_unlisted_statuses() -> None:
    assert http_message(HTTPStatus.IM_A_TEAPOT) == "Erro ao processar a requisição."

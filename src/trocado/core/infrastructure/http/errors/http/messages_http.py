from __future__ import annotations

from http import HTTPStatus

_FALLBACK = "Erro ao processar a requisição."

_HTTP_MESSAGES: dict[int, str] = {
    HTTPStatus.BAD_REQUEST: "Requisição inválida.",
    HTTPStatus.UNAUTHORIZED: "Não autenticado.",
    HTTPStatus.FORBIDDEN: "Acesso negado.",
    HTTPStatus.NOT_FOUND: "Recurso não encontrado.",
    HTTPStatus.METHOD_NOT_ALLOWED: "Método não permitido.",
    HTTPStatus.UNSUPPORTED_MEDIA_TYPE: "Tipo de mídia não suportado.",
    HTTPStatus.INTERNAL_SERVER_ERROR: "Erro interno do servidor.",
}


def http_message(status: int) -> str:
    """pt-BR message for a framework-raised HTTP error, by status — pure, framework-free.

    Frames errors the framework raises itself (malformed JSON → 400, unknown route → 404, …) so the envelope
    carries a generic pt-BR message instead of the framework's English detail (which can also leak parser
    internals like a byte offset). Falls back to a generic message for any status not listed.
    """
    return _HTTP_MESSAGES.get(status, _FALLBACK)

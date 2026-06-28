from __future__ import annotations

import uvicorn


def main() -> None:
    """Serve the ASGI app with uvicorn — the transitional dev entrypoint (no production server config).

    The app is passed as an **import string** (not the object) so uvicorn's ``reload`` actually works — reload
    and workers require an import target uvicorn can re-import in a child process. Matches ``poe serve``.
    """
    uvicorn.run(
        "trocado.core.infrastructure.http.app:app",
        port=8000,
        reload=True,
        host="127.0.0.1",
        log_level="debug",
    )


if __name__ == "__main__":
    main()

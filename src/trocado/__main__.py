from __future__ import annotations

import uvicorn

from trocado.core.infrastructure.http.app import app


def main() -> None:
    """Serve the ASGI app with uvicorn — the transitional dev entrypoint (no production server config)."""
    uvicorn.run(app, host="127.0.0.1", port=8000)


if __name__ == "__main__":
    main()

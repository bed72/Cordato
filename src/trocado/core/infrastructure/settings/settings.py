from __future__ import annotations

import os

DATABASE_URL: str = os.environ.get("DATABASE_URL", "sqlite+aiosqlite:///dev.db")

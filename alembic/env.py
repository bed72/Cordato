from __future__ import annotations  # isort: skip_file

import asyncio
import sys
from logging.config import fileConfig
from pathlib import Path

# Make the trocado package importable when alembic is invoked from the project root.
sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "src"))

from alembic import context  # noqa: E402
from sqlalchemy import Connection  # noqa: E402
from sqlalchemy.ext.asyncio import create_async_engine  # noqa: E402

from trocado.core.infrastructure.persistence.models.base_model import BaseModel  # noqa: E402
from trocado.core.infrastructure.settings import settings  # noqa: E402

target_metadata = BaseModel.metadata

alembic_config = context.config

if alembic_config.config_file_name is not None:
    fileConfig(alembic_config.config_file_name)


def do_run_migrations(connection: Connection) -> None:
    context.configure(
        render_as_batch=True,
        connection=connection,
        target_metadata=target_metadata,
    )
    with context.begin_transaction():
        context.run_migrations()


async def run_async_migrations() -> None:
    connectable = create_async_engine(settings.DATABASE_URL)
    async with connectable.connect() as connection:
        await connection.run_sync(do_run_migrations)
    await connectable.dispose()


def run_migrations_online() -> None:
    asyncio.run(run_async_migrations())


def run_migrations_offline() -> None:
    context.configure(
        url=settings.DATABASE_URL,
        literal_binds=True,
        render_as_batch=True,
        target_metadata=target_metadata,
        dialect_opts={"paramstyle": "named"},
    )
    with context.begin_transaction():
        context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()

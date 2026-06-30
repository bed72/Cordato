from __future__ import annotations

from collections.abc import AsyncGenerator

from sqlalchemy.ext.asyncio import AsyncEngine, AsyncSession, async_sessionmaker, create_async_engine

from trocado.core.infrastructure.settings import settings

engine: AsyncEngine = create_async_engine(settings.DATABASE_URL)

type AsyncSessionMaker = async_sessionmaker[AsyncSession]

session_factory: AsyncSessionMaker = async_sessionmaker(engine, expire_on_commit=False)


async def provide_database_session(
    db_session_factory: AsyncSessionMaker,
) -> AsyncGenerator[AsyncSession]:
    async with db_session_factory() as session:
        yield session

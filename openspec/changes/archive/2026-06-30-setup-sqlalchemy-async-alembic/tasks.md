## 1. Dependências

- [x] 1.1 Adicionar `sqlalchemy[asyncio]`, `aiosqlite` e `alembic` ao `pyproject.toml` via `uv add`
- [x] 1.2 Verificar que `uv.lock` foi atualizado e `uv sync` roda sem erro

## 2. Settings

- [x] 2.1 Criar `src/trocado/core/infrastructure/settings.py` com `DATABASE_URL` lido de `os.environ` com fallback `sqlite+aiosqlite:///dev.db`

## 3. Database

- [x] 3.1 Criar `src/trocado/core/infrastructure/database.py` com `AsyncEngine` criado via `create_async_engine(settings.DATABASE_URL)`
- [x] 3.2 Declarar `Base(DeclarativeBase)` no mesmo arquivo
- [x] 3.3 Declarar `async_sessionmaker` com `expire_on_commit=False` e tipo `AsyncSessionMaker = async_sessionmaker[AsyncSession]`
- [x] 3.4 Criar provider `provide_db_session` como async generator que faz `async with session_factory() as session: yield session`

## 4. DI no Litestar

- [x] 4.1 Registrar `db_session_factory` e `provide_db_session` em `core/main/core_provider.py` (ou equivalente no `build()` do app)

## 5. Alembic

- [x] 5.1 Inicializar Alembic na raiz com `alembic init alembic`
- [x] 5.2 Reescrever `alembic/env.py` com padrão async: `create_async_engine` + `run_sync(do_run_migrations)` + `render_as_batch=True`
- [x] 5.3 Apontar `target_metadata = Base.metadata` importando de `trocado.core.infrastructure.database`
- [x] 5.4 Comentar/remover `sqlalchemy.url` do `alembic.ini`; URL vem de `settings.DATABASE_URL` via `env.py`
- [x] 5.5 Adicionar `src/` ao `sys.path` no topo de `alembic/env.py` para que o import de `trocado` resolva

## 6. Verificação

- [x] 6.1 `uv run alembic upgrade head` roda sem erro (metadata vazia, nenhuma tabela criada ainda)
- [x] 6.2 `uv run poe check` passa sem erros (format, lint, mypy, pytest)

## Context

O projeto tem Clean Architecture com ports & adapters e "async everywhere" como regra inegociável. Hoje os repositórios são in-memory. Este change coloca a fundação de persistência — engine, session factory, settings e Alembic — sem tocar em nenhuma feature. Os próximos changes adicionarão `Model` + `ModelMapper` + `Repository` concreto por feature.

## Goals / Non-Goals

**Goals:**
- Engine async (`AsyncEngine`) configurável por `DATABASE_URL`
- `async_sessionmaker` como fábrica injetável via DI do Litestar
- `DeclarativeBase` disponível para os futuros `Model`s
- Módulo `settings.py` como ponto único de leitura de ENV vars
- Alembic com `env.py` async-aware pronto para receber metadata

**Non-Goals:**
- Nenhum `Model`, `Repository`, ou migração concreta neste change
- Sem `pydantic-settings` ou dotenv — `os.environ` é suficiente agora; env management avançado é change separado
- Sem fixture de banco de dados para testes — virá com o primeiro `Repository` concreto
- Sem conexão PostgreSQL — `asyncpg` entra quando PG for necessário

## Decisions

### 1. `os.environ` direto, não `pydantic-settings`

`pydantic-settings` adiciona parsing, validação e `.env` file. Para uma única variável agora, é overhead. O módulo `settings.py` expõe constantes no nível de módulo lidas no import; qualquer teste pode sobrescrever via `monkeypatch.setenv`. Quando o número de ENVs crescer (ex: secrets, feature flags), promovemos para `pydantic-settings` num change dedicado.

### 2. `DeclarativeBase` fica em `database.py`

Alternativa seria `core/infrastructure/models/base.py`. Mas enquanto não há nenhum `Model` concreto, colocar em `database.py` evita um arquivo praticamente vazio. Quando o primeiro `Model` chegar, o import já estará pronto: `from trocado.core.infrastructure.database import Base`.

### 3. Session como async generator no DI do Litestar

```python
async def provide_db_session(db_session_factory: AsyncSessionMaker) -> AsyncGenerator[AsyncSession, None]:
    async with db_session_factory() as session:
        yield session
```

Uma `AsyncSession` por request, com `autocommit=False`. O use case faz `await session.commit()` explicitamente. `expire_on_commit=False` evita lazy-load pós-commit em contexto async.

### 4. Alembic com `run_async_migrations`

O padrão oficial para Alembic + SQLAlchemy async:

```python
async def run_async_migrations() -> None:
    connectable = create_async_engine(settings.DATABASE_URL)
    async with connectable.connect() as connection:
        await connection.run_sync(do_run_migrations)
```

`env.py` detecta se está em modo online (rodando migration) ou offline (gerando SQL puro). `target_metadata = Base.metadata` — sem `Model`s ainda, a metadata está vazia; as próximas migrations a preencherão.

### 5. `alembic.ini` sem hardcode de URL

`sqlalchemy.url` em `alembic.ini` é ignorado; a URL vem de `env.py` via `settings.DATABASE_URL`. Isso garante que migrations de prod e dev leem do mesmo `DATABASE_URL` do ambiente.

## Risks / Trade-offs

- **SQLite não suporta `ALTER COLUMN` ou `DROP COLUMN`** → Alembic tem `render_as_batch=True` para contornar via recriação de tabela. Configurar isso agora em `env.py` para evitar surpresa na primeira migration de schema change.
- **`expire_on_commit=False` pode servir dados stale** → Aceitável; as use cases não reutilizam a sessão após o commit.
- **Alembic com metadata vazia gera migration vazia** → Esperado; a primeira migration real vem com o primeiro `Model`.

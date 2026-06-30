## Why

O projeto roda hoje com repositórios in-memory; nenhum dado sobrevive ao restart. Antes de qualquer feature de persistência poder ser implementada, precisamos de um engine async configurado, uma session factory injetável, um módulo de settings para ENV vars, e o Alembic pronto para gerar migrations — tudo isso sem tocar em nenhuma feature existente.

## What Changes

- Adicionar dependências de runtime: `sqlalchemy[asyncio]`, `aiosqlite`
- Adicionar dependência de runtime: `alembic`
- Criar módulo `core/infrastructure/settings.py` que lê `DATABASE_URL` (e futuras ENVs) via `os.environ`
- Criar `core/infrastructure/database.py` com engine async e `async_sessionmaker`
- Inicializar o Alembic em `alembic/` com `env.py` async-aware (usa `AsyncEngine`, `run_async_migrations`)
- Configurar `alembic.ini` apontando para `DATABASE_URL` por variável de ambiente
- Nenhum `Model`, `Repository` ou feature tocada neste change

## Capabilities

### New Capabilities

- `database-session`: session factory async (`AsyncSession`) configurável por `DATABASE_URL`, exposta como porta de DI no Litestar
- `app-settings`: módulo de leitura de variáveis de ambiente centralizado (`core/infrastructure/settings.py`) — ponto único de acesso a `DATABASE_URL` e futuras ENVs
- `database-migrations`: Alembic inicializado com `env.py` async, pronto para receber `Model`s nas próximas features

### Modified Capabilities

## Impact

- `pyproject.toml`: novas deps `sqlalchemy[asyncio]`, `aiosqlite`, `alembic`
- `src/trocado/core/infrastructure/`: dois arquivos novos (`settings.py`, `database.py`)
- Raiz do projeto: diretório `alembic/` + `alembic.ini`
- Nenhuma rota, nenhum use case, nenhum repositório existente alterado

## ADDED Requirements

### Requirement: Alembic inicializado com env.py async-aware
O sistema SHALL ter o Alembic configurado com um `env.py` que usa `AsyncEngine` e `run_sync` para executar migrations de forma não-bloqueante. O `target_metadata` SHALL apontar para `Base.metadata`.

#### Scenario: Comando de migration bem-sucedido
- **WHEN** `alembic upgrade head` é executado com `DATABASE_URL` definido
- **THEN** o comando conecta ao banco, aplica migrations pendentes e retorna sem erro

#### Scenario: Metadata vazia não gera erro
- **WHEN** nenhum `Model` foi registrado em `Base.metadata` ainda
- **THEN** `alembic upgrade head` termina sem erro (nenhuma tabela criada)

### Requirement: URL do banco vinda exclusivamente do ambiente
O sistema SHALL ler `DATABASE_URL` em `env.py` via `settings.DATABASE_URL`. O campo `sqlalchemy.url` em `alembic.ini` SHALL estar desabilitado (comentado) para evitar hardcode acidental.

#### Scenario: Migration em produção usa URL do ambiente
- **WHEN** `DATABASE_URL=postgresql+asyncpg://...` está no ambiente e `alembic upgrade head` é executado
- **THEN** o Alembic conecta ao PostgreSQL, não ao SQLite

#### Scenario: Migration sem DATABASE_URL usa fallback
- **WHEN** `DATABASE_URL` não está no ambiente
- **THEN** o Alembic usa `sqlite+aiosqlite:///dev.db`

### Requirement: render_as_batch habilitado para compatibilidade com SQLite
O sistema SHALL configurar `render_as_batch=True` no contexto de migration do Alembic. Isso permite que `ALTER TABLE` via recriação funcione no SQLite, que não suporta `ALTER COLUMN` ou `DROP COLUMN` nativos.

#### Scenario: Schema change em SQLite não falha
- **WHEN** uma migration adiciona uma coluna com constraint ou renomeia uma coluna existente
- **THEN** o Alembic usa batch mode para recriar a tabela no SQLite sem erro

### Requirement: Estrutura de diretórios do Alembic na raiz do projeto
O sistema SHALL criar o diretório `alembic/` na raiz do projeto contendo `env.py`, `script.py.mako` e `versions/`. O arquivo `alembic.ini` SHALL estar na raiz do projeto.

#### Scenario: Diretório de versões presente
- **WHEN** `alembic revision --autogenerate -m "init"` é executado
- **THEN** um arquivo de migration é criado em `alembic/versions/`

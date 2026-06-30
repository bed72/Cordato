## ADDED Requirements

### Requirement: Engine async configurável por DATABASE_URL
O sistema SHALL criar um `AsyncEngine` SQLAlchemy usando o valor de `settings.DATABASE_URL`. O engine SHALL ser criado uma única vez na inicialização da aplicação e reutilizado durante todo o ciclo de vida do processo.

#### Scenario: Engine com URL padrão
- **WHEN** `DATABASE_URL` não está definido no ambiente
- **THEN** o engine usa `sqlite+aiosqlite:///dev.db` como URL

#### Scenario: Engine com URL customizada
- **WHEN** `DATABASE_URL` está definido no ambiente (ex: `sqlite+aiosqlite:///test.db`)
- **THEN** o engine usa o valor fornecido

### Requirement: Session factory async injetável
O sistema SHALL expor um `async_sessionmaker[AsyncSession]` como fábrica de sessões. A factory SHALL ser registrada no DI do Litestar com a chave `db_session_factory`.

#### Scenario: Factory disponível via DI
- **WHEN** um controller ou use case declara `db_session_factory: AsyncSessionMaker` como dependência
- **THEN** o Litestar injeta a instância da factory

### Requirement: AsyncSession por request
O sistema SHALL fornecer uma `AsyncSession` isolada por request HTTP via provider async generator. A sessão SHALL ser fechada automaticamente ao final do request, com ou sem erro.

#### Scenario: Session aberta e fechada no ciclo do request
- **WHEN** um handler HTTP conclui (com sucesso ou exceção)
- **THEN** a sessão é fechada e devolvida ao pool

#### Scenario: Commit explícito pelo use case
- **WHEN** o use case chama `await session.commit()`
- **THEN** a transação é persistida; a sessão permanece aberta até o fim do request

### Requirement: DeclarativeBase disponível para models
O sistema SHALL exportar uma `Base` (`DeclarativeBase`) de `core/infrastructure/database.py`. Todos os futuros `Model`s SHALL herdar de `Base`.

#### Scenario: Import do Base por um Model futuro
- **WHEN** um arquivo de model executa `from trocado.core.infrastructure.database import Base`
- **THEN** a importação resolve sem erro e `Base.metadata` contém o model registrado

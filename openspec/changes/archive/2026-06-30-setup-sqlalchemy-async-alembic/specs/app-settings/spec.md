## ADDED Requirements

### Requirement: Módulo de settings como ponto único de ENVs
O sistema SHALL expor um módulo `core/infrastructure/settings.py` que lê variáveis de ambiente via `os.environ`. Todo código que precisar de uma ENV SHALL importar de `settings`, nunca chamar `os.environ` diretamente fora deste módulo.

#### Scenario: Leitura de DATABASE_URL com fallback
- **WHEN** `DATABASE_URL` não está definido no ambiente
- **THEN** `settings.DATABASE_URL` retorna `"sqlite+aiosqlite:///dev.db"`

#### Scenario: Leitura de DATABASE_URL definida
- **WHEN** `DATABASE_URL=sqlite+aiosqlite:///custom.db` está no ambiente no momento do import
- **THEN** `settings.DATABASE_URL` retorna `"sqlite+aiosqlite:///custom.db"`

### Requirement: Substituível em testes sem monkey-patch do os.environ
O sistema SHALL permitir que testes sobrescrevam settings via `monkeypatch.setenv` antes do import ou reimport do módulo, sem depender de mocks de `os.environ` espalhados pelos testes.

#### Scenario: Override de DATABASE_URL em teste
- **WHEN** um teste define `DATABASE_URL=sqlite+aiosqlite:///:memory:` antes de importar o módulo de database
- **THEN** o engine usa `:memory:` como banco isolado para aquele teste

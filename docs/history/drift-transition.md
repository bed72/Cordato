# Transição para Drift — registro de 23/11/2026

Este registro preserva decisões intermediárias e resultados executados durante
a transição. Não é um contrato vigente, checklist de funcionalidades disponíveis
ou autorização para restaurar Localstore. Consulte [README](../../README.md),
[ARCHITECTURE](../../ARCHITECTURE.md) e [AGENTS](../../AGENTS.md).

## Sequência das entregas

1. Fundação em `core/infrastructure/clients/database/`: DatabaseClient como
   banco tipado, tabelas de perfil/despesas, constraints, índice e cascade.
   A retirada de Localstore antecedeu a migração dos consumidores; a interrupção
   temporária de compilação foi autorizada, sem reintroduzir a dependência.
2. Registro lazy no coreModule, síncrono e sem abrir storage ao resolver DI.
   O fechamento assíncrono pelo root permaneceu pendente.
3. UserRepository passou a usar SQLite em transações, criando perfil sob demanda
   com nome Cordato e seed aleatória. `avatar` passou a `seed` nos contratos,
   entidade, apresentação e previews.
4. IDs inicialmente textuais foram substituídos por inteiros AUTOINCREMENT nas
   duas tabelas; profile_id e contratos de User foram ajustados. Sem usuários,
   o schema experimental 1 foi redefinido sem migração dos arquivos com IDs
   textuais. Não foi criado reset automático.
5. ExpenseRepository, IDs de despesas, navegação, Blocs e previews passaram a
   SQLite. Criação depende do perfil já inicializado por User, com falha segura
   quando ausente. Metrics e composição global não foram migrados.
6. A primeira implementação de sugestões percorria páginas SQL de 100 registros,
   filtrando em Dart para manter matching literal Unicode. Foi substituída por
   SuggestionsDao, com CTE materializada, filtro literal, limite de 30 e
   deduplicação posterior por ROW_NUMBER. `cordato_lower` foi registrado na
   conexão; o índice existente foi verificado no plano de consulta.
7. CRUD de Expense passou a uma instrução de escrita por mutação: INSERT SELECT
   RETURNING, UPDATE RETURNING e DELETE por linhas afetadas. Create/update
   mantiveram transação para rollback do mapeamento e publicação após commit.
8. Schema 2 acrescentou default SQL `date('now', 'localtime')` em occurred_on.
   Create sem data omite a coluna; datas explícitas prevalecem. A migração do
   schema 1 de IDs inteiros preserva dados, relações, índices e sequências,
   incluindo despesas já excluídas. `_hasUpdates` isolou a checagem de campos.
9. Nomes atuais são CategoryEnum (`domain/enums/category_enum.dart`) e
   SuggestionsDao (`infrastructure/daos/suggestions_dao.dart`). Referências a
   ExpenseCategoryEnum/ExpenseSuggestionsDao em relatos anteriores são históricas.

Não foram implementados exclusão de perfil pela UI, troca atômica do perfil,
limpeza do snapshot nativo após exclusão, IA, views ou backup/restauração.

## Resultados registrados durante as etapas

| Etapa | Verificação registrada |
| --- | --- |
| Fundação Drift | `flutter pub get` e `dart run build_runner build` concluídos; análise focada limpa; 27 testes do client passando. |
| Fundação + arquitetura | 116 passando e uma falha no teste que ainda exige Localstore no lockfile. |
| Registro no core | Três testes do módulo passando; análise focada limpa; arquitetura + client + módulo com 119 passando e a mesma falha legada. Análise global com 97 diagnósticos. |
| Antes do registro no core | Suíte global: 770 passando e 10 falhas ligadas ao Localstore ausente. |
| Migração de User | 141 testes de User/Dashboard passando; análise focada limpa. |
| User + IDs autoincrementais | 173 testes de client/core/User/Dashboard passando; análise focada limpa; suíte global com 804 passando e seis falhas; análise global com 51 diagnósticos legados. |
| Migração de Expense | 346 testes de Expense/Dashboard passando; análise focada limpa; arquitetura + Expense/Dashboard/User/core com 558 passando e uma falha legada. Suíte global: 844 passando e quatro falhas; análise global: 32 diagnósticos. |
| Otimização SQL/DAO | 334 testes de Expense/client passando; análise focada limpa; suíte global com 860 passando e quatro falhas; análise global com 32 diagnósticos. |
| Default de data / schema 2 | 343 testes de Expense/client/migração passando; análise focada limpa; suíte global com 869 passando e quatro falhas; análise global com 32 diagnósticos. |

Os números são retratos distintos, não contagens cumulativas nem uma medição de
cobertura. Testes de parsing JSON do legado foram substituídos por testes dos
contratos tipados/constraints correspondentes, sem manter mecanismos removidos.

### Últimos comandos registrados

```bash
flutter pub get
dart run build_runner build
flutter analyze
flutter test --reporter failures-only
flutter test test/features/core/infrastructure/clients/database test/features/expense --reporter failures-only
```

As análises focadas usaram os diretórios de produção/testes de core/database e
Expense. Os quatro bloqueios da suíte global foram:

- carregamento de `test/features/metrics/metrics_module_test.dart`;
- carregamento de `test/features/metrics/infrastructure/repositories/metrics_repository_test.dart`;
- `test/architecture/localstore_dependency_test.dart`, ainda exigindo o fork;
- carregamento de `test/app_module_test.dart`.

### Datas locais e migração

O teste de localtime próximo à virada do dia UTC foi executado no host com:

```bash
TZ=UTC flutter test test/features/core/infrastructure/clients/database/database_client_test.dart --plain-name 'localtime respeita componentes locais junto à virada do dia UTC' --reporter failures-only
TZ=America/Sao_Paulo flutter test test/features/core/infrastructure/clients/database/database_client_test.dart --plain-name 'localtime respeita componentes locais junto à virada do dia UTC' --reporter failures-only
```

Ambos passaram, um teste por execução. O fixture
`test/support/core/storage/schema_v1.sql` permitiu testar upgrade, conservação da
sequência com IDs excluídos/tabela vazia e rollback em falha de migração.

Testes reais também verificaram SQL sem SELECT preparatório nas mutações,
RETURNING, publicação de observadores somente após commit, busca literal com
acentos e caracteres especiais, limite antes da deduplicação e reabertura de
arquivo em isolate.

## Limites da evidência

Não foram executados novos builds nativos, homologação visual, benchmark em
dispositivo, auditoria de corrupção/durabilidade ou release remoto nessas etapas.
O teste de fuso no host não homologa Android/iOS. O checkout continuava sem
compilação global por causa de Metrics/composição.

O workflow Android ainda exigia LOCALSTORE_READ_TOKEN, apesar de a dependência
ter sido retirada. Não foi modificado nem executado; sua revisão ficou pendente.
Os resultados nativos de 22/11/2026 pertencem à
[transição local anterior](local-transition.md), não validam a versão Drift.

## Consolidação documental

Na revisão documental seguinte, apenas Markdown foi alterado. As referências
locais dos oito guias/registros revisados foram conferidas sem arquivos ausentes;
`git diff --check` não apontou whitespace inválido. A conferência de espelhamento
encontrou 66 testes de features, 57 com correspondência exata; os nove casos
restantes estão na arquitetura, sem mover testes nesta revisão.
Nenhuma suíte Flutter/nativa ou publicação foi reexecutada por essa edição.

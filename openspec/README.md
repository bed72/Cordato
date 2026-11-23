# OpenSpec: estado vigente e histórico

Revisado em **23/11/2026** para a transição local para Drift/SQLite.

## Precedência

1. [AGENTS.md](../AGENTS.md): regras de implementação e testes.
2. [ARCHITECTURE.md](../ARCHITECTURE.md): decisões e contratos atuais.
3. [README.md](../README.md): produto, execução, limites e verificação.
4. Specs e changes: requisitos compatíveis, sujeitos às decisões atuais.

O app é exclusivamente local. Authentication, Session, Welcome, PocketBase, backend,
worker, áudio, IA, Insight, CSV e compartilhamento foram removidos.
Não restaure essas funcionalidades para satisfazer uma spec anterior.
Não há servidor necessário para executar o Flutter, identidade autenticada,
`owner` em despesas ou backup/restauração disponível.

## Arquitetura vigente

```text
Screen/Widget → Bloc → contrato em application
                            ↑
                 repository em infrastructure → DatabaseClient (User/Expense)
                                             → Localstore legado (Metrics, bloqueado)
                                             → client nativo do core
```

Contratos usam Future e exceções de aplicação, sem Either, CommandIt ou data
sources intermediários. Domain é puro; dinheiro usa centavos inteiros.
Metrics é projeção mensal somente leitura, ainda no código legado Localstore e
não integrada à tabela SQLite de Expense.
Seus totais mensal e por categoria usam `total` inteiro em centavos; os grupos
são construídos em Dart, sem parser JSON de agregados ou Bloc próprio de Metrics.

UserRepository cria o perfil padrão na primeira leitura, se ausente, sem
inicializador no bootstrap. Usa `profiles` com ID int gerado pelo SQLite, nome e
seed aleatória. `coreModule` registra DatabaseClient como singleton lazy, sem
abrir arquivo ao resolver DI. O client é o banco tipado Drift, não wrapper CRUD.
Contratos, entidades e apresentação não recebem tipos do SDK.

Expense usa IDs int, profile_id interno com cascade, CRUD SQL/RETURNING e
SuggestionsDao em infrastructure. Sugestões filtram correspondências literais
Unicode, limitam às 30 mais recentes e deduplicam depois por janela. CategoryEnum
fica em `expense/domain/enums/category_enum.dart`.

Schema atual 2: default civil local `date('now', 'localtime')` ao omitir a data.
Migração SQLite 1→2 preserva dados e sequências. Não há migração de
Localstore/ToStore nem restauração do fork privado, retirado das dependências.
O client registra cordato_lower; executors nativos injetados usam o mesmo setup.
Detalhes estão na [fundação Drift](../ARCHITECTURE.md#fundação-drift).

Metrics, composição e testes legados ainda impedem análise/compilação globais.
A migração interrompida foi autorizada; não reintroduza dependências, ownership
remoto ou wrappers para satisfazer documentos anteriores.
Apagar perfil/recriar padrão, limpar widget, views e IA continuam pendentes;
FK/cascade preparados não tornam essas funcionalidades disponíveis.

ExpenseSuggestionsBloc pertence ao provide da rota. Os demais ownerships
existentes são preservados: screens com factories estáveis e Root com os Blocs
de launch/sync no AppWidget. Não há SessionBloc. Navegação nova usa BuildContext,
argumentos transportam dados e retornos confirmados são tipados.
Root usa `WidgetLaunchBloc`, `WidgetSyncBloc`, `IWidgetLaunchRepository` e
`IWidgetSyncRepository`, com arquivos `widget_*`. Referências antigas a
`HomeWidget*` em specs são históricas, não orientação para restaurar nomes.
O plugin `home_widget` e a URI nativa com `homeWidget=true` permanecem.

Testes devem espelhar nomes/pastas da implementação. A conferência atual,
incluindo desvios legados e suítes separadas por responsabilidade, está em
[ARCHITECTURE.md](../ARCHITECTURE.md#organização-e-espelhamento-dos-testes).
Esta atualização não move testes, sincroniza specs nem altera checklists.

## Como ler as specs existentes

O diretório `specs/` conserva requisitos de diferentes etapas e **ainda não foi
integralmente sincronizado com a versão local**. A existência de um arquivo não
torna seu mecanismo atual. Esta revisão não sincroniza deltas nem arquiva changes.

| Documento | Uso atual |
| --- | --- |
| `specs/dashboard-monthly-navigation/` | Regras mensais e retorno da listagem; implementação por Bloc e contratos locais. |
| `specs/expense-category-metrics-cards/` | Cards e navegação por categoria/período; Metrics legado ainda usa Localstore e não está integrado às despesas SQLite. |
| `specs/expenses-period-query/`, `specs/expenses-removable-filters/` | Comportamento de datas/filtros; transporte HTTP e owner remoto não se aplicam. |
| `specs/expense-reregistration/` | Referência do comportamento de novo cadastro; subordinada à implementação local atual. |
| `specs/shared-error-screen/`, `specs/dart-primary-constructor-conventions/` | Requisitos visuais/linguagem sujeitos às convenções atuais. |
| `specs/settings-screen-ui/` | Somente requisitos visuais compatíveis; não há logout ou seção Dados. |
| `specs/authentication-session-logout/` | Histórico de funcionalidade removida. |
| `specs/expense-csv-export/` | Histórico de funcionalidade removida; CSV não é backup restaurável. |
| `specs/insights-monthly-query/` | Histórico de Insight removido; não confundir com Metrics atual. |
| `specs/presentation-command-*`, `specs/expense-reactive-command-consumption/`, `specs/dashboard-reactive-command-coordination/` | Intenções de UX/concorrência compatíveis podem orientar; commands/Either não são arquitetura aprovada. |
| `changes/migrate-expense-to-tostore/` | Registro histórico, incluindo CSV removido depois. ToStore foi substituído por Localstore e Expense depois passou a Drift; a change não descreve a persistência vigente. |
| `changes/archive/` | Histórico temporal de decisões/resultados, não guia vigente nem comprovação de execução atual. |

Ao implementar requisito antigo, adapte o mecanismo às decisões canônicas e
registre conflitos. Não marque tarefas ou verificações pendentes como concluídas
por atualizar documentação; não enfraqueça testes ou declare E2E aprovado.
Históricos detalhados permanecem intactos.
Decisões/resultados da transição Drift estão em
[docs/history/drift-transition.md](../docs/history/drift-transition.md), sem
sincronizar deltas, editar specs históricas ou marcar tarefas como concluídas.

## Registro do arquivamento de 09/11/2026

As quatro changes então ativas foram arquivadas por solicitação explícita, sem
sincronizar deltas com as specs principais e sem declarar pendências concluídas:

- `add-pocketbase-audio-intake`: 19/19 tarefas; registro transferido na época
  para projeto Go independente. Áudio não está disponível no app atual.
- `add-authenticated-password-change`: 26/27; revisão visual histórica pendente.
- `migrate-dashboard-to-bloc`: 39/40; validação visual histórica pendente, sem
  autorização para restaurar Maestro ou testes de UI.
- `add-pocketbase-family-memberships`: sem proposta, design, specs ou tarefas.

Os arquivos e checklists de `changes/archive/` permanecem preservados.
Família continua planejada. Resultados de etapas locais estão no
[histórico da transição](../docs/history/local-transition.md).

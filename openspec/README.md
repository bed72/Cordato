# OpenSpec: estado vigente e histórico

Revisado em **24/11/2026** para Drift/SQLite e exportação CSV local.

## Precedência

1. [AGENTS.md](../AGENTS.md): regras de implementação e testes.
2. [ARCHITECTURE.md](../ARCHITECTURE.md): decisões e contratos atuais.
3. [README.md](../README.md): produto, execução, limites e verificação.
4. Specs e changes: requisitos compatíveis, sujeitos às decisões atuais.

O app é exclusivamente local. Authentication, Session, Welcome, PocketBase, backend,
worker, áudio, IA e Insight foram removidos.
Não restaure essas funcionalidades para satisfazer uma spec anterior.
CSV e compartilhamento foram reintroduzidos por solicitação explícita, sobre
Drift e arquivos temporários locais, sem restaurar o transporte remoto antigo.
Não há servidor necessário para executar o Flutter, identidade autenticada,
`owner` em despesas ou backup/restauração disponível.

## Arquitetura vigente

```text
Screen/Widget → Bloc → contrato em application
                            ↑
                 repository em infrastructure → DatabaseClient (User/Expense)
                                             → MetricsDao → DatabaseClient
                                             → client nativo do core
```

Contratos usam Future e exceções de aplicação, sem Either, CommandIt ou data
sources intermediários. Domain é puro; dinheiro usa centavos inteiros.
Metrics é projeção mensal somente leitura da tabela SQLite de Expense, pelo
MetricsDao sobre o mesmo DatabaseClient compartilhado.
Seus totais mensal e por categoria usam `total` inteiro em centavos; os grupos
são construídos em uma consulta SQL, sem parser JSON de agregados ou Bloc próprio
de Metrics.

UserRepository cria o perfil padrão na primeira leitura, se ausente, sem
inicializador no bootstrap. Usa `profiles` com ID int gerado pelo SQLite, nome e
seed aleatória. `coreModule` registra DatabaseClient como singleton lazy, sem
abrir arquivo ao resolver DI. O client é o banco tipado Drift, não wrapper CRUD.
Contratos, entidades e apresentação não recebem tipos do SDK.

Expense usa IDs int, profile_id interno com cascade, CRUD SQL/RETURNING e
SuggestionsDao em infrastructure. Sugestões filtram correspondências literais
Unicode, limitam às 30 mais recentes e deduplicam depois por janela. CategoryEnum
fica em `expense/domain/enums/category_enum.dart`.

Schema atual 1 consolidado: IDs AUTOINCREMENT, CHECK de categorias e default civil
local `date('now', 'localtime')` ao omitir a data. Não há migração de versões
experimentais anteriores, Localstore/ToStore ou restauração do fork privado,
retirado das dependências. Bancos experimentais incompatíveis precisam ser
recriados manualmente; o app não apaga arquivos nem faz reset automático.
O client registra cordato_lower; executors nativos injetados usam o mesmo setup.
Detalhes estão na [fundação Drift](../ARCHITECTURE.md#fundação-drift).

Metrics e composição global já usam Drift, sem bloqueio legado de Localstore.
Não reintroduza dependências, ownership remoto ou wrappers para satisfazer
documentos anteriores.
Apagar perfil/recriar padrão e limpar widget nessa operação continuam pendentes;
FK/cascade preparados não tornam essas funcionalidades disponíveis.
Views não fazem parte desta entrega; IA permanece removida.

ExpenseSuggestionsBloc e ExportBloc pertencem ao provide das respectivas rotas.
ExportExpensesWidget mostra progresso no lugar da seta e bloqueia novos cliques
durante preparação/compartilhamento, sem descrição. Contratos de compartilhamento
usam caminho String e não transportam coordenadas; a origem fixa do iPad é
detalhe interno do client. CSV não é criptografado nem um backup restaurável.
Os demais ownerships
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
| `specs/expense-category-metrics-cards/` | Cards e navegação por categoria/período; Metrics consulta despesas SQLite por MetricsDao, sem Localstore. |
| `specs/expenses-period-query/`, `specs/expenses-removable-filters/` | Comportamento de datas/filtros; transporte HTTP e owner remoto não se aplicam. |
| `specs/expense-reregistration/` | Referência do comportamento de novo cadastro; subordinada à implementação local atual. |
| `specs/shared-error-screen/`, `specs/dart-primary-constructor-conventions/` | Requisitos visuais/linguagem sujeitos às convenções atuais. |
| `specs/settings-screen-ui/` | Somente requisitos visuais compatíveis; não há logout. Dados contém exportação CSV local. |
| `specs/authentication-session-logout/` | Histórico de funcionalidade removida. |
| `specs/expense-csv-export/` | Referência histórica da exportação remota. O fluxo atual é local, sem autenticação/internet obrigatória, paginação ou descrição de progresso no item; prevalecem os contratos canônicos. CSV não é backup restaurável. |
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

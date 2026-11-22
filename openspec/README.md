# OpenSpec: estado vigente e histórico

Revisado em **22/11/2026** para a versão local com Localstore.

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
                 repository em infrastructure → Localstore / client nativo do core
```

Contratos usam Future e exceções de aplicação, sem Either, CommandIt ou data
sources intermediários. Domain é puro; dinheiro usa centavos inteiros.
Metrics é projeção mensal somente leitura das despesas locais.
Seus totais mensal e por categoria usam `total` inteiro em centavos; os grupos
são construídos em Dart, sem parser JSON de agregados ou Bloc próprio de Metrics.

UserRepository cria o perfil padrão na primeira leitura, se ausente, sem
inicializador no bootstrap. Usa um documento com nome e avatar. `coreModule` registra
`Localstore.instance`; repositories recebem o SDK diretamente por construtor,
sem client de persistência, schemas ou factory. O SDK vem do fork privado
`bed72/localstore`, via Git com `ref: main` e commit resolvido no lockfile;
não da versão do pub.dev. Atualizações usam `flutter pub upgrade localstore`.
Dados antigos de ToStore não são migrados. Filtros, paginação, sugestões e
métricas são calculados em Dart. O fork aguarda escritas e propaga erros de JSON;
as limitações antigas de 1.4.0 não descrevem mais a implementação vigente.
Limitações do SDK e confirmação de escrita estão em
[ARCHITECTURE.md](../ARCHITECTURE.md#bootstrap-e-composição).

ExpenseSuggestionsBloc pertence ao provide da rota. Os demais ownerships
existentes são preservados: screens com factories estáveis e Root com os Blocs
de launch/sync no AppWidget. Não há SessionBloc. Navegação nova usa BuildContext,
argumentos transportam dados e retornos confirmados são tipados.
Root usa `WidgetLaunchBloc`, `WidgetSyncBloc`, `IWidgetLaunchRepository` e
`IWidgetSyncRepository`, com arquivos `widget_*`. Referências antigas a
`HomeWidget*` em specs são históricas, não orientação para restaurar nomes.
O plugin `home_widget` e a URI nativa com `homeWidget=true` permanecem.

Testes devem espelhar nomes/pastas da implementação. A conferência atual,
incluindo as sete exceções de correspondência exata, está em
[ARCHITECTURE.md](../ARCHITECTURE.md#organização-e-espelhamento-dos-testes).
Esta atualização não move testes, sincroniza specs nem altera checklists.

## Como ler as specs existentes

O diretório `specs/` conserva requisitos de diferentes etapas e **ainda não foi
integralmente sincronizado com a versão local**. A existência de um arquivo não
torna seu mecanismo atual. Esta revisão não sincroniza deltas nem arquiva changes.

| Documento | Uso atual |
| --- | --- |
| `specs/dashboard-monthly-navigation/` | Regras mensais e retorno da listagem; implementação por Bloc e contratos locais. |
| `specs/expense-category-metrics-cards/` | Cards e navegação por categoria/período; dados vêm do Localstore. |
| `specs/expenses-period-query/`, `specs/expenses-removable-filters/` | Comportamento de datas/filtros; transporte HTTP e owner remoto não se aplicam. |
| `specs/expense-reregistration/` | Referência do comportamento de novo cadastro; subordinada à implementação local atual. |
| `specs/shared-error-screen/`, `specs/dart-primary-constructor-conventions/` | Requisitos visuais/linguagem sujeitos às convenções atuais. |
| `specs/settings-screen-ui/` | Somente requisitos visuais compatíveis; não há logout ou seção Dados. |
| `specs/authentication-session-logout/` | Histórico de funcionalidade removida. |
| `specs/expense-csv-export/` | Histórico de funcionalidade removida; CSV não é backup restaurável. |
| `specs/insights-monthly-query/` | Histórico de Insight removido; não confundir com Metrics atual. |
| `specs/presentation-command-*`, `specs/expense-reactive-command-consumption/`, `specs/dashboard-reactive-command-coordination/` | Intenções de UX/concorrência compatíveis podem orientar; commands/Either não são arquitetura aprovada. |
| `changes/migrate-expense-to-tostore/` | Registro histórico da migração de Expense, incluindo CSV removido depois. ToStore foi substituído por Localstore; a change não descreve a persistência vigente. |
| `changes/archive/` | Histórico temporal de decisões/resultados, não guia vigente nem comprovação de execução atual. |

Ao implementar requisito antigo, adapte o mecanismo às decisões canônicas e
registre conflitos. Não marque tarefas ou verificações pendentes como concluídas
por atualizar documentação; não enfraqueça testes ou declare E2E aprovado.
Históricos detalhados permanecem intactos.

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

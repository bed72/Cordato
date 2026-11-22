# OpenSpec: estado vigente e histórico

Revisado em **22/11/2026** para a versão local com ToStore.

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
                 repository em infrastructure → ToStore / client nativo do core
```

Contratos usam Future e exceções de aplicação, sem Either, CommandIt ou data
sources intermediários. Domain é puro; dinheiro usa centavos inteiros.
Metrics é projeção mensal somente leitura das despesas locais.

O bootstrap abre o banco e inicializa o perfil antes de runApp.
Somente `createAppModule` recebe o ToStore e registra `addInstance` no módulo
raiz. `coreModule` e features não recebem o banco por parâmetro. Repositories
usam injeção por construtor, sem singleton global manual.

ExpenseSuggestionsBloc pertence ao provide da rota. Os demais ownerships
existentes são preservados: screens com factories estáveis e Root com os Blocs
de launch/sync no AppWidget. Não há SessionBloc. Navegação nova usa BuildContext,
argumentos transportam dados e retornos confirmados são tipados.

## Como ler as specs existentes

O diretório `specs/` conserva requisitos de diferentes etapas e **ainda não foi
integralmente sincronizado com a versão local**. A existência de um arquivo não
torna seu mecanismo atual. Esta revisão não sincroniza deltas nem arquiva changes.

| Documento | Uso atual |
| --- | --- |
| `specs/dashboard-monthly-navigation/` | Regras mensais e retorno da listagem; implementação por Bloc e contratos locais. |
| `specs/expense-category-metrics-cards/` | Cards e navegação por categoria/período; dados vêm do ToStore. |
| `specs/expenses-period-query/`, `specs/expenses-removable-filters/` | Comportamento de datas/filtros; transporte HTTP e owner remoto não se aplicam. |
| `specs/expense-reregistration/` | Referência do comportamento de novo cadastro; subordinada à implementação local atual. |
| `specs/shared-error-screen/`, `specs/dart-primary-constructor-conventions/` | Requisitos visuais/linguagem sujeitos às convenções atuais. |
| `specs/settings-screen-ui/` | Somente requisitos visuais compatíveis; não há logout ou seção Dados. |
| `specs/authentication-session-logout/` | Histórico de funcionalidade removida. |
| `specs/expense-csv-export/` | Histórico de funcionalidade removida; CSV não é backup restaurável. |
| `specs/insights-monthly-query/` | Histórico de Insight removido; não confundir com Metrics atual. |
| `specs/presentation-command-*`, `specs/expense-reactive-command-consumption/`, `specs/dashboard-reactive-command-coordination/` | Intenções de UX/concorrência compatíveis podem orientar; commands/Either não são arquitetura aprovada. |
| `changes/migrate-expense-to-tostore/` | Registro da migração de Expense, incluindo CSV removido depois. Não descreve todo o produto atual. |
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

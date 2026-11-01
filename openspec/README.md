# OpenSpec: Referência Atual E Histórico

## Precedência

As decisões atuais estão em [ARCHITECTURE.md](../ARCHITECTURE.md) e as regras de
implementação em [AGENTS.md](../AGENTS.md). [README.md](../README.md) registra
produto, execução e limitações. Specs e changes antigas podem descrever uma
implementação que já foi substituída; não as use para restaurar Supabase/RPC,
CommandIt, Either, data sources ou callbacks de navegação.

Atualizar documentação não executa migrações, não conclui tarefas de changes
antigas e não comprova DI, build ou E2E. O histórico de `changes/archive/` é
preservado como registro temporal, não como guia de implementação vigente.

## Backend Adotado E Integração Pendente

O serviço atual é PocketBase 0.41.1 em [`backend/`](../backend/README.md), com
coleções `users` e `expenses` e APIs nativas. O cliente Flutter ainda usa o
contrato HTTP anterior. Specs que descrevem JSON:API, revogação de token,
confirmação por URL assinada ou endpoints de métricas/insights/sugestões não
comprovam suporte desses contratos pelo PocketBase nem autorizam recriá-los.

Consulte os [limites de integração](../ARCHITECTURE.md#backend-pocketbase-e-limite-de-integração)
antes de implementar. Esta revisão é documental: não conclui a migração do
cliente, não altera schema e não migra dados. Specs arquivadas permanecem intactas.

## Arquitetura Vigente

```text
Screen/Widget -> Bloc -> contrato em application
                            ^
                 repository em infrastructure -> clients do core
```

Contratos usam `Future<T>` e exceções de aplicação. Domain é puro, valores
monetários são centavos inteiros e família é uma lente de leitura autorizada.

Modular V7 organiza DI e rotas com `createModule`. Para estado de página novo ou
explicitamente migrado, prefira `provide` com `BlocScopedExtension.addBloc` do
core: Modular cria e fecha a instância e a screen apenas a recebe. Sign-in e o
novo `ExpenseSuggestionsBloc` usam esse padrão. As demais screens mantêm factories estáveis e ownership
local; Session continua global sob AppWidget. Não duplique owners ou binds.
Dependências entre features precisam estar disponíveis fora de seus escopos de
rota. Authentication e Expense usam um módulo sem path por feature, com URLs
completas e binds root-owned. Não fragmente em dependencies/form/list nem monte
features irmãs em `/`, pois o Modular indexa seus binds pelo path. Factories
continuam factories; ownership de página continua independente do módulo.
O teste global de logout e a abertura de cadastro/edição/listagem/Settings na
composição real passaram após essa correção.

Navegação ocorre pelo BuildContext do widget/mixin responsável. Argumentos levam
dados, não funções. Edição devolve a entidade confirmada; ExpensesScreen não
recebe callbacks de voltar, editar ou notificar alterações. Dashboard e Metrics
recarregam ao retornar da listagem, mesmo sem mutação. Cadastro recarrega quando
há resultado confirmado. Callbacks locais de composição visual são permitidos.

## Como Ler As Specs Existentes

A feature Insight foi removida do aplicativo. Specs e changes relacionadas a
insights permanecem somente como histórico e não autorizam restaurar módulo,
endpoint, seção da Dashboard, previews ou testes próprios.

| Documento | Uso atual |
| --- | --- |
| `specs/dashboard-monthly-navigation/` | Regras mensais e retorno da listagem; detalhes antigos de commands são substituídos por Bloc/contratos de aplicação. |
| `specs/expense-category-metrics-cards/` | Apresentação dos cards e navegação por categoria/período; recarga ao retornar sem callback de rota. |
| `specs/expenses-period-query/`, `specs/expenses-removable-filters/` | Comportamento de período/filtros; implementação segue Bloc e HTTP atuais. |
| `specs/shared-error-screen/`, `specs/dart-primary-constructor-conventions/` | Requisitos visuais e de linguagem, subordinados às convenções atuais. |
| `specs/settings-screen-ui/`, `specs/authentication-session-logout/` | Referência de UX; Authentication usa HTTP e Session é independente. Descrições Supabase são históricas. |
| `specs/presentation-command-*`, `specs/expense-reactive-command-consumption/`, `specs/dashboard-reactive-command-coordination/`, `specs/insights-monthly-query/` | Intenções de UX/concorrência e regras de consulta continuam úteis; CommandIt/Either/data sources não são arquitetura atual. |
| `changes/migrate-dashboard-to-bloc/` | Registro de uma migração anterior; resultados, contratos e política de recarga registrados na época não redefinem o checkout atual. |
| `changes/archive/` | Histórico imutável de decisões/resultados daquela etapa; nunca comprova execução atual. |

Ao implementar uma spec antiga, preserve os requisitos de produto compatíveis,
adapte o mecanismo à arquitetura canônica e registre conflitos reais. Não marque
E2E aprovado nem enfraqueça testes para satisfazer uma descrição histórica.

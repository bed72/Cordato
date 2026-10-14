## Why

A apresentação mantém `Either` dentro de CommandIt e, em algumas telas, replica loading, dados e erros já disponíveis nos observáveis da biblioteca. Adaptar as falhas na fronteira dos commands permite usar o canal nativo de erros e simplificar esses consumidores, preservando os contratos de repository e os controles de concorrência próprios da aplicação.

## What Changes

- Criar uma exceção tipada mínima da apresentação, `CommandFailureException`, que transporta a instância original de `ErrorsEntity` sem descartar informações JSON:API.
- **BREAKING** nos contratos internos de apresentação: commands atualmente baseados em `Either<ErrorsEntity, T>?` passam a publicar `T?`; `Right` devolve o valor e `Left` lança `CommandFailureException`. Entradas, registros de DI, nomes, factories e contratos de repository permanecem existentes.
- Adaptar todos os consumidores, testes unitários de commands e fakes/previews afetados na mesma unidade de migração de cada command. Resultados booleanos `false` e o limite histórico nulo continuam valores válidos, com interpretação específica pelo consumidor.
- Definir a política nativa de exceções de CommandIt 9.5.2, com fallback global sem efeitos visuais, falhas esperadas não reportadas como defeitos e handlers locais para feedback contextual. Não adicionar filtros customizados quando o filtro nativo padrão for suficiente.
- Começar a simplificação pela Dashboard: remover observação duplicada de erros, separar reconstrução visual e coordenação e preservar erro persistente, tentativa de recuperação, mês, filas coalescidas e invalidação assíncrona.
- Usar `CommandBuilder.onData`, `onNullData`, `whileRunning` e `onError` conforme o estado observado, sem navegação ou toasts dentro de builders.
- Remover as cópias de loading, entidade e falha da consulta simples de `ExpenseScreen`, preservando identidade de ID, execução pendente e descarte.
- Simplificar somente o loading derivável da listagem; manter páginas acumuladas, filtros, revisões, continuação, rolagem, edição, exclusão e retry da operação correta.
- Corrigir a propriedade de assinaturas em consumidores que recebem commands substituíveis; manter descarte manual de instâncias factory e descarte modular de singletons de feature.
- Atualizar documentação canônica e executar validação unitária e Maestro conforme as regras do projeto, sem novos testes Flutter de UI, módulos ou rotas.

## Capabilities

### New Capabilities

- `presentation-command-errors`: adaptação de Either nos commands, contratos de sucesso, preservação de erros, política nativa de exceções e validação de resultados observáveis.
- `dashboard-reactive-command-coordination`: fontes de verdade da Dashboard, observação mínima, recuperação e atualização após navegação com proteção de concorrência.
- `expense-reactive-command-consumption`: consulta de edição dirigida pelo command, estados de formulário e listagem e preservação de interações financeiras.
- `presentation-command-lifecycle`: propriedade de commands e assinaturas, substituição de dependências, descarte e separação entre builders e efeitos nos demais consumidores.

### Modified Capabilities

- `insights-monthly-query`: explicitar que Either e metadados são preservados no repository, enquanto o command publica a lista de sucesso ou a exceção tipada no canal nativo, sem alterar filtros ou conteúdo dos insights.

## Impact

- Camadas alteradas na implementação futura: apresentação, composição de bootstrap e documentação. `domain`, `application/repositories`, data sources e integração HTTP mantêm seus contratos.
- Contextos afetados: Dashboard, Expense, Insight, Metrics, User, Authentication, Root e os componentes mínimos compartilhados de apresentação em Core.
- As operações de `SessionCommand` e `CallbackCommand` não retornam Either e não serão convertidas artificialmente; seus controles e políticas de lifecycle/erro serão revisados onde pertinente.
- Dependências fixadas para a proposta: CommandIt 9.5.2, listen_it 6.0.0, Flutter Modular 7.1.1 e auto_injector 2.2.0. Não há upgrade, dependência nova, geração de código ou troca de arquitetura.
- A change existente `unify-dashboard-error-screen` continua independente. Seus requisitos de recuperação são preservados; pendências visuais e divergências de cabeçalho não são corrigidas incidentalmente por esta refatoração.
- As referências históricas a Supabase em outras specs não são fonte de integração. Esta proposta segue o código HTTP JSON:API atual e `ARCHITECTURE.md`.
- Esta entrega contém somente planejamento. Implementação, atualização das specs principais e arquivamento dependem de etapas posteriores explicitamente autorizadas.

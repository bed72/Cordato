## Why

A Dashboard concentra coordenação assíncrona, recuperação e verificações defensivas de CommandIt em um mixin de 571 linhas. O objetivo é ter um único proprietário testável do fluxo, usando Bloc e cancelamento real das leituras HTTP, em vez de transferir a mesma complexidade para outro arquivo.

## What Changes

- Introduzir `bloc`, `flutter_bloc`, `bloc_concurrency` e `bloc_test`, com versões compatíveis com o SDK do projeto.
- Migrar somente a Dashboard para `DashboardBloc`, com estado imutável e acesso aos contratos dos repositories; remover CommandIt desse fluxo, inclusive da leitura de usuário e do limite histórico.
- Centralizar coordenação de abertura, mês, refresh, recuperação e retorno de navegação em ciclos identificáveis, com cancelamento e proteção contra conclusões obsoletas.
- Manter a troca de mês bloqueada e substituir os botões de navegação mensal por skeleton durante o carregamento, preservando o rótulo de mês/ano.
- Na primeira falha financeira, cancelar as outras consultas financeiras do ciclo e apresentar a ErrorScreen existente. Retry executa recuperação completa no mês preservado.
- Retorno com alteração financeira confirmada cancela o ciclo financeiro vigente e inicia uma nova leitura imediatamente; retorno sem alteração não recarrega.
- Integrar cancelamento opcional às leituras usadas pela Dashboard por um contrato independente do Dio, adaptado para `CancelToken` na infraestrutura. Cancelamento intencional não é erro de negócio ou falha visual.
- Preservar os commands dos outros consumidores, rotas, contratos de navegação, estados vazios, regras civis e fallbacks auxiliares.

## Capabilities

### New Capabilities

- `dashboard-bloc-lifecycle`: propriedade do estado e do ciclo de vida da Dashboard por Bloc, políticas de concorrência entre eventos, cancelamento e isolamento de resultados.
- `cancellable-http-reads`: cancelamento opcional e isolado de leituras através de repositories, data sources e HTTP, sem dependência de Dio no domínio.

### Modified Capabilities

- `dashboard-reactive-command-coordination`: remover requisitos específicos de CommandIt e da coordenação pelo mixin, substituídos por `dashboard-bloc-lifecycle` e pelas regras mensais atualizadas.
- `dashboard-monthly-navigation`: adaptar skeleton dos controles, cancelamento na primeira falha, recuperação e retorno com alteração para o novo ciclo.

## Impact

- Dashboard: módulo, tela, mixin, seções, cabeçalho, seletor, previews e leitura do primeiro mês do histórico.
- Core HTTP: ponte de cancelamento, requests, cliente, helper de resposta e testes, respeitando alterações locais existentes.
- Leituras de User, Expense, Insight e Metrics: parâmetros opcionais de cancelamento nos contratos, implementações, mocks e fakes. A API HTTP remota não muda.
- Commands compartilhados permanecem disponíveis para User e demais telas; somente recursos exclusivos da Dashboard deixam de existir quando não houver consumidores.
- Testes unitários de Bloc e das camadas afetadas; validação visual e de fluxo com Maestro, sem novos testes automatizados de widgets ou de módulos Modular.
- Atualizar `ARCHITECTURE.md`, `AGENTS.md` e o README se necessário para documentar a exceção/piloto Bloc; não migrar outras telas nem introduzir uma BaseBloc genérica.
- A change `introduce-exception-http-insight` e as alterações locais de HTTP devem ser conciliadas durante a implementação, sem reversão ou reintrodução de comportamentos antigos de parsing/erros.

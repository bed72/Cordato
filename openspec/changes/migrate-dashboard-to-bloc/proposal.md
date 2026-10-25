# Estado Documental

Esta proposta registra uma etapa anterior. Consulte
[a referência vigente](../../README.md) para arquitetura, ownership e navegação.
Não restaure Either, commands ou callbacks de rota a partir deste histórico.

## Why

A Dashboard concentra coordenação assíncrona, recuperação e verificações defensivas de CommandIt em um mixin de 571 linhas. O objetivo é ter um único proprietário testável do fluxo usando Bloc, em vez de transferir a mesma complexidade para outro arquivo. Por solicitação explícita durante a implementação, cancelamento HTTP fica para depois; este piloto usa somente invalidação lógica.

## What Changes

- Introduzir `bloc`, `flutter_bloc`, `bloc_concurrency` e `bloc_test`, com versões compatíveis com o SDK do projeto.
- Migrar somente a Dashboard para `DashboardBloc`, com estado imutável e acesso aos contratos dos repositories; remover CommandIt desse fluxo, inclusive da leitura de usuário e do limite histórico.
- Centralizar coordenação de abertura, mês, refresh, recuperação e retorno de navegação em ciclos identificáveis, com proteção contra conclusões obsoletas.
- Manter a troca de mês bloqueada e substituir os botões de navegação mensal por skeleton durante o carregamento, preservando o rótulo de mês/ano.
- Por decisão posterior do usuário, simplificar para loading, conteúdo ou erro: publicar todas as seções juntas após concluir as consultas. Retry é uma nova carga, sem fases especiais, barreiras ou publicação parcial.
- Usar uma sequência única de cinco leituras por carga financeira, inclusive troca mensal: User e limite, depois as três seções. Manter fallbacks auxiliares e proteção contra conclusões antigas.
- Retorno com alteração financeira confirmada invalida o ciclo financeiro vigente e inicia uma nova leitura imediatamente; retorno sem alteração não recarrega.
- Preservar os commands dos outros consumidores, rotas, contratos de navegação, estados vazios, regras civis e fallbacks auxiliares.

## Capabilities

### New Capabilities

- `dashboard-bloc-lifecycle`: propriedade do estado e do ciclo de vida da Dashboard por Bloc, políticas de concorrência entre eventos e isolamento lógico de resultados.

### Modified Capabilities

- `dashboard-reactive-command-coordination`: remover requisitos específicos de CommandIt e da coordenação pelo mixin, substituídos por `dashboard-bloc-lifecycle` e pelas regras mensais atualizadas.
- `dashboard-monthly-navigation`: adaptar skeleton dos controles, publicação atômica, retry como carga normal e retorno com alteração para o novo ciclo.

## Impact

- Dashboard: módulo, tela, mixin, seções, cabeçalho, seletor, previews e leitura do primeiro mês do histórico.
- Core HTTP não é alterado. Expense.get recebe sort opcional nos contratos e implementações para buscar o primeiro mês com uma única request, sem varrer todo o histórico.
- Commands compartilhados permanecem disponíveis para User e demais telas; somente recursos exclusivos da Dashboard deixam de existir quando não houver consumidores.
- Testes unitários de Bloc e das camadas afetadas; validação visual e de fluxo com Maestro, sem novos testes automatizados de widgets ou de módulos Modular.
- Atualizar `ARCHITECTURE.md`, `AGENTS.md` e o README se necessário para documentar a exceção/piloto Bloc; não migrar outras telas nem introduzir uma BaseBloc genérica.
- A change `introduce-exception-http-insight` e as alterações locais de HTTP devem ser conciliadas durante a implementação, sem reversão ou reintrodução de comportamentos antigos de parsing/erros.

# Grupo 5: recuperação coordenada da Dashboard

## Escopo e baseline

Implementação em 14/10/2026, sobre árvore Git limpa, limitada ao grupo 5.
O grupo 4 já havia removido Left da Dashboard: `_failed` usa somente snapshot
terminal com `hasError`. Os três listeners de `results` continuam ligados ao
State durante conteúdo, ErrorScreen e recuperação; nenhum listener adicional de
`errors` foi criado. A ErrorScreen continua sem cabeçalho, conforme o baseline.

## Tentativas válidas

- Metrics, Insights e recentes capturam parâmetros e snapshot anterior, chamam
  `runAsync` e conferem imediatamente o novo snapshot de início. Início exige
  objeto novo, `isRunning` e os parâmetros solicitados.
- Após o await, exigem mounted, versão e command vigentes, terminal distinto do
  início, parâmetros correspondentes, ausência de erro/loading e dados não nulos
  da mesma identidade do retorno do Future. Lista/página vazia e total zero
  continuam sucessos. Não consultam `value` ou `isSuccess`.
- O limite histórico também exige início novo e terminal distinto com o retorno
  esperado. Null concluído continua histórico ausente e aplica a regra civil.
  Falha não altera o mês nem impede as seções financeiras.
- A implementação instalada de CommandIt 9.5.2 publica o início antes do primeiro
  await em `run`, enquanto `runAsync` compartilha o completer ocupado. A prova de
  início distingue execução nova de adesão, inclusive com parâmetros iguais.

## Coordenação e lifecycle

- O ciclo bloqueia reentrada antes do primeiro await; `isRecovering` captura o
  contexto de erro da entrada. User corre em paralelo ao limite na recuperação;
  o limite resolve antes das três seções iniciadas por `Future.wait`.
- O primeiro erro financeiro ativa o latch imediatamente. Sucessos remanescentes
  não o removem. Somente os três sucessos válidos da recuperação liberam conteúdo;
  falhas auxiliares não prolongam o latch. O ciclo termina no finally vigente.
- Pendências financeiras e de User só são consumidas após a microtask revalidar
  disponibilidade, versão, identidade e intenção ainda presente. Se outra leitura
  começar antes, a intenção permanece para o próximo idle. Microtasks adicionais
  não duplicam leituras depois de consumir a intenção.
- Retorno direto ocioso também consome uma intenção já existente ao iniciar a
  leitura nova. Retorno financeiro sem alteração não solicita refresh.
- Qualquer troca de dependências limpa pendências e invalida continuations;
  troca de User remove listener e descarta a factory antiga antes da nova leitura.
  Dispose limpa intenções e remove observações antes de descartar os commands.
- Retorno de User/Settings valida também a versão de dependências. A exclusão
  mútua da listagem é reiniciada na troca, e finally antigo não libera uma
  navegação da versão nova nem modifica State descartado.

As flags existentes continuam necessárias para lente civil, latch persistente,
contexto de recuperação, ciclo com etapas, intenções coalescidas e exclusão mútua
de navegação. Não foram adicionados listeners permanentes, fontes de dados locais
ou gerenciadores. O reforço acrescenta validação de identidade, sem reduzir os
três listeners financeiros e os cinco listeners de execução já mínimos.

## Verificação executada

- `dart format` somente nos dois arquivos Dart alterados.
- `flutter analyze`: sem problemas.
- `flutter test`: **700 testes aprovados**, incluindo quatro cenários novos de
  User/limite reais com falha tipada e inesperada, sem listeners locais de
  `results`/`errors`. O bootstrap real garante conclusão do Future com erro;
  falha tipada não gera reporte, inesperada gera um reporte não fatal com a stack
  do snapshot. Configuração global e recursos são restaurados/descartados.
- As suítes existentes exercitam compartilhamento concorrente, publicação
  terminal, nova execução via microtask, null do limite e descarte pendente.
  Esses testes comprovam contratos de commands, não todo interleaving do State.
- `flutter pub get` não aplicável: dependências/configuração não foram alteradas.
- `openspec validate align-command-it-presentation-errors --strict`: válido.
- `git diff --check`: sem problemas de whitespace.

## Matriz Dashboard e pendência 5.9

`maestro_list_devices` retornou apenas simuladores iOS e Chromium com
`connected: false`. Nenhum flow, consulta HTTP ou resultado visual desta etapa
foi observado pelo Maestro. É necessário iniciar um dispositivo com o app
atualizado para executar a matriz. Não há recurso controlado de falhas/atrasos
mantido no app; cenários artificiais exigem ambiente apropriado ou autorização
para harness temporário. A validação de mudanças de dependências nesta entrega
é inspeção estática, sem reprodução runtime.

| Cenário | Evidência desta etapa | Validação visual/runtime |
| --- | --- | --- |
| D01 abertura/mês, seis recentes e setas | Composição e parâmetros inspecionados | Pendente |
| D02 erro imediato e persistente | Listeners de results e latch inspecionados | Pendente |
| D03 retry falho/bem-sucedido, sem toque extra | Guard pré-await e três provas de sucesso inspecionados | Pendente |
| D04 falhas auxiliares independentes | Quatro testes de fallback reais; coordenação inspecionada | Pendente na tela |
| D05 limite null/ajuste civil | Testes existentes do command; aceitação e ajuste inspecionados | Pendente na recuperação |
| D06 retorno financeiro com/sem alteração | Callback e versão inspecionados | Pendente |
| D07 retorno ocupado/intenção coalescida | Revalidação das microtasks e idle inspecionados | Pendente runtime |
| D08 troca/descarte durante retry | Guards de versão/identidade/mounted e finally inspecionados | Pendente runtime |

Tarefas 5.1–5.8 encerradas pela implementação/revisão e checks automatizados.
Tarefa 5.9 permanece aberta; esta entrega não afirma execução da matriz visual.

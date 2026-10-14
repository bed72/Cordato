# Grupo 7: mutações de Expense

## Implementação

- CreateExpenseCommand e UpdateExpenseCommand publicam ExpenseEntity anulável.
  Right mantém a entidade original; Left lança CommandFailureException com a
  mesma ErrorsEntity. Entradas e contratos dos repositories não mudaram.
- Os builders do formulário usam os tipos nativos. Seus listeners interpretam
  results terminal, priorizando erro antes de dados; não usam value antigo.
  Falhas tipadas preservam pointers e mensagens. Lista vazia recebe fallback
  localizado, assim como erro inesperado. Efeitos continuam fora do build.
- DeleteExpenseCommand publica bool anulável, preservando false. A confirmação
  exige true no Future e no snapshot terminal sem erro do ID vigente. O catch
  tipado preserva mensagens; o catch inesperado aplica fallback, sem feedback
  duplicado por listener de exclusão.
- Controllers, validação, pickers, hold, callbacks, factories e descarte mantêm
  seus proprietários. Gesto, thresholds, pendingDeleteId, filtros, continuação,
  ordenação, remoção e verificação de necessidade de mais itens foram preservados.
- Previews continuam usando commands reais com repositories Either e um único
  proprietário de descarte; não precisaram de mudanças adicionais.

## Checks

`flutter analyze`: sem problemas. `flutter test`: 711 testes aprovados.
Sem alterações de dependências; pub get não foi necessário.
Os testes das três mutações verificam dados nativos, identidade da falha nos
observáveis/Future, metadados, retry, false, parâmetros parciais, isolamento,
sucesso anterior seguido de lista de erros vazia e descarte pendente.

## Maestro controlado

Com autorização do usuário, um launcher temporário usou ExpenseScreen,
ExpensesScreen, commands, validators, tema e toasts reais com repository em
memória, sem mutações na conta. Contadores observaram chamadas de repository,
sinais de alteração e callbacks de navegação, não requisições HTTP.

Dispositivo: iPhone Air iOS 26.2. O MCP passou a falhar com “Device became
unreachable during deviceInfo”; a CLI Maestro funcionou no mesmo dispositivo.

Cenários aprovados por assertions e/ou inspeção da hierarquia:

- Hold bem-sucedido: uma criação, um sinal, nenhum callback de navegação;
  descrição e valor limpos. Hold de 900 ms: nenhuma criação adicional.
- Falha de criação com pointers: três mensagens remotas nos respectivos campos,
  descrição/valor/data preservados e nenhum sinal de sucesso.
- Falhas de criação com lista vazia e exceção inesperada: modo controlado
  explicitamente confirmado, entrada preservada e nenhum sinal/navegação.
- Cancelar os pickers de data e valor preservou descrição, R$ 3,00 e 14/10/2026.
- Toque simples após falha: um sinal e um callback de navegação. O callback do
  harness conta a intenção; não demonstra o router Modular real.
- Edição sem mudanças: Atualizar desabilitado. Edição só da descrição enviou
  `patch A null Despesa editada null` e atualizou o item com um sinal.
- Edição só da data enviou `patch A null null date`; listagem mostrou 13 de Out
  preservando descrição e R$ 12,34.
- Falha de atualização com pointers preservou entrada e três mensagens de campo.
- Cancelar exclusão não chamou delete. Falhas preservaram item e contador de
  alterações; exclusão confirmada removeu item e seu cabeçalho Hoje com um sinal.
- Lista vazia e exceção inesperada na exclusão foram exercitadas com modo
  explicitamente confirmado; não removeram o item.

Limites e tentativas intermediárias:

- Houve falhas de assertions durante exploração por coordenadas/semântica após
  teclado, dupla abertura/fechamento de rota e seleção de cenário coberta por
  toast. Cenários centrais foram repetidos com estado confirmado; tentativas
  ambíguas não comprovam o modo solicitado.
- Assertions do título do toast de exclusão não passaram na janela de observação;
  não há comprovação automatizada da duração ou contagem visual dos toasts.
  O feedback único e fallback foram verificados pelo código, não por essas
  assertions. A matriz não prova todos os interleavings, paginação/rolagem extensa
  ou edição para fora dos filtros.
- O usuário interrompeu a validação por duração excessiva. A tarefa 7.7 permanece
  aberta para revisão das evidências e eventual complemento somente quando
  solicitado. Não se afirma cobertura completa.

Posteriormente, o usuário autorizou explicitamente marcar 7.7 como completa.
A tarefa foi encerrada por esse aceite, com as evidências e limitações acima,
sem nova execução Maestro ou cobertura adicional demonstrada. O grupo 7 está
concluído.

Os arquivos temporários Dart/YAML foram removidos. O launcher normal é
restaurado ao finalizar. Nenhum hook ou menu controlado permanece no código.

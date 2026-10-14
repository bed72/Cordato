# Grupo 6: consulta simples de ExpenseScreen

## Implementação

`GetExpenseCommand` publica `ExpenseEntity?`, inicialmente null. Delega o ID sem
normalização, devolve a entidade original do Right e lança
`CommandFailureException` com a ErrorsEntity original do Left. Exceções
inesperadas permanecem originais nos observáveis e no Future.

`ExpenseScreen` usa `CommandBuilder<String, ExpenseEntity?>` com `onData`,
`onError`, `whileRunning` e `onNullData`. Dados e falhas só compõem conteúdo
quando o parâmetro do snapshot corresponde ao ID vigente. Outro ID conserva
skeleton, sem preencher formulário ou mostrar erro obsoleto. Criação não monta
o builder de consulta e não inicia GET.

O mixin deixa de manter `expense`, `loadErrors` e `isLoading`, e remove todos os
quatro `setState` da consulta. Mantém somente `_loadPending` e `_queryRevision`
para intenção e validade. Inicia por `run`, deixando resultado/erro na fonte
observável; não aguarda nem interpreta Future compartilhado ou `value` antigo.
Um listener de `isRunning` solicita em microtask o ID final pendente, depois de
validar mounted, revisão e command. A microtask revalida disponibilidade antes
de consumir a intenção. Retry ocupado não enfileira consulta. Retirar o ID
limpa a intenção; trocar command ou descartar remove o listener e invalida
microtasks antigas. Get/Create/Update continuam factories pertencentes à screen;
o formulário só remove suas assinaturas e recursos.

Falha tipada mostra os detalhes/títulos remotos em ordem, com fallback localizado
seguro para lista vazia. Falha inesperada mantém a mensagem genérica anterior
“Não foi possível processar a resposta.”. Nenhum toast foi adicionado à consulta.

## Testes e checks

- Os onze testes de GetExpense cobrem null inicial, ID intacto, identidade da
  entidade, metadados e ordem da falha, erro inesperado original em Future/results/
  errors, retry, consulta concorrente compartilhada sem consulta de outro ID,
  snapshot novo de início/término, instâncias isoladas e descarte pendente.
- Descarte após sucesso anterior comprova a particularidade da 9.5.2: o Future
  pode terminar com `value` antigo, mas o snapshot da consulta pendente não publica
  entidade terminal. A screen não utiliza esse Future para aplicar resultados.
- `flutter analyze`: sem problemas. `flutter test`: **704 testes aprovados** na
  execução final. Sem alterações de dependências; `flutter pub get` não aplicável.
- Uma execução direcionada intermediária encontrou duas assertions consultando
  `value` antes de iniciar a operação. A ordem foi corrigida com await explícito
  em variável antes das verificações; a suíte completa final passou.
- `flutter run -d B3BC6DCE-E28C-412D-A10E-147BE3A845C2 --no-resident` compilou e
  executou `lib/main.dart` atualizado no iPhone Air iOS 26.2.
- `openspec validate align-command-it-presentation-errors --strict`: válido.
- `git diff --check`: sem problemas de whitespace.

## Maestro executado

Dispositivo: iPhone Air iOS 26.2, bundle `com.bed.cordato`.

O Maestro abriu a listagem mensal a partir de “Ver tudo”, abriu duas despesas
por arraste da esquerda para a direita e validou os campos retornados:

| Despesa | Descrição | Valor | Data | Ação sem alterações |
| --- | --- | --- | --- | --- |
| Primeira | Mercado | R$ 74,45 | 14/10/2026 | Atualizar desabilitado |
| Segunda | Petshop | R$ 124,00 | 13/10/2026 | Atualizar desabilitado |

Na segunda abertura, confirmou também ausência da descrição da primeira.
Cancelar ambas retornou à listagem. Nenhuma mutação financeira foi executada.
Os valores foram obtidos da hierarquia e usados nas assertions Maestro.

Tentativas intermediárias: YAML sem config foi rejeitado; recebeu `appId` e
`launchApp`. A primeira tentativa de “Ver tudo” abriu cadastro devido à
sobreposição com o FAB no posicionamento inicial. Após voltar e rolar a
Dashboard, a abertura da listagem passou. Esse incidente de exploração não
alterou a composição visual desta change.

## Previews e validação técnica

O inventário não contém preview de `ExpenseScreen` ou consumidor de
`GetExpenseCommand` no catálogo. Os previews existentes de formulário recebem
Create/Update e entidade diretamente, incluindo skeleton; seus contratos não
mudaram. As instâncias pertencem ao wrapper nesse preview, enquanto o formulário
somente observa. Os fakes continuam devolvendo Either nos repositories.

Inspeção estática dos casos não expostos pela rota normal, que cria uma screen
com chave por ID:

- A → B → C com o mesmo command ocupado: mudanças incrementam a revisão e
  mantêm uma intenção; terminal de A não passa a comparação de parâmetro com C.
  O idle agenda somente C com a revisão vigente; microtasks antigas não executam.
- Retirada do ID durante A: a intenção vira false, criação continua sem GET e
  a conclusão não monta edição.
- Command substituído durante consulta: listener antigo removido, factory antiga
  descartada, nova leitura solicitada; microtasks antigas falham em identidade e
  revisão. Dispose impede execução posterior por mounted/revisão.
- Retry ocupado: handler retorna antes de alterar a intenção. Lista de erros
  vazia e falha inesperada têm fallback seguro pelo método de apresentação.

Essas evidências não representam reprodução runtime de A/B/C na mesma screen.
As duas aberturas Maestro são navegações reais com instâncias distintas.

## Pendência inicial 6.6

O sucesso/cancelamento foi validado pelo Maestro. Loading acessível prolongado,
falha esperada/inesperada e retry sem requisições extras não foram reproduzidos
na tela, pois o ambiente atual respondeu com sucesso e não expõe cenários
controlados. O skeleton conserva seu anúncio “Carregando despesa” por inspeção,
mas não foi capturado durante as consultas rápidas.

Não há contagem HTTP desta execução nem harness temporário autorizado. A tarefa
6.6 permanece parcialmente pendente para esses cenários; os testes de command
e a inspeção de UI não são apresentados como substitutos da matriz completa.

## Validação controlada autorizada e conclusão da 6.6

Após autorização explícita do usuário, foi criado um launcher temporário em
`tool/expense_validation.dart`, usando a ExpenseScreen de produção, os commands
reais, tema/localização/toast do wrapper compartilhado e repository controlado.
Cada consulta por ID aguardava um Completer liberado pelo harness; um contador
observável mostrava versão do repository e IDs efetivamente solicitados. Não
houve alteração dos repositories de produção, HTTP, storage ou dados financeiros.

O launcher foi compilado e executado no mesmo iPhone Air iOS 26.2. Os nove
cenários abaixo passaram nas assertions e inspeções do Maestro:

| Cenário | Evidência runtime | Consultas finais |
| --- | --- | --- |
| Sucesso/loading | Anúncio “Carregando despesa”; placeholders e retry ausentes da semântica; três chamadas de retry ocupado não enfileiram leitura; liberação preenche entidade e Atualizar permanece desabilitado | `v1:A` |
| Erro tipado | Título de falha e “Primeiro detalhe remoto\nSegundo detalhe remoto” preservados na ordem; retry volta ao skeleton; quatro chamadas ocupadas não duplicam; segunda conclusão recupera formulário | `v1:A, v1:A` |
| Erro vazio | Lista vazia apresenta “Tente novamente para carregar os dados.” sem falha secundária; retry recupera formulário | `v1:A, v1:A` |
| Erro inesperado | Apresenta “Não foi possível processar a resposta.” sem expor mensagem técnica; retry e três chamadas ocupadas mantêm uma única leitura nova; recuperação válida | `v1:A, v1:A` |
| IDs A → B → C | Mesma GlobalKey e State; B/C chegam durante A pendente; sucesso de A mantém skeleton e somente C é consultado; formulário final mostra Despesa C, R$ 34,56 e 09/10/2026 | `v1:A, v1:C` |
| Erro antigo A → B → C | Falha tipada de A não mostra erro da despesa vigente; skeleton aguarda C; C recupera formulário sem consulta de B | `v1:A, v1:C` |
| Retirada do ID | A pendente vira criação na mesma instância; sucesso tardio não preenche descrição nem retorna à edição; criação permanece sem GET adicional | `v1:A` |
| Troca de command | Mesmo ID e State recebem factory nova; conclusão antiga não tira skeleton; conclusão da nova preenche formulário | `v1:A, v2:A` |
| Descarte pendente | ExpenseScreen removida antes da conclusão; liberar sucesso antigo não remonta conteúdo ou inicia consulta; permanece “Tela descartada” | `v1:A` |

As chamadas de retry ocupado exercitaram o handler real do State pelo harness;
o retry visível foi acionado pelo botão real “Tentar novamente”. Os contadores
medem chamadas ao contrato de repository, não tráfego HTTP. A validação usa dados
controlados; a integração normal com duas despesas reais já foi registrada acima.
Não há promessa de cobertura de todos os interleavings ou lifecycle de outras
telas. Esta rodada comprova runtime dos casos que antes tinham somente inspeção.

O arquivo temporário foi removido após a matriz. Nenhum menu, hook, fake de
simulação ou flow foi adicionado permanentemente à aplicação. A tarefa 6.6 foi
concluída, encerrando o grupo 6; as evidências anteriores ficam como histórico.

Após a remoção, `flutter analyze` voltou a passar sem problemas. O launcher
normal `lib/main.dart` foi recompilado e executado no simulador; inspeção e
assertions Maestro confirmaram Dashboard normal, mês “Outubro 2026”, FAB
“Adicionar gasto” e ausência de “Menu de cenários”, “Sucesso” e “Liberar”.
A suíte de 704 testes já aprovada continua a verificação unitária desta mudança;
o harness não exigiu alteração adicional do código de produção ou dos testes.

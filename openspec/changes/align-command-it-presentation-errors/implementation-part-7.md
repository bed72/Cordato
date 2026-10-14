# Grupo 8 — Loading derivado da listagem

## Implementação

- `ExpensesScreenStateMixin.isLoading` passa de campo mutável a getter da
  execução de GetExpenses ou da recarga pendente da revisão vigente.
- A request não possui outra flag local de loading. A intenção pendente continua
  legítima: cobre a espera por uma consulta da lente anterior e a microtask
  entre a liberação do command e a primeira página da lente final.
- `ExpensesScreen` observa `isRunning` declarativamente por `ListenableBuilder`,
  mantendo `CommandBuilder` para resultados e roteamento contextual dos erros.
- Um listener de execução coordena a intenção pendente. A microtask revalida
  mounted, command, revisão, intenção e disponibilidade antes de removê-la e
  iniciar leitura nova. Se outra execução ocupar o command antes dela, a intenção
  permanece até a próxima liberação. Intenções repetidas da mesma revisão não
  produzem requests adicionais.
- Abertura usa o mesmo reinício de lente, inclusive se receber command ocupado.
  Troca de command remove o listener da instância anterior antes do descarte;
  descarte invalida revisão e pendência antes de liberar recursos.
- Cada operação captura parâmetros e snapshots anteriores/de início. Somente
  início novo e terminal distinto, com os parâmetros solicitados, dados idênticos
  ao Future, ausência de erro e command/revisão vigentes incorporam a página.
- O `finally` da consulta foi removido: nenhuma conclusão antiga modifica loading
  ou dispara recarga. A pendência pertence ao listener da instância vigente.

## Estado e efeitos preservados

`expenses`, `hasLoaded`, `hasFailure`, `nextPageLink`, `_retryRefresh`,
`_queryRevision`, `_pendingRefreshRevision`, filtros, controller e coordenação
de edição/exclusão permanecem nos proprietários atuais.

Refresh falho preserva itens e continuação e repete a primeira página. Paginação
falha preserva itens/continuação e repete a página seguinte. Reinício de lente
limpa lista, continuação e feedback, preserva os filtros novos e controller,
retorna ao topo e aguarda disponibilidade quando necessário. Resultados e erros
de revisões antigas não são aplicados. A incorporação permanece no await de cada
operação válida, sem outro listener incorporando os mesmos itens.

Foram inspecionados os oito placeholders sem itens, três no rodapé com itens,
anúncio “Carregando despesas”, exclusão semântica de textos fictícios, bloqueios
de filtros/gestos e agrupamentos lazy. Loading tem precedência sobre feedback e
vazio. A pendência mantém skeleton entre lente anterior e consulta nova; a
aplicação da página ocorre na continuation do Future antes do próximo frame.
`hasLoaded` só passa a true após página válida. Essa verificação é técnica;
ausência de flash não foi novamente observada em dispositivo nesta etapa.

Redução concreta: um campo de loading e quatro atribuições de sincronização
foram removidos, incluindo os dois `setState` de finalização. O listener novo
coordena a intenção, sem copiar loading, dados ou erro para o State.

## Verificação e limites

- `flutter analyze`: sem problemas.
- `flutter test`: 711 testes aprovados, incluindo a suíte existente de
  GetExpenses com concorrência, publicação terminal antes de idle, microtask,
  falha após sucesso, descarte pendente e filtros preservados.
- `openspec validate align-command-it-presentation-errors --strict`: change válida.
- `git diff --check`: sem problemas.
- Não houve alteração de dependências; `flutter pub get` não foi necessário.
- Não foram criados testes Flutter de UI, mixins ou rotas.
- O simulador iOS listado pelo Maestro não respondeu à inspeção. A hierarquia
  Android mostrou a Dashboard da instalação existente; isso não valida o código
  desta etapa.
- O usuário recusou criar outro launcher temporário. Nenhum launcher foi criado,
  nenhuma despesa foi alterada e a matriz Maestro 8.6 não foi repetida.
  Posteriormente, autorizou marcar o step 8 como concluído e avançar ao step 9;
  8.6 foi encerrada por esse aceite, sem ampliar a cobertura demonstrada.
- Cenários de troca artificial de command/lente, ocupação antes da microtask,
  refresh/paginação falhos, edição para fora da lente e exclusão do último item
  foram inspecionados no código. Os testes de commands não são apresentados como
  cobertura runtime dessas interações do State.

`ARCHITECTURE.md` e `AGENTS.md` descrevem o loading e a coordenação vigentes.
As alterações preexistentes de tema, botões, métricas e documentação foram
preservadas. Steps 9–12 e a outra change ativa não foram implementados.

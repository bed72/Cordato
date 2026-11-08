## ADDED Requirements

### Requirement: Confirmação de recadastro na listagem

A listagem SHALL oferecer recadastro por long press no item e ação semântica equivalente, preservando os gestos existentes de edição e exclusão. Toque simples no item não SHALL abrir edição. A bottom-sheet SHALL seguir os componentes e tema existentes, com título “Recadastrar”, descrição “Recadastre essa despesa com a data atual.” e botão “Voltar” acima de “Cadastrar”.

#### Scenario: Abrir confirmação
- **WHEN** o usuário mantém uma despesa pressionada ou aciona “Recadastrar despesa” pela acessibilidade
- **THEN** a confirmação é aberta para essa despesa sem abrir formulário nem enviar criação

#### Scenario: Cancelar antes do envio
- **WHEN** o usuário toca “Voltar” antes de confirmar
- **THEN** a bottom-sheet fecha sem escrita ou alteração da lista

### Requirement: Nova despesa com data civil de hoje

Ao confirmar, o sistema SHALL criar diretamente um registro novo com a descrição, valor em centavos inteiros e categoria da despesa selecionada, sem normalização adicional. SHALL usar o dia local no momento da confirmação representado como meia-noite UTC sem conversão de fuso, preservar o original e obter o proprietário pelo fluxo autenticado existente.

#### Scenario: Recadastrar com sucesso
- **WHEN** o usuário confirma uma despesa histórica
- **THEN** uma única chamada de criação recebe seus centavos, descrição e categoria e a data civil de hoje, sem reutilizar ID ou atualizar o registro original

#### Scenario: Despesa já é de hoje
- **WHEN** o usuário confirma uma despesa cuja data já é hoje
- **THEN** o sistema permite criar outro registro, mesmo que os demais campos sejam iguais

#### Scenario: Virada de dia durante a confirmação
- **WHEN** a bottom-sheet abre antes da meia-noite local e o usuário confirma após a virada
- **THEN** a criação usa o novo dia local, não o dia da abertura

### Requirement: Bloqueio durante gravação

O sistema SHALL manter a bottom-sheet aberta com loading durante o POST, desabilitar “Voltar” e “Cadastrar” e bloquear fechamento por gesto, toque externo ou back. SHALL descartar submissões adicionais durante a gravação e impedir que outras operações da listagem concorram de modo a sobrescrever seu resultado. Não SHALL executar retry automático de criação.

#### Scenario: Submissões repetidas
- **WHEN** chegam novas confirmações enquanto uma criação está pendente
- **THEN** apenas a primeira criação é executada e os botões permanecem indisponíveis

#### Scenario: Tentativa de fechar durante envio
- **WHEN** o usuário tenta voltar, arrastar ou tocar fora enquanto a gravação está pendente
- **THEN** a bottom-sheet permanece aberta até a conclusão da operação

### Requirement: Fechamento e feedback após conclusão

Após sucesso ou falha da criação, o sistema SHALL fechar a bottom-sheet e mostrar uma única notificação com título curto e descrição. No sucesso SHALL usar “Despesa cadastrada” e “Uma nova despesa foi registrada com a data de hoje.” Na falha SHALL usar título “Não foi possível cadastrar” e descrição local segura, sem mensagens remotas diretamente; fallback “Tente novamente em instantes.”

#### Scenario: Sucesso confirmado
- **WHEN** o repository confirma a criação
- **THEN** a bottom-sheet fecha e o toast de sucesso aparece uma única vez

#### Scenario: Falha de criação
- **WHEN** a criação falha por erro esperado ou inesperado
- **THEN** a bottom-sheet fecha, a lista anterior é preservada e um toast de falha é exibido, sem retry automático

#### Scenario: Nova tentativa manual
- **WHEN** após uma falha o usuário abre novamente a confirmação e toca “Cadastrar”
- **THEN** uma nova tentativa pode ser executada

### Requirement: Atualização preserva filtros e paginação consistente

Após criação confirmada, o sistema SHALL recarregar a primeira página com os filtros ativos preservados. Não SHALL inserir item fora do filtro ou interpretar falha dessa recarga como falha da criação. Respostas de consultas anteriores não SHALL sobrescrever dados mais recentes da listagem.

#### Scenario: Hoje corresponde ao filtro
- **WHEN** a criação é confirmada e a recarga filtrada tem sucesso
- **THEN** a lista apresenta a primeira página atualizada com ordenação e próxima página da consulta nativa

#### Scenario: Hoje está fora do intervalo selecionado
- **WHEN** a criação é confirmada com filtro que exclui hoje
- **THEN** o filtro permanece, a nova despesa não aparece na consulta e o toast de sucesso ainda é mostrado

#### Scenario: Recarga falha após criação
- **WHEN** o POST tem sucesso mas o GET subsequente falha
- **THEN** a criação continua confirmada, o erro pertence à consulta e nenhuma nova criação é enviada automaticamente

### Requirement: Operação isolada em Expense com lifecycle seguro

A apresentação SHALL usar `ExpensesBloc` e `IExpenseRepository.create`, sem chamar o Bloc do formulário, importar repositories concretos/SDK ou depender de Root/Metrics. SHALL preservar a sinalização existente de mutação no repository e o ownership atual do Bloc. Falhas esperadas SHALL preservar `ErrorsEntity`; inesperadas SHALL usar fallback e `addError`.

#### Scenario: Identidade autenticada ausente
- **WHEN** o repository lança a exceção compartilhada de identidade ausente
- **THEN** o Bloc preserva seus erros como falha esperada, sem telemetry de erro inesperado ou gestão própria da sessão

#### Scenario: Tela encerrada durante criação
- **WHEN** a criação conclui depois do fechamento do Bloc ou descarte da tela
- **THEN** não há emissão inválida, navegação ou toast em contexto descartado, sem presumir cancelamento remoto

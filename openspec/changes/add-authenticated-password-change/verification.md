# Verificação Da Implementação

## Estado Atual — Reversão Dos Ajustes De Teclado E Rolagem

Por solicitação explícita, foram desfeitas somente as alterações adicionais de
abertura de teclado, cabeçalho, centralização e rolagem. Os arquivos preexistentes
de login, cadastro, recuperação/reenvio, reset, edição do nome, Expense e seu
piloto de header retornaram ao conteúdo anterior, após conferência de que as
mudanças nesses arquivos eram exclusivamente desta ampliação. Os novos layouts,
medição de conteúdo, cálculos de geometria, previews e testes específicos desses
ajustes foram removidos, junto da capacidade OpenSpec `keyboard-form-headers`.

A troca de senha continua implementada com app bar, header comum e formulário
de rolagem simples. Permanecem a política 6–16, validações, proteção dos logs,
logout coordenado com Session, subtítulo sobre novo login e toast de sucesso
dividido em título/descrição. As ações Próximo/Enviar dos campos foram preservadas,
pois não alteram abertura de teclado nem composição/rolagem das telas.

Verificação após a reversão:

- `flutter pub get`: concluído, sem alteração de dependências.
- `flutter analyze`: sem problemas.
- `flutter test test/architecture test/features/core test/features/authentication test/features/user test/features/expense/presentation/screens/expense test/features/expense/expense_module_test.dart test/app_module_test.dart --reporter failures-only`: **634 aprovados**.
- `flutter test --reporter failures-only`: **1277 aprovados e as mesmas cinco falhas preexistentes** de descrições de categorias de Expense.
- `openspec validate add-authenticated-password-change --strict` e `git diff --check`: sem problemas.

Os relatos e resultados da ampliação abaixo são somente histórico de trabalho
desfeito, não requisitos nem garantias do código atual. A revisão manual da troca
de senha continua pendente; não houve commit, push ou deploy.

## Resultado

Fluxo de alteração de senha implementado no cliente, sem alteração de backend,
schema, dados, dependências ou deploy. Nenhum teste de UI foi criado.

Authentication possui operação, rota, Bloc, apresentação e validações. User
somente abre a rota autenticada. A política 6–16 com classes ASCII é compartilhada
com cadastro, sign-in e recuperação. Nova igual à atual bloqueia envio; confirmação
divergente tem erro próprio. Logout falho após alteração confirmada permite somente
repetir limpeza local. Senhas ficam fora dos estados e dos logs HTTP.

## Comandos Executados

### Histórico — Ampliação De Formulários Desfeita

Exceção posterior solicitada: somente a etapa inicial “Recupere sua conta” usa
`collapsibleHeader: false`. O título/descrição e campo permanecem centralizados
com scroll simples quando necessário, voltar no topo e Enviar embaixo. A etapa
de reenvio e os demais formulários não mudam. Verificação: `flutter analyze` sem
problemas, `flutter test test/features/authentication test/features/core
test/architecture --reporter failures-only` com **467 aprovados**, OpenSpec
estrito e `git diff --check` sem problemas. Sem nova inspeção visual em dispositivo.

Correção de centralização após relato visual: as páginas de Authentication e
edição do nome voltaram a centralizar título/descrição/campos em um único bloco,
mantendo voltar no topo e ações/rodapés embaixo. A altura natural é medida após
layout e informa o padding do header expandido, sem altura fixa do formulário ou
controller. Expense permanece ao topo como no original. Os oito novos testes
puros verificam centralização exata com um, dois e três campos em dois viewports,
overflow e alteração de altura por mensagens/texto. Os previews incluem um campo
e fonte ampliada sem teclado, além dos cenários já existentes.

Última execução após essa correção: `flutter pub get` concluído, `flutter analyze`
sem problemas, o mesmo lote focado abaixo com **665 aprovados** e suíte completa
com **1308 aprovados e as mesmas cinco falhas preexistentes** de Expense. Catálogo
de previews compilou/serviu, encerrando por timeout de 60 segundos sem cliente
conectado. OpenSpec estrito e `git diff --check` passaram. Não houve validação
visual em dispositivo; a tarefa 4.9 permanece aberta. A primeira análise encontrou
uso de tipo privado na assinatura pública de um override de render, corrigido
antes da última execução.

Por solicitação explícita após o relato de título cortado no sign-in, o layout
foi centralizado no core: `KeyboardFormWidget` captura o inset antes de criar o
Scaffold; `KeyboardFormScrollWidget` recebe o valor e aplica slivers/altura mínima;
`KeyboardFormLayout` contém o cálculo puro antes local à troca de senha.

Adotado em login, cadastro, recuperação (solicitação e reenvio), reenvio da
verificação, redefinição/troca de senha, edição do nome e Novo/Editar gasto. Expense
mantém a composição e só reutiliza a rolagem; o inset é encaminhado pela screen e
pelos previews. Botões, rodapés, validações, operações, callbacks legados e ownership
dos Blocs foram preservados. A calculadora com campo somente leitura fica fora
da adoção de header de página.

- `flutter pub get`: concluído, sem atualização de dependências.
- `flutter analyze`: sem problemas na última execução; três sugestões de ordenação de `child` encontradas inicialmente foram corrigidas.
- `flutter test test/architecture test/features/core test/features/authentication test/features/user test/features/expense/presentation/screens/expense test/features/expense/expense_module_test.dart test/app_module_test.dart --reporter failures-only`: **657 aprovados**.
- `flutter test --reporter failures-only`: **1300 aprovados e as mesmas 5 falhas preexistentes** de descrições de categorias em Expense, detalhadas abaixo.
- `dart run tool/widget_preview.dart`: catálogo compilado/servido com novos previews de título longo, um campo, teclado simulado e texto ampliado; encerrado por timeout de 60 segundos, sem cliente conectado.
- `openspec validate add-authenticated-password-change --strict` e `git diff --check`: sem problemas.

Os testes arquiteturais verificam a captura pré-Scaffold, a passagem explícita do
inset, a adoção nas páginas e a pureza do cálculo. Não montam UI nem comprovam o
resultado visual. A reconferência em dispositivo, inclusive navegação de foco e
fontes ampliadas, continua pendente na tarefa 4.9. Não houve deploy, commit ou push.

### Execuções Anteriores À Ampliação

- `flutter pub get`: concluído, sem atualização de dependências do projeto.
- `dart format $(git diff --name-only -- '*.dart') $(git ls-files --others --exclude-standard -- '*.dart')`: arquivos Dart alterados formatados.
- `flutter analyze`: última execução sem problemas.
- `flutter test test/features/authentication test/features/user test/features/core test/features/session test/features/root test/architecture test/app_module_test.dart --reporter failures-only`: **649 aprovados** na última execução.
- `flutter test --reporter failures-only`: **1277 aprovados e 5 falhas** na última execução. As falhas estão em `test/features/expense/presentation/extensions/expense_category_extension_test.dart`, nas descrições de `travel`, `services`, `transport`, `investments` e `subscriptions`, com quatro palavras onde os testes exigem cinco ou seis. Esses arquivos não foram alterados nesta change; a mesma pendência já estava registrada no README antes desta implementação.
- `dart run tool/widget_preview.dart`: catálogo compilado e servido, com as quatro novas funções de preview incluídas no arquivo gerado. Encerrado por timeout de 60 segundos; mensagem final informa recompilação sem cliente conectado. Isso não equivale a inspeção visual nem execução em dispositivo.
- `openspec validate add-authenticated-password-change --strict`: válido.
- `git diff --check`: sem problemas.

Durante o desenvolvimento, o primeiro lote focado identificou uma fixture de
limite com 17 caracteres rotulada como válida; a fixture foi corrigida e os lotes
subsequentes passaram. A análise inicial também apontou duas sugestões de estilo,
corrigidas antes da última execução.

## Cobertura Acrescentada

- Limites de comprimento, classes ASCII, espaços e code points suplementares.
- Reutilização da senha, confirmação exata e obrigatoriedade da senha atual.
- Payload/ID/status do PATCH, erros HTTP e de storage, espera e ausência de gravações/retry/logout no método remoto.
- Estados e delegação do Bloc, erros esperados/inesperados, espera da limpeza, retry exclusivamente local, concorrência e fechamento pendente.
- Mensagens por campo e fallback sem texto remoto.
- Filtros de request/response/error e observador de Bloc sem credenciais.
- Rota protegida, resolução isolada e ownership pelo escopo Modular, sem montar UI.
- Decisão pura da navegação e retenção local do redirecionamento: watch do token antes/depois da limpeza, liberação idempotente e demais logouts preservados.

## Pendência Manual — Tarefa 4.9

Correção posterior à tentativa de altura mínima: o inset estava sendo lido no
contexto do `LayoutBuilder`, dentro do body. A implementação de `Scaffold` em
material_ui 1.9.0 aplica `removeViewInsets(removeBottom: true)` ao body quando
redimensiona pelo teclado. Assim, a entrada do cálculo era sempre zero e a reserva
anterior nunca era ativada. A screen agora lê `viewInsets.bottom` antes do
`Scaffold` e passa esse valor ao cálculo, mantendo o viewport medido no body.
`flutter analyze` passou sem problemas e o lote focado de Authentication/core/
architecture passou com 440 testes. Essa validação estática/unitária não comprova
o gesto em dispositivo; a tarefa manual permanece aberta.

O formulário também passou a reutilizar `CollapsibleHeaderWidget` com slivers
nativos, sem app bar duplicada ou controller de rolagem. O
botão continua fixo. A redução de viewport causada pelo teclado permite rolar e
recolher o título, mantendo o teclado aberto durante o gesto. Ao fechar o teclado,
a extensão de rolagem se ajusta nativamente. Fontes ampliadas e telas baixas também
podem produzir overflow legítimo; não se bloqueia a rolagem por uma flag de teclado.
Foi adicionado um preview de área reduzida (390 × 420) para inspeção manual.

Após novo relato, o formulário curto passou a receber uma altura mínima somente
com o teclado aberto: viewport útil menos `kToolbarHeight`. Sem esse mínimo, a
rolagem podia terminar antes de completar o recolhimento. `LayoutBuilder` lê a
área realmente disponível e `ChangePasswordScrollLayout` faz o cálculo puro,
sem somar novamente o inset do teclado. A reserva desaparece ao fechar o teclado.
Um preview adicional simula inset de teclado para esse cenário. Os cinco novos
testes unitários cobrem ausência de teclado, percurso completo do cabeçalho,
independência da altura do teclado, viewport pequeno e remoção da reserva.

Verificação da correção: `flutter pub get` concluído, `flutter analyze` sem
problemas, lote focado de Authentication/core/architecture com **440 aprovados**,
validação OpenSpec estrita e `git diff --check` sem problemas. O catálogo de
previews compilou/serviu, encerrando por timeout de 60 segundos sem cliente
conectado. Não foi realizada nova verificação visual do gesto no dispositivo;
testes de geometria não substituem essa etapa manual.

Verificação do cabeçalho: `flutter pub get` concluído, `flutter analyze` sem
problemas, `flutter test test/features/authentication test/features/core
test/architecture --reporter failures-only` com **435 aprovados**, validação
OpenSpec estrita e `git diff --check` sem problemas. `dart run
tool/widget_preview.dart` compilou/serviu o catálogo e terminou por timeout de
60 segundos, sem cliente conectado; não comprova validação visual ou teclado real.

Após o relato em dispositivo sobre a ação do teclado, o formulário passou a
possuir FocusNodes próprios descartados pelo mixin. `PasswordFieldWidget` encaminha
o foco e `onEditingComplete` ao campo compartilhado: Próximo vai diretamente de
Senha atual para Nova senha e depois para a confirmação; Enviar na confirmação
chama a mesma submissão do botão. Os demais consumidores mantêm seus defaults.
O subtítulo passou a “Após trocar a senha, você precisará entrar novamente.”

Verificação desse ajuste: `flutter pub get` concluído, `flutter analyze` sem
problemas, `flutter test test/features/authentication test/features/core
test/architecture --reporter failures-only` com **435 aprovados**, validação
OpenSpec estrita e `git diff --check` sem problemas. Não foram criados testes
de UI, e a interação corrigida do teclado ainda precisa de reconferência manual.

Ainda é necessário revisar em dispositivo:

1. Abertura por Dados pessoais, campos ocultos/autofill, teclado e rolagem com texto ampliado.
2. Três senhas iguais, confirmação divergente, senha atual incorreta e preservação da entrada após falhas.
3. Alteração real no PocketBase, limpeza local, chegada ao sign-in com um único toast e impossibilidade de voltar ao formulário concluído.
4. Falha de limpeza após PATCH e retry de logout sem nova alteração remota.
5. Acessibilidade e leitura semântica dos campos e mensagens.

Sem dispositivo/cliente de preview conectado nesta execução, essa tarefa permanece
aberta. A change não foi arquivada e não houve commit ou push.

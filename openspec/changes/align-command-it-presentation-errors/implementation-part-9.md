# Step 10 — Authentication e Settings

## Implementação

- `SignInCommand.execute` publica `SessionEntity?`. SignUp, ResendEmail e Logout
  publicam `bool?`, todos com valor inicial nulo.
- Cada command aguarda o repository e adapta Right para o valor original e Left
  para `CommandFailureException`, conservando a mesma ErrorsEntity. Exceções
  inesperadas continuam originais; entradas são delegadas sem normalização.
- Os quatro consumidores tratam erro no snapshot terminal antes dos dados,
  sem interpretar Either ou usar `value` anterior como confirmação.
- SignIn e SignUp preservam o mapeamento de erros de e-mail/senha nos formulários
  existentes e o toast dos itens restantes. Lista vazia e erro inesperado recebem
  fallback localizado. ResendEmail e Settings também protegem listas vazias.
- Somente `true` no snapshot sem erro navega após cadastro ou reinicia o cooldown
  e anuncia o reenvio. `false` permanece dado válido sem esses efeitos.
- SignIn e Logout mantêm a navegação pela observação da sessão. A confirmação do
  logout e a revogação/limpeza no repository preservam seu fluxo existente.
- Os builders de botões foram adaptados aos novos tipos; seus callbacks continuam
  somente visuais. Settings já inferia o tipo e não precisou alterar seu builder.
- Não foram encontrados previews que instanciem esses quatro commands; o preview
  de convite de Settings não depende do logout. O teste de reenvio foi atualizado
  no caminho histórico existente, conforme 10.3.
- ARCHITECTURE.md e AGENTS.md agora descrevem os contratos nativos de Authentication.
  README não precisou mudar, pois configuração e execução permanecem iguais.

## Estado e propriedade

Controllers, validação e erros de campo continuam no formulário. O cooldown local
de sessenta segundos e seu timer continuam na tela de reenvio. Não houve criação
de flags de request, cópias de resultado ou novas subscriptions na aplicação.
Os quatro listeners existentes continuam pertencendo às telas; nenhum singleton
é descartado manualmente. A revisão de substituição de dependências é o step 11.

## Verificação executada

- `dart format` nos quinze arquivos Dart alterados nesta etapa.
- `flutter analyze`: sem erros ou warnings; um diagnóstico informativo de
  `deprecated_member_use` em `expense_dismissible_widget_state_mixin.dart:27`,
  pelo uso de `TickerMode.of`. Esse arquivo foi alterado em paralelo fora desta
  implementação, e suas alterações foram preservadas.
- `flutter test test/features/authentication/presentation`: **40 testes aprovados**.
  Os quatro commands migrados somam 27 cenários. Cobrem null inicial, sucesso
  nativo no Future/value/results, inputs intactos, falha tipada no Future/results/
  errors, identidade de ErrorsEntity com metadados e múltiplos itens, throwable
  inesperado original, lista vazia após sucesso, retry e false nos três booleanos.
  Logout mantém também o teste de bloqueio de execução concorrente.
- Os testes usam handlers locais reais de results para o roteamento nativo,
  removidos no tearDown antes de descartar cada command; nenhuma configuração
  global é alterada por essas suítes.
- `flutter test`: **734 aprovados e quatro falhas** nos testes de UpdateUser e
  UpdateAvatar, fora dos arquivos alterados nesta etapa.
- Reexecução isolada dos dois arquivos de User: **14 aprovados e as mesmas quatro
  falhas**, sem carregar Authentication. As causas são expectativas antes da
  execução que produziria o valor esperado:
  - `update_user_command_test.dart:151`: espera paramData antes de runAsync.
  - `update_user_command_test.dart:192`: espera limpar hasError antes do retry.
  - `update_avatar_command_test.dart:98`: espera usuário antes de executar retry.
  - `update_avatar_command_test.dart:155`: espera paramData antes de runAsync.
  Esses arquivos e seus commands não foram modificados nesta etapa.
- `openspec validate align-command-it-presentation-errors`: válido.

## Validação de interação pendente — 10.7

Maestro listou o iPhone Air iOS 26.2 como conectado, mas `inspect_screen` retornou
`Device became unreachable during deviceInfo`. Nenhum flow foi executado e não
há evidência runtime de sign-in, cadastro, reenvio ou logout nesta etapa.
Não foi criado launcher ou harness temporário, nem alterado storage ou conta em
dispositivo. A tarefa 10.7 permanece aberta para execução com app atualizado,
dispositivo acessível e credenciais/ambiente de teste disponíveis.

Por inspeção, erros preservam entrada, cadastro false não navega, reenvio false
não reinicia o cooldown nem anuncia sucesso, e logout não força limpeza ou
navegação na UI. Essa inspeção não substitui a matriz Maestro.

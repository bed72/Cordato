# Parte 2 — Fronteira tipada e fallback nativo de erros

## Escopo e entrega

Grupo 3 concluído após o aceite do usuário para a Parte 1. Os contratos de saída
dos commands permanecem vigentes; a adaptação de Right/Left será feita nas
próximas unidades completas de migração.

- `CommandFailureException`, em `core/presentation/commands/`, usa primary constructor const, implementa Exception e armazena a mesma ErrorsEntity, sem helper genérico, IO ou DI.
- `configureCommandExceptionHandler`, em `lib/main.dart`, instala o callback global após resolver ICrashClient e antes de criar AppWidget. A função é parte da composição de bootstrap, sem colocar acesso ao crash client na apresentação de uma feature.
- Falha tipada no fallback encerra o callback sem telemetry ou efeito visual; throwable inesperado é delegado ao crash client como não fatal, com erro e stack recebidos.
- A atribuição não cria subscriptions. Reinstalar o callback substitui a configuração anterior; não acumula handlers. Não envia paramData, credenciais, ID, nome de command ou payload adicional ao reporter.
- `GlobalIfNoLocalErrorFilter`, `reportAllExceptions` e `assertionsAlwaysThrow` mantêm os padrões instalados. FlutterError/PlatformDispatcher conservam seus callbacks anteriores.

## Evidência unitária

Os testes de `command_failure_exception_test.dart` verificam identidade da
ErrorsEntity e sua lista, ordem, metadados completos, strings futuras, campos
nulos e lista vazia. Não há toString que serialize conteúdo da falha.

`command_exception_handler_test.dart` instala a função real de bootstrap e
executa `GetExpensesCommand` com `ExpenseRepositoryMock`:

| Cenário | Resultado observado |
| --- | --- |
| CommandFailureException sem observador local | Future termina com a mesma exceção, results/errors registram a falha e crash client não é chamado |
| StateError sem observador local | Future termina com o mesmo erro; exatamente um recordError com fatal false e a mesma stack publicada em results |
| Falha tipada com listener de results | Um evento terminal local e nenhum reporte global |
| Falha inesperada com listener de results | Um evento terminal local e nenhum reporte global |
| Falha tipada com listener de errors | Um evento local e nenhum reporte global |
| Falha inesperada com listener de errors | Um evento local e nenhum reporte global |
| Reinstalação da configuração | Filtro, flags e callbacks de Flutter/PlatformDispatcher preservados |

Os cenários locais começam com um sucesso anterior e comprovam que a falha
corrente não contém data, apesar de value preservar o resultado antigo. O await
trata o Future em erro e não produz um segundo efeito local. Os listeners são
removidos pelo tearDown e o callback global anterior é restaurado ao fim de cada
teste. Não há teste Flutter de widget, screen, tema, módulo ou rota.

Nesta unidade, o mock lança a exceção para exercitar o roteamento do command real
sem alterar sua saída Either. Isso não substitui os testes de adaptação de Left
previstos para a migração. A preservação da política de AssertionError foi
verificada nas flags e no código instalado: o relançamento precede o filtro;
não se afirma uma execução runtime desse caminho excepcional.

## Documentação

ARCHITECTURE.md e AGENTS.md registram a fronteira aprovada, a coexistência atual
com Either e a política local-first/global fallback. Não há mudança de setup ou
início rápido que exija alteração do README.

## Verificação final

- `flutter analyze`: nenhum problema.
- `flutter test`: 685 testes aprovados, incluindo dez novos casos de transporte e política de erros.
- `openspec validate align-command-it-presentation-errors --strict`: change válida.
- `git diff --check`: sem problemas.
- Nenhuma dependência alterada; `flutter pub get` não foi necessário.
- Grupo 3: sete tarefas concluídas. Progresso total da change: 19/85, incluindo o aceite da Parte 1.
- Próxima unidade: consultas compartilhadas e todos os seus consumidores, grupo 4, seguida da adequação da recuperação no grupo 5.

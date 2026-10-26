# Expense E2E

## Sugestões — execução em 25/10/2026

Os quatro flows em `suggestions/` foram executados e aprovados no simulador
iPhone 17 Pro / iOS 26.5, com build iOS debug apontando exclusivamente para a
fixture loopback. Isso não valida Android, produção, periodicidade ou autorização
do backend real. Os flows CRUD descritos abaixo não foram reexecutados.

```bash
python3 test/support/expense/fakes/expense_http_server.py
flutter build ios --simulator --debug --dart-define=BASE_URL=http://127.0.0.1:8771/api/
xcrun simctl install <simulator-id> build/ios/iphonesimulator/Runner.app
maestro --device <simulator-id> test test/features/expense/presentation/screens/expense/e2e/suggestions
```

- `Success`: usa descrição/valor e confirma no servidor 160000 centavos.
- `DescriptionOnly`: seleciona descrição, abre calculadora e confirma valor manual.
- `Failure`: indisponibilidade de sugestões não impede cadastrar manualmente.
- `Loading`: request retida não bloqueia valor/cadastro nem reaparece após perder foco.

Asserções finais usam saída do formulário e estado da fixture, não toast transitório.
Login aceita submissão pelo teclado no iOS, sem tocar em um botão que já saiu da tela.
A fixture expõe `operations.suggestions`, `queries`, `amounts` e `descriptions` nos
stats, sempre com dados sintéticos e token fictício. Sugestões exigem autenticação.
Os mesmos endpoints de reset/release controlam as respostas e requisições retidas.
O servidor deve ser encerrado após os testes. As chamadas do app usam o client
existente; nenhum domínio ou token de produção é necessário.

O MCP de Maestro falhou com dispositivo inacessível e sua inspeção excedeu o limite
de profundidade. A execução aprovada usou a CLI e inspeção da hierarquia pela CLI.

## Flows CRUD anteriores

Flows preparados, **não executados em dispositivo**. Dashboard e Expense estão
registrados na composição global; isso não comprova DI nem navegação em execução.
Expense usa um único módulo sem path, mantendo validators e factories no injector
raiz. Testes da composição real cobrem criação/edição/listagem/Settings, incluindo
a antiga colisão de binds com Authentication; o teste de DI de logout também passa.
Os seletores devem ser confirmados na primeira execução em app compilável.

`Success`, `Failure` e `Loading` cobrem criação, erro 422 com entrada preservada e
retry manual, e request retida com campo bloqueado. A fixture HTTP é isolada,
escuta somente loopback e usa login/token fictícios, sem chamar produção.

```bash
python3 test/support/expense/fakes/expense_http_server.py
adb reverse tcp:8771 tcp:8771
flutter run --dart-define=BASE_URL=http://127.0.0.1:8771/api/
maestro test test/features/expense/presentation/screens/expense/e2e/Success.yaml
maestro test test/features/expense/presentation/screens/expense/e2e/Failure.yaml
maestro test test/features/expense/presentation/screens/expense/e2e/Loading.yaml
```

Execute sequencialmente, sem sharding, em dispositivo de teste: os flows limpam
dados/keychain. Nunca use uma build apontando para produção. Android precisa de
HTTP debug permitido; simulador iOS usa loopback do host. Loading libera a request
em teardown; a retenção tem limite de 60 segundos. Os endpoints de controle são
`POST /__test/reset`, `POST /__test/release` e `GET /__test/stats`.

O servidor também implementa consulta/edição/exclusão e as leituras da Dashboard.
Testes Flutter cobrem edição, hold contínuo, datas, paginação, parsing, concorrência
e lifecycle; estes flows não substituem essa cobertura nem provam autorização remota.

Criação/edição navegam pelo próprio BuildContext, sem callbacks de rota. Edição
retorna a entidade confirmada. Cadastro contínuo permanece aberto; o retorno
transporta o resultado salvo conforme o estado do formulário.

# Expense E2E

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

# User / Perfil E2E

Flows preparados, **não executados em dispositivo**. Dashboard/Settings/User estão
registrados na composição global; isso não comprova DI nem navegação no app.
Perfil e edição usam Bloc com ownership pelas screens, não pelo escopo Modular.
Não adicione bypasses de sessão ou rotas de teste para contornar falhas reais.

- `Success.yaml`: perfil, avatar após debounce, cancelamento da exclusão e
  exclusão confirmada com redirecionamento global por Session.
- `Failure.yaml`: avatar 422 e exclusão 503, perfil preservado e retry manual.
- `Loading.yaml`: PATCH retido, ações desabilitadas e uma única atualização.

Consulta pendente, falha de consulta, fechamento, troca de factory, storage e
concorrência cruzada também são cobertos nos testes Flutter. Os seletores e o
redirecionamento composto ainda precisam ser verificados no app compilável.

## Execução

Somente dispositivo de teste: os flows limpam dados/keychain. Nunca execute
contra produção. A fixture escuta apenas loopback, não usa serviços externos e
reutiliza a fixture local de login para os demais endpoints da Dashboard.

Com a composição validada e o build de teste instalado, na raiz:

```bash
python3 test/support/user/fakes/user_http_server.py
```

Em outro terminal, para Android:

```bash
adb reverse tcp:8770 tcp:8770
flutter run --dart-define=BASE_URL=http://127.0.0.1:8770/api/
maestro test test/features/user/presentation/screens/user/e2e/Success.yaml
maestro test test/features/user/presentation/screens/user/e2e/Failure.yaml
maestro test test/features/user/presentation/screens/user/e2e/Loading.yaml
```

Execute sequencialmente, sem sharding. iOS simulador usa loopback do host; iOS
físico não é suportado. O build precisa permitir HTTP local. A retenção tem limite
de 60 segundos, com liberação em teardown. YAML presente não prova execução E2E.

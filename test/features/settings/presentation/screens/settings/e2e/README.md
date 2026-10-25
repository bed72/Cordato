# Logout E2E

Flows preparados, **não executados em dispositivo** devido aos bloqueios globais
de compilação/composição (`command_it`, `Either`, `response<T>` e módulo de rotas
de Authentication). Os seletores precisam ser confirmados no build atualizado.

- `Success.yaml`: confirmação cancelada sem request, revogação, navegação por
  observação da sessão e ausência de sessão após reiniciar.
- `Failure.yaml`: erro 503, sessão preservada após reiniciar e retry manual com
  nova confirmação. Não usa 401, que tem política própria no SessionInterceptor.
- `Loading.yaml`: revogação retida, sem navegação antes da liberação e uma request.

## Execução

Somente em dispositivo de teste: os flows apagam dados/keychain. Nunca use API
de produção ou credenciais reais. A fixture aceita login fictício, respostas
mínimas da Dashboard e DELETE de logout. Escuta somente loopback, verifica o
Bearer fictício sem registrá-lo e não chama serviços externos.

Na raiz, em um terminal:

```bash
python3 test/support/authentication/fakes/logout_http_server.py
```

Em Android:

```bash
adb reverse tcp:8769 tcp:8769
flutter run --dart-define=BASE_URL=http://127.0.0.1:8769/api/
maestro test test/features/settings/presentation/screens/settings/e2e/Success.yaml
maestro test test/features/settings/presentation/screens/settings/e2e/Failure.yaml
maestro test test/features/settings/presentation/screens/settings/e2e/Loading.yaml
```

Session, Welcome, Dashboard, Settings e Authentication precisam estar ativos.
Execute sequencialmente, sem sharding. No simulador iOS o loopback aponta para
o host; iOS físico não é suportado. O build deve permitir HTTP local.

Loading é liberado explicitamente e no teardown, antes do timeout de 60 segundos.
Testes Flutter cobrem concorrência, confirmação obsoleta, lifecycle, falhas
inesperadas e espera da limpeza do storage. Maestro não injeta falha no storage
nativo. Os testes isolados de Settings não provam o redirecionamento global;
os flows só poderão validá-lo quando a composição do app estiver compilável.

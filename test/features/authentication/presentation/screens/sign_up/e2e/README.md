# Sign-up E2E

Flows preparados, **não executados em dispositivo**. As rotas estão registradas;
isso não comprova execução no app. Cadastro mantém factory e ownership pela screen;
somente Sign-in migrou para provide/addBloc do Modular. Seletores precisam ser
confirmados no build.

- `Success.yaml`: payload único, confirmação com e-mail e ausência de sessão ao reiniciar.
- `Failure.yaml`: validação local, conflito 409, entrada preservada e retry manual.
- `Loading.yaml`: resposta retida, campos bloqueados e uma única request.

## Execução

Use somente dispositivo de teste: os flows limpam dados/keychain. Nunca aponte
para produção. A fixture escuta somente loopback, não acessa backend ou storage
e verifica o payload completo e a ausência de Bearer sem registrar credenciais.

Na raiz, em um terminal:

```bash
python3 test/support/authentication/fakes/sign_up_http_server.py
```

Em Android, encaminhe a porta e instale um build exclusivamente com essa base:

```bash
adb reverse tcp:8766 tcp:8766
flutter run --dart-define=BASE_URL=http://127.0.0.1:8766/api/
```

No simulador iOS o loopback também aponta ao host; iOS físico não é suportado.
O build deve permitir HTTP local. Com app compilado/instalado, execute um por vez:

```bash
maestro test test/features/authentication/presentation/screens/sign_up/e2e/Success.yaml
maestro test test/features/authentication/presentation/screens/sign_up/e2e/Failure.yaml
maestro test test/features/authentication/presentation/screens/sign_up/e2e/Loading.yaml
```

Session/Welcome e as rotas de Authentication precisam estar ativos. O servidor
compartilha somente estado/utilitários HTTP da fixture de sign-in, não seus
endpoints de sessão. O loading é liberado explicitamente e no teardown.
Parsing, concorrência, lifecycle e falhas inesperadas continuam nos testes Flutter.

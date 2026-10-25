# Callback E2E

Flows preparados, **não executados em dispositivo**. As rotas estão registradas;
isso não comprova DI nem execução no app. Callback ainda usa factory e ownership
pela screen; somente Sign-in migrou para provide/addBloc do Modular.
Seletores e entrega nativa do deep link precisam ser validados no build.

- `Success.yaml`: 204, toast, entrada e ausência de sessão após reiniciar.
- `Failure.yaml`: 500, feedback seguro e retorno ao sign-in.
- `Invalid.yaml`: 403, link inválido e retorno ao sign-in.
- `Loading.yaml`: resposta retida, tela acessível de validação e uma request.

## Execução

Somente em dispositivo de teste: os flows apagam dados/keychain. Nunca use links
assinados reais ou API de produção. A fixture escuta somente loopback, verifica a
URL completa e a ausência de Bearer sem registrar links/credenciais e não acessa
serviços externos. A URL encaminhada para confirmação é sempre local.

Na raiz, mantenha a fixture em um terminal:

```bash
python3 test/support/authentication/fakes/callback_http_server.py
```

Em Android:

```bash
adb reverse tcp:8768 tcp:8768
flutter run --dart-define=BASE_URL=http://127.0.0.1:8768/api/
maestro test test/features/authentication/presentation/screens/callback/e2e/Success.yaml
maestro test test/features/authentication/presentation/screens/callback/e2e/Failure.yaml
maestro test test/features/authentication/presentation/screens/callback/e2e/Invalid.yaml
maestro test test/features/authentication/presentation/screens/callback/e2e/Loading.yaml
```

Session/Welcome e Authentication precisam estar ativos. Execute sequencialmente.
O manifest Android registra o envelope de navegação
`https://app.cordato.cloud/authentication/confirm-email`. Antes de executar,
garanta nas configurações do dispositivo que esses app links abrem **no app de
teste**, nunca no navegador. O envelope só entrega a rota ao Flutter; sua query
contém a URL da fixture local. Não execute se o sistema enviar o link ao browser.

No simulador iOS, use `-e CALLBACK_BASE=trocado://app/authentication/confirm-email`
em cada comando Maestro, de acordo com o esquema registrado em Info.plist.
Confirme antes que a entrega nativa preserva o path do callback. O loopback aponta
para o host; iOS físico não é suportado por essa configuração. O build precisa
permitir HTTP local. Não altere configurações de produção para viabilizar a suíte.

Loading é liberado explicitamente e no teardown, antes do timeout de 60 segundos
da fixture. Scripts de estatísticas/liberação são compartilhados com Sign-up.
Testes Flutter cobrem adicionalmente URL ausente/duplicada, troca de link/factory,
resultados obsoletos e descarte. A existência dos flows não prova execução E2E.

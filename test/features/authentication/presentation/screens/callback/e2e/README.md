# Callback E2E

Flows preparados, **não executados em dispositivo**. As rotas estão registradas;
isso não comprova DI nem execução no app. Callback ainda usa factory e ownership
pela screen; somente Sign-in migrou para provide/addBloc do Modular.
Seletores e entrega nativa do deep link precisam ser validados no build.

- `Success.yaml`: 204, toast, entrada e ausência de sessão após reiniciar.
- `Failure.yaml`: 500, feedback seguro e retorno ao sign-in.
- `Invalid.yaml`: 400 PocketBase, token inválido e retorno ao sign-in.
- `Loading.yaml`: resposta retida, tela acessível de validação e uma request.

## Execução

Somente em dispositivo de teste: os flows apagam dados/keychain. Nunca use links
com tokens reais ou API de produção. A fixture escuta somente loopback, verifica
POST `/api/collections/users/confirm-verification`, JSON `token` e ausência de
Bearer sem registrar credenciais e não acessa serviços externos. O token é fictício.

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
contém `token` fictício. O destino HTTP é fixo e usa a BASE_URL local do build.
Não execute se o sistema enviar o link ao browser.

No simulador iOS, use `-e CALLBACK_BASE=trocado://app/authentication/confirm-email`
em cada comando Maestro, de acordo com o esquema registrado em Info.plist.
Confirme antes que a entrega nativa preserva o path do callback. O loopback aponta
para o host; iOS físico não é suportado por essa configuração. O build precisa
permitir HTTP local. Não altere configurações de produção para viabilizar a suíte.

Loading é liberado explicitamente e no teardown, antes do timeout de 60 segundos
da fixture. Scripts de estatísticas/liberação são compartilhados com Sign-up.
Testes Flutter cobrem adicionalmente token ausente/vazio/duplicado, troca de token/factory,
resultados obsoletos e descarte. A existência dos flows não prova execução E2E.

Em produção, a confirmação no app requer configurar o template de verificação
da coleção `users` com um link para o callback e o placeholder `{TOKEN}`, por
exemplo `https://app.cordato.cloud/authentication/confirm-email?token={TOKEN}`.
Esta mudança não modifica template, backend ou associação de domínio. O template
padrão do PocketBase continua confirmando na página web quando usado.

# Session / Root E2E

Flows preparados, **não executados em dispositivo**. Os destinos estão registrados
na composição global; o teste de DI do logout passou com o contrato de
Authentication root-owned no módulo sem path. Session continua global sob ownership de AppWidget;
somente Sign-in usa provide/addBloc no escopo da página. Não crie outra instância
de Session nem transfira seu fechamento ao escopo de uma rota.

- `Success.yaml`: login fictício, reinício sem limpar dados, entrada por token
  já persistido validado por auth-refresh, logout e novo reinício sem sessão.
  A fixture conta refresh separadamente do login e exige zero requests de logout.
- `Failure.yaml` e `Loading.yaml`: wrappers de cenários legados de logout HTTP,
  incompatíveis com a limpeza local. Não execute estes arquivos nem a pasta inteira.
  Falha e espera do storage são cobertas por testes Flutter, não pela fixture HTTP.

Falha/leitura pendente do storage nativo não é injetável pela fixture HTTP.
Esses cenários, recuperação, corrida entre leitura e watch, troca de factory e
descarte são cobertos por testes de Bloc/Root com Futures controlados, não pelos
flows. Não acrescente bypasses de segurança no app para simular storage no E2E.

O servidor compartilhado oferece `POST /api/collections/users/auth-refresh`
com o token fictício para o reinício autenticado. Erros 401/403 de refresh,
respostas tardias e persistência pendente são cobertos pelos testes Flutter de
Session e HTTP; a existência do YAML não é homologação de backend ou dispositivo.

## Execução

Use somente dispositivo de teste: o preparo limpa dados/keychain. Nunca aponte
para produção; credenciais e token são fictícios. Os flows compartilham a
[fixture de logout](../../../../../settings/presentation/screens/settings/e2e/README.md)
na porta 8769, que escuta somente loopback e não chama serviços externos.

Após validar a composição, em build de teste instalado, execute na raiz:

```bash
python3 test/support/authentication/fakes/logout_http_server.py
```

Em Android, em outro terminal:

```bash
adb reverse tcp:8769 tcp:8769
flutter run --dart-define=BASE_URL=http://127.0.0.1:8769/api/
maestro test test/features/root/presentation/screens/app/e2e/Success.yaml
```

Execute sequencialmente, sem sharding. No simulador iOS o loopback aponta para
o host; iOS físico não é suportado. O build deve permitir HTTP local.
Os seletores precisam ser confirmados no build compilável.

O teste `test/features/root/presentation/widgets/app_session_integration_test.dart`
usa repositories e Blocs reais de Session, Authentication e Settings, com clients
mockados e Dashboard visual de teste. Ele valida a observação global no Flutter,
não o plugin nativo de storage nem a composição completa de `app_module.dart`.

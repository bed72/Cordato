# Session / Root E2E

Flows preparados, **não executados em dispositivo**. Os destinos estão registrados
na composição global; o teste de DI do logout ainda falha por visibilidade do
contrato de Authentication. Session continua global sob ownership de AppWidget;
somente Sign-in usa provide/addBloc no escopo da página. Não crie outra instância
de Session nem transfira seu fechamento ao escopo de uma rota.

- `Success.yaml`: login fictício, reinício sem limpar dados, entrada por token
  já persistido, logout e novo reinício sem sessão. A fixture comprova que não
  houve segundo login nem segunda revogação.
- `Failure.yaml`: reutiliza o flow de logout 503 e prova, quando executado,
  manutenção da sessão e da entrada após reinício, antes do retry manual.
- `Loading.yaml`: reutiliza a revogação retida do logout; a rota protegida é
  mantida até a operação ser liberada e remover o token.

Falha/leitura pendente do storage nativo não é injetável pela fixture HTTP.
Esses cenários, recuperação, corrida entre leitura e watch, troca de factory e
descarte são cobertos por testes de Bloc/Root com Futures controlados, não pelos
flows. Não acrescente bypasses de segurança no app para simular storage no E2E.

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
maestro test test/features/root/presentation/screens/app/e2e/Failure.yaml
maestro test test/features/root/presentation/screens/app/e2e/Loading.yaml
```

Execute sequencialmente, sem sharding. No simulador iOS o loopback aponta para
o host; iOS físico não é suportado. O build deve permitir HTTP local.
Loading usa o teardown do flow de logout para liberar a request antes do timeout
de 60 segundos. Os seletores precisam ser confirmados no build compilável.

O teste `test/features/root/presentation/widgets/app_session_integration_test.dart`
usa repositories e Blocs reais de Session, Authentication e Settings, com clients
mockados e Dashboard visual de teste. Ele valida a observação global no Flutter,
não o plugin nativo de storage nem a composição completa de `app_module.dart`.

# Edição de nome E2E

Flows preparados, **não executados em dispositivo**. A migração de User não
reativa os destinos comentados de Dashboard/Settings/User nem resolve o legado
das outras features. É necessário um build compilável com essas rotas ativas.

- `Success.yaml`: nome inicial inalterado não permite envio; trim no formulário,
  uma atualização e retorno ao perfil com recarga do nome.
- `Failure.yaml`: 422 por campo, entrada preservada, erro limpo ao editar e retry
  manual retornando ao perfil apenas após sucesso.
- `Loading.yaml`: atualização retida, tela mantida e uma única request antes da
  liberação. Bloqueio de campo/botão e teclado também são testados no Flutter.

Reutiliza a [fixture de User](../../user/e2e/README.md), porta 8770, com login
fictício e endpoints de controle locais. Não chama serviços externos. Os seletores
ainda precisam ser confirmados no app; arquivos YAML não provam validação E2E.

Após resolver os bloqueios globais e ativar as rotas, na raiz:

```bash
python3 test/support/user/fakes/user_http_server.py
```

Em outro terminal, no Android:

```bash
adb reverse tcp:8770 tcp:8770
flutter run --dart-define=BASE_URL=http://127.0.0.1:8770/api/
maestro test test/features/user/presentation/screens/edit/e2e/Success.yaml
maestro test test/features/user/presentation/screens/edit/e2e/Failure.yaml
maestro test test/features/user/presentation/screens/edit/e2e/Loading.yaml
```

Use somente dispositivo de teste: o preparo limpa dados/keychain. Nunca execute
contra produção. Rode sequencialmente, sem sharding e com HTTP local permitido.
iOS simulador usa loopback do host; iOS físico não é suportado. Loading libera a
request em teardown, antes do timeout de 60 segundos da fixture.

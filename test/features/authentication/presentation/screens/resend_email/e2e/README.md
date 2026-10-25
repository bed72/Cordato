# Resend-email E2E

Flows preparados, **não executados em dispositivo** devido aos bloqueios globais
de compilação/composição (`command_it`, `Either`, `response<T>` e módulo de rotas
de Authentication). Seletores precisam ser confirmados no build atualizado.

- `Success.yaml`: cooldown inicial, envio, feedback, novo cooldown e segundo envio manual.
- `Failure.yaml`: erro 429, e-mail preservado e retry imediato, sem novo cooldown na falha.
- `Loading.yaml`: resposta retida, bloqueio de duplicatas e cooldown após conclusão.

## Execução

Somente em dispositivo de teste: os flows apagam dados/keychain. Nunca execute
contra produção. A fixture escuta somente loopback, aceita cadastro para alcançar
a tela e conta apenas reenvios. Verifica JSON:API e ausência de Bearer sem logs
de credenciais; não acessa serviços externos. Reutiliza utilitários HTTP e scripts
de estatísticas/liberação das fixtures existentes.

Em um terminal na raiz:

```bash
python3 test/support/authentication/fakes/resend_email_http_server.py
```

Para Android, encaminhe a porta e instale um build exclusivamente com essa base:

```bash
adb reverse tcp:8767 tcp:8767
flutter run --dart-define=BASE_URL=http://127.0.0.1:8767/api/
```

No simulador iOS o loopback aponta para o host; iOS físico não é suportado.
O build deve permitir HTTP local. Session/Welcome e rotas de Authentication
precisam estar ativos. Execute um por vez, sem sharding:

```bash
maestro test test/features/authentication/presentation/screens/resend_email/e2e/Success.yaml
maestro test test/features/authentication/presentation/screens/resend_email/e2e/Failure.yaml
maestro test test/features/authentication/presentation/screens/resend_email/e2e/Loading.yaml
```

Os flows aguardam os 60 segundos reais, sem reduzir o cooldown de produção.
Loading é liberado explicitamente e no teardown. A fixture expira requests
retidas em 60 segundos; libere antes desse prazo. Testes Flutter avançam tempo
virtual e cobrem fallback, concorrência, troca de factory e descarte do timer/Bloc.

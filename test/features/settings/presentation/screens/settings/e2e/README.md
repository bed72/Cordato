# Logout E2E

Flows preparados, **não executados em dispositivo**. As rotas estão registradas
e o teste global de DI do logout passou após Authentication adotar um único
módulo sem path e disponibilizar seu contrato no injector raiz. Isso não valida
execução no dispositivo. Logout mantém factory e ownership pela
screen; Session global redireciona após limpeza do storage. Os seletores precisam
ser confirmados no build atualizado.

- `Success.yaml`: confirmação cancelada sem operação, limpeza local sem HTTP, navegação por
  observação da sessão e ausência de sessão após reiniciar.
- `Failure.yaml` e `Loading.yaml`: cenários legados de revogação HTTP, agora
  incompatíveis e não executáveis. Não execute a pasta inteira. A fixture não
  oferece mais endpoint de logout nem injeta falha/atraso no storage nativo;
  essas coberturas ficam nos testes Flutter com Futures controlados.

## Execução

Somente em dispositivo de teste: os flows apagam dados/keychain. Nunca use API
de produção ou credenciais reais. A fixture aceita login fictício, respostas
mínimas da Dashboard, mas rejeita qualquer DELETE como inesperado. O sucesso
exige zero requests de logout. Escuta somente loopback e não chama serviços externos.

Na raiz, em um terminal:

```bash
python3 test/support/authentication/fakes/logout_http_server.py
```

Em Android:

```bash
adb reverse tcp:8769 tcp:8769
flutter run --dart-define=BASE_URL=http://127.0.0.1:8769/api/
maestro test test/features/settings/presentation/screens/settings/e2e/Success.yaml
```

Session, Welcome, Dashboard, Settings e Authentication precisam estar ativos.
Execute sequencialmente, sem sharding. No simulador iOS o loopback aponta para
o host; iOS físico não é suportado. O build deve permitir HTTP local.

Testes Flutter cobrem concorrência, confirmação obsoleta, lifecycle, falhas
inesperadas e espera da limpeza do storage. Maestro não injeta falha no storage
nativo. Os testes isolados de Settings não provam o redirecionamento global;
os flows só poderão validá-lo quando a composição do app estiver compilável.

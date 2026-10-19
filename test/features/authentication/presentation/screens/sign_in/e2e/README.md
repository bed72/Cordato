# Sign-in E2E

Três flows Maestro, complementares aos testes Flutter de widget em
`../sign_in_screen_test.dart`:

- `Success.yaml`: envio, navegação para Dashboard, payload recebido uma única vez
  e persistência da sessão após reiniciar.
- `Failure.yaml`: campos obrigatórios, e-mail inválido sem request, limpeza de erro
  ao editar, rejeição remota, preservação dos dados, ausência de retry automático
  e retry manual bem-sucedido.
- `Loading.yaml`: resposta retida até liberação explícita, campo desabilitado,
  botão em loading, envio duplo produzindo uma única request e conclusão.

## Pré-requisitos

- App de desenvolvimento compilável e instalado em um dispositivo Maestro.
- Módulos de Session, Welcome e Dashboard ativos em `app_module.dart`.
- Build apontando exclusivamente para a API local abaixo. Não execute contra
  produção; as credenciais e o token são fictícios.
- Python 3 e Maestro disponíveis. Execute os flows sequencialmente, sem sharding:
  o servidor mantém um cenário por vez.

Os bloqueios já presentes de compilação (`command_it`, `Either` e `response<T>`)
e os módulos comentados precisam ser resolvidos antes da execução E2E. Esta suíte
não altera esses pontos. Os seletores foram derivados do código e ainda precisam
ser confirmados na árvore semântica do build atualizado; a checagem de sintaxe
não substitui a execução no dispositivo.

## Executar

Na raiz do projeto, mantenha a fixture em um terminal:

```bash
python3 test/support/authentication/fakes/sign_in_http_server.py
```

Para Android, encaminhe a porta do dispositivo para o host:

```bash
adb reverse tcp:8765 tcp:8765
```

Instale o build debug usando essa base. No simulador iOS, `127.0.0.1` também
aponta para o host. Dispositivos iOS físicos não são suportados por essa
configuração loopback. A política de rede do build deve permitir a API local;
o manifest debug Android atual já permite HTTP.

```bash
flutter run --dart-define=BASE_URL=http://127.0.0.1:8765/api/
maestro test test/features/authentication/presentation/screens/sign_in/e2e
```

Cada flow limpa os dados do app e o keychain antes de começar; use somente um
dispositivo de teste. `Success` reinicia sem limpar dados para validar a sessão.
O `appId` de Android/iOS é `com.bed.cordato`.

`scripts/configure.js` reinicia a fixture, `stats.js` consulta contagem e igualdade
do payload sem expor credenciais, e `release.js` libera a request de Loading,
inclusive no teardown. O servidor escuta somente em `127.0.0.1`, não acessa
serviços externos e oferece respostas mínimas para a Dashboard.

## Limites

Os três flows cobrem os estados principais, não todas as combinações possíveis.
Falhas de storage, descarte, erros inesperados, limites de senha e classificação
HTTP continuam sendo responsabilidade dos testes unitários correspondentes.
Não há injeção de falha no storage nativo nem de factory de Bloc via Maestro.

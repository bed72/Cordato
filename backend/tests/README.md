# Testes do backend

Execute os comandos a partir de `backend/`.

## Organização

```text
internal/
  application/audio/                       aceite e testes unitários
  bootstrap/                               composição e testes unitários de CLI
  infrastructure/http/audio/               transporte HTTP
tests/
  architecture/                            fronteiras de dependências e testes
  integration/
    bootstrap/                             configuração e segurança
    infrastructure/http/audio/             contrato HTTP e ausência de persistência
    pocketbase/                            migrations, autenticação, despesas e métricas
  e2e/server/                              executável real, HTTP e reinícios
  support/pocketbase/                       preparação e fixtures compartilhadas
```

Integração espelha a camada/responsabilidade exercitada; as APIs geradas do
PocketBase ficam agrupadas por tecnologia porque não há repositories ou casos de
uso financeiros próprios no backend. Não criar diretórios vazios para simular camadas.
Testes unitários ficam ao lado da implementação, conforme a convenção Go.

Helpers compartilhados em `support/pocketbase/` usam arquivos `.go` para serem
importados por diferentes pacotes de teste, mas nunca pela produção. Os arquivos
separam aplicação, HTTP, records, migrations e localização do backend. Fixtures e
doubles exclusivos de uma suíte ficam em arquivos `*_test.go` próprios dessa suíte.
Não criar dependências entre suítes de integração e E2E.

## Comandos

```sh
go test -count=1 ./...
go test -race ./...
go vet ./...
```

Execução focada, sem abrir portas:

```sh
go test -count=1 ./internal/...
go test -count=1 ./tests/architecture
go test -count=1 ./tests/integration/...
```

E2E opcional, com executável temporário e HTTP real somente em loopback:

```sh
CORDATO_HTTP_SMOKE=1 go test -count=1 -run '^TestLocalServerLifecycle$' -v ./tests/e2e/server
```

Sem essa variável, E2E é ignorado. O teste abre portas efêmeras em `127.0.0.1`, usa
banco descartável e encerra os processos via SIGTERM. Não inicia serviços existentes,
não usa dados reais, SMTP externo, IA ou deploy. O race detector instrumenta os
testes; o binário filho usa build normal.

### Coleção Bruno e tooling

```sh
make bruno-check
make test-bruno
```

`bruno-check` exige Node.js e CLI Bruno 4+ instalados. Valida exatamente duas
requests (login e upload), sintaxe, origem loopback, limpeza do token no login,
credenciais e fallback CLI, captura em memória e upload sem sessão bloqueado.
Não faz HTTP, monta UI ou acessa ambientes privados. O ambiente versionado contém
somente nomes de Secrets. Shells: `sh -n` e `shellcheck -e SC1090`.

`test-bruno` habilita `CORDATO_HTTP_SMOKE=1 CORDATO_BRUNO_SMOKE=1` no E2E acima.
Além dos cenários Go existentes, executa somente login e upload binário sintético
da coleção, com usuário e banco temporários. Exige exatamente duas requests com
asserções/status reais; execução vazia, request pulada ou asserção falha não passa.
O relatório temporário omite bodies/headers. Não usa arquivos privados, produção
ou SMTP externo. A redução da coleção não remove testes Go de APIs nativas.

`make bruno` chama o login no servidor iniciado manualmente; `make bruno-upload`
faz login e envia o arquivo privado. Veja [bruno/README.md](../bruno/README.md).

## Isolamento

- Bancos e cópias das migrations são temporários; não ler `.env` ou dados existentes.
- A suíte padrão usa HTTP em memória e transporte de e-mail capturado, sem portas.
- Não paralelizar cenários que alteram ambiente, diretório corrente ou registro
  global de migrations. Pacotes distintos executam em processos separados.
- O suporte descobre a raiz do backend antes de entrar no workspace descartável;
  não basear a montagem em caminhos relativos dependentes da pasta da suíte.
- Autenticação, propriedade, migrations e segurança continuam cobertas. Somente os
  cenários exclusivos da saúde customizada removida deixaram de existir; a saúde
  nativa, o painel e a ausência da rota da POC são verificados.
- `architecture/` impede dependências externas/transporte/persistência em application,
  imports de suporte na produção e dependências de integração/E2E nos unitários.

Esses testes não comprovam mídia válida, processamento de áudio, SMTP real,
TLS/Traefik, integração Flutter ou disponibilidade remota.

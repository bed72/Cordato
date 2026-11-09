# Cordato — PocketBase

Serviço independente **PocketBase 0.41.1** para contas, despesas pessoais e métricas mensais. O Docker Compose no Dokploy continua usando o executável oficial. Um executável Go local usa a mesma versão como biblioteca, preservando as migrations JavaScript. Sem runtime Node, hooks JavaScript, worker, IA ou Batch API.

O backend vive em `backend/` no repositório do aplicativo Flutter, mas tem build, serviço e volume próprios. Execute os comandos deste documento **a partir de `backend/`**. O Flutter já usa o SDK oficial PocketBase; a presença dos arquivos neste repositório não comprova provisionamento ou homologação remota.

## Escopo E Fontes De Verdade

Este documento descreve o serviço existente, sua operação e limites de validação.

| Documento | Responsabilidade |
| --- | --- |
| [AGENTS.md](AGENTS.md) | Regras de manutenção e segurança para agentes |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Camadas, composição, dependências e contratos do backend Go |
| [adrs/README.md](adrs/README.md) | Decisões arquiteturais e suas consequências |
| [tests/README.md](tests/README.md) | Organização, isolamento e comandos dos testes |
| [bruno/README.md](bruno/README.md) | Teste manual dos endpoints, ambientes e coleção Bruno |
| [Arquitetura do aplicativo](../ARCHITECTURE.md#backend-pocketbase-e-limite-de-integração) | Limites da integração Flutter–PocketBase |
| [README da raiz](../README.md) | Panorama do produto |

O módulo Go é `cordato/backend`, com entrada em `cmd/cordato/`. Sua composição
permanece local; a existência desse código não troca o executável oficial usado
pelo Docker. ADRs registram escolhas, não comprovam testes ou implantação.

- **Implementado na configuração:** contas individuais e despesas próprias,
  autenticação/verificação nativas, regras de propriedade e cascata, além da view
  somente leitura `metrics` com agregações por proprietário/mês.
- **Ausente nesta configuração:** agregações por intervalos arbitrários, insights, endpoints
  customizados de sugestões, orçamentos e família. O Flutter obtém sugestões por
  GET filtrado do histórico pessoal, sem recurso adicional no servidor.
- **Cliente Flutter:** Authentication, Session, User, Expense e Metrics usam o SDK
  PocketBase compartilhado pela DI, sem Dio ou client HTTP próprio. A sessão usa
  `AsyncAuthStore` com Secure Storage; logout é local, sem revogação remota ou
  confirmação de exclusão durável. Expense envia `owner` na criação, a categoria
  selecionada (`other` por padrão) e a data civil codificada
  como meia-noite UTC, sem conversão de fuso. Paginação usa `page`/`perPage` e
  filtros nativos. Não há migração de registros antigos ou fallback para campos
  vazios; os campos opcionais de despesas permanecem inalterados. Metrics consulta
  a view mensal, sem somar despesas ou recalcular percentuais no cliente; a UI da
  Dashboard e a navegação por categoria/mês ficam intactas.
- **Pendente:** provisionar o banco novo com a migration consolidada e homologar
  o fluxo real, incluindo autorização e precisão dos valores.
  Não basta mudar a URL nem considerar testes com clients mockados como validação
  das permissões do serviço.
- **Fora desta etapa:** migração de dados, provisionamento remoto e deploy.

Os exemplos Dart abaixo ilustram a API nativa do SDK PocketBase. No aplicativo,
essas chamadas pertencem aos repositories de infrastructure; SDK e records não
atravessam os contratos de application nem chegam aos Blocs. As evidências locais
ao final são registros anteriores, não verificações executadas nesta revisão.

## Arquivos

- `compose.yml`: um serviço `pocketbase`, volume persistente e rede externa `dokploy-network`.
- `Dockerfile`: base Alpine fixada por digest e binário oficial Linux verificado por SHA-256, com suporte amd64, arm64 e arm/v7; execução sem root. Atualizações da base exigem revisão do digest.
- `docker/entrypoint.sh`: exige chave de criptografia de 32 bytes, fixa opções seguras e inicia o serviço.
- `pb_migrations/1793491200_initial.js`: única migration transacional, **exclusiva para banco novo**. Consolida schema, permissões, superusuário, settings, view `metrics` e links de verificação e recuperação de `users` para o app. Templates administrativos permanecem nativos. As quatro migrations incrementais foram incorporadas e removidas; esta revisão não atualiza bancos existentes.
- `.env.example`: nomes das variáveis, sem segredos.
- `AGENTS.md`, `ARCHITECTURE.md` e `adrs/`: orientações, arquitetura e decisões do projeto Go.
- `cmd/cordato/`: entrada do executável Go local.
- `Makefile`: servidor local, verificações Go e execução explícita da coleção Bruno.
- `bruno/`: somente login/upload locais, com ambiente privado development ignorado e example sem credenciais versionadas.
- `tool/`: helpers de desenvolvimento; Node/Bruno não entram no runtime Go ou Docker.
- `internal/bootstrap/`: composição do PocketBase, plugins de migrations JS, flags, configuração segura e registro da rota de áudio.
- `internal/application/audio/`: aceite síncrono, entrada própria, limite único e falhas de áudio, sem SDK ou transporte.
- `internal/infrastructure/http/audio/`: headers MIME, leitura limitada e resposta da rota de áudio.
- `tests/architecture/`: isolamento de application, produção e suporte de testes; fronteira entre unitários e integração/E2E.
- `tests/integration/bootstrap/`: configuração segura e migrations automáticas desabilitadas.
- `tests/integration/pocketbase/`: migrations, autenticação, autorização, CRUD e métricas nativas.
- `tests/integration/infrastructure/http/audio/`: contrato HTTP e ausência de persistência do áudio.
- `tests/e2e/server/`: ciclo opcional do executável real por HTTP em loopback.
- `tests/support/pocketbase/`: preparação e fixtures compartilhadas entre os pacotes de teste.

## Executável Go Local

Para **chamar o endpoint manualmente**, siga o passo a passo em
[bruno/README.md](bruno/README.md). Por solicitação explícita, a coleção foi reduzida
a **login e upload**, exclusivamente locais, sem refresh, cadastro, CRUD ou produção.
`make run` inicia o Go local; `make bruno` faz login pela CLI e
`make bruno-upload` faz login e envio pela CLI com variáveis de processo.
Na interface, selecione o ambiente privado `development` preparado nesta máquina,
envie Login e selecione sua gravação no Body do Upload. Não precisa copiar token.
O ambiente versionado `example` continua sem valores privados, com Secrets para
outras máquinas. Não há criação/verificação automática de contas nem helper de
preparação de usuário. As regras do backend e os testes negativos Go permanecem.
Não há arquivos `.env` exclusivos do Bruno. O servidor usa `.env.development.local`,
com `.env.development.example` como modelo; a interface usa seu próprio ambiente
privado `bruno/environments/development.bru`.

Requer **Go 1.27 ou superior**, conforme o módulo PocketBase 0.41.1. Execute a
partir de `backend/`. As dependências diretas são PocketBase e `pflag`, o parser de
flags já usado pelo próprio PocketBase, para tratar `--help` sem inicializar o banco.
`go.mod` e `go.sum` fixam também as dependências transitivas. Não há Echo, Chi, ORM
ou framework de DI.

```sh
go test ./...
go test -race ./...
go vet ./...
go build -o .temp/cordato-server ./cmd/cordato
```

Os testes padrão usam cópias das migrations e bancos temporários, dados fictícios,
requisições HTTP em memória e `tests.TestMailer` oficial. Não carregam `.env`, não
usam SMTP, não escutam portas e não acessam volume ou banco existentes. Os testes
são sequenciais porque ambiente, diretório corrente e registro de migrations JS
são globais no processo. As alterações temporárias são restauradas ao terminar.

Testes unitários permanecem junto do código (`internal/application/audio/` e
`internal/bootstrap/`). Integração e E2E ficam exclusivamente em `tests/`, por
responsabilidade e camada, sem criar camadas financeiras para CRUD nativo.
Fixtures/doubles locais ficam em arquivos próprios; helpers compartilhados não
podem ser importados pela produção. Estrutura e comandos focados estão em
[tests/README.md](tests/README.md).

Para validar o **executável real por HTTP**, há um teste opcional em macOS/Linux:

```sh
CORDATO_HTTP_SMOKE=1 go test -count=1 -run '^TestLocalServerLifecycle$' -v ./tests/e2e/server
```

Ele compila o executável em diretório temporário, inicia três processos sequenciais
em portas efêmeras de `127.0.0.1` e encerra cada um com `SIGTERM`. Valida aplicação
da migration pelo próprio `serve`, resposta HTTP do painel (sem teste visual), login,
aceite/rejeição de áudio, CRUD, isolamento e preservação de dados/histórico após reinícios.
Usuários verificados são fixtures criadas entre execuções, com o servidor parado;
o teste não simula confirmação de e-mail pelo servidor real. A configuração SMTP
do banco descartável é redirecionada a `127.0.0.1:1` antes dos logins para impedir
contato com o provedor externo; nenhum envio é solicitado. Não usa proxy HTTP,
segredos ou dados existentes e não deixa servidor rodando. Sem a variável acima,
esse teste é ignorado e a suíte permanece sem abrir portas.

Para iniciar manualmente, configure em ambiente privado **credenciais locais
descartáveis**, usando os mesmos nomes da seção de instalação abaixo. Não reutilize
credenciais ou chave de produção. A migration inicial exige URL HTTPS, administrador,
senha SMTP e chave de exatamente 32 bytes; para um banco local sem envio de e-mail,
a senha SMTP pode ser fictícia. Não solicite envios no servidor manual: somente os
testes em memória substituem o transporte SMTP por um capturador.

```sh
go run ./cmd/cordato serve --http=127.0.0.1:8091 --dir=.temp/cordato/pb_data --migrationsDir=pb_migrations --automigrate=false
```

O diretório padrão também é `.temp/cordato/pb_data`, separado de `pb_data/` e do
volume Docker, ignorado pelo Git. Não aponte `--dir` para dados reais nesta etapa.
A porta manual 8091 evita a porta 8090 do serviço atual. O endereço de escuta deve
ser informado explicitamente como no exemplo para manter a execução local.

Permanecem disponíveis a API nativa `/api/`, a saúde pública `/api/health` e o painel
`/_/`. A rota customizada `GET /api/cordato/health`, usada apenas na POC, foi removida.
O CRUD financeiro permanece nativo, sem use cases ou repositories de repasse.
O painel é servido pelo PocketBase; os testes HTTP não exercitam interface visual.

### Entrada binária de áudio (somente executável Go local)

`POST /api/collections/audio/process` é uma operação customizada, não uma collection
`audio` ou CRUD de records. Exige token nativo da coleção `users` e e-mail verificado,
antes de ler o body. Não foi publicada no runtime Docker oficial ou integrada ao Flutter.

O contrato do futuro gravador é uma gravação finalizada M4A/AAC-LC enviada diretamente
como bytes no body, com `Content-Type: audio/mp4`. Não recebe multipart, JSON, base64,
nome de arquivo, proprietário ou metadados financeiros. Parsing MIME aceita variação
de caixa e parâmetros válidos, sem validar o codec declarado. Aliases `audio/m4a`,
`audio/aac`, `audio/wav` e `application/octet-stream` não são suportados. Somente
`Content-Encoding` ausente ou `identity` é aceito; não há descompressão.

O teto inclusivo é **2.097.152 bytes (2 MiB)**, definido em application e aplicado
pela API pública `apis.BodyLimit` da rota. Autorização e headers precedem esse limite;
os demais middlewares, timeouts e rate limits nativos permanecem ativos. Tamanho
declarado excessivo é rejeitado antes da leitura; tamanho desconhecido ou incorreto
também é limitado pelo fluxo real, lendo no máximo um byte adicional para detectar
excesso. A memória é limitada por upload, não globalmente por processo.

| Status | Significado |
| --- | --- |
| `202` | Leitura completa e aceite: `{"status":"accepted"}` |
| `400` | Conteúdo vazio, erro de leitura ou transferência incompleta |
| `401` | Token ausente ou inválido |
| `403` | Outra coleção auth (inclusive superusuário) ou e-mail não verificado |
| `413` | Tamanho declarado ou efetivo acima do teto |
| `415` | Tipo MIME ou codificação não suportados |

Erros usam o envelope nativo PocketBase, sem expor áudio, credenciais ou erro bruto.
O handler só delega uma vez ao caso de uso após terminar a leitura sem erro; application
revalida conteúdo não vazio e tamanho. **`202` significa apenas aceite preparatório**:
os bytes são descartados após a requisição. Não há processamento, transcrição, IA,
persistência em arquivo/banco/storage, fila, goroutine de processamento, realtime,
despesa criada, ID de job, acompanhamento ou conclusão futura garantida. Repetir o
upload repete o aceite, sem deduplicação persistente.

Não há inspeção de container, decodificação, validação de AAC-LC, integridade ou
duração (inclusive 60 segundos), nem FFmpeg/FFprobe. Bytes sintéticos não decodificáveis
são aceitos quando passam pelas validações limitadas desta etapa. Os testes Go
exercitam esses bytes, autorização sem leitura, limites conhecidos/desconhecidos,
falhas parciais, espera por EOF, ausência de efeitos persistentes e fronteiras de
imports. O smoke opcional também cobre aceite e rejeição por HTTP real em loopback.
Nenhuma disponibilidade remota ou homologação de um gravador Flutter é comprovada.

`jsvm` executa os arquivos existentes em `pb_migrations/`; `migratecmd` registra
os comandos e templates JS. `automigrate` é falso por padrão; migrations pendentes
continuam sendo aplicadas por `serve` ou `migrate up`. O histórico `_migrations`
impede reaplicar a inicial. Não converter, renomear ou reaplicar a inicial em banco
existente. Hooks JS e modo dev ficam desabilitados por padrão; o padrão de arquivos
dos hooks impede carregamento mesmo ao fornecer `--hooksDir`.

O executável não registra o atualizador do binário oficial: atualizações exigem
revisar `go.mod`, dependências, testes e recompilar. Não use o comando `update` para
substituir um binário customizado por uma distribuição oficial. Dockerfile,
entrypoint, Compose e migration inicial não foram alterados; este executável ainda
não substitui o runtime Docker nem comprova homologação Flutter ou remota.

## Instalação no Dokploy

O DNS `pocketbase.cordato.cloud` já foi criado como CNAME para `dokploy.cordato.cloud`. DNS não configura o proxy nem emite certificado.

1. Criar um serviço **Docker Compose** apontando para o repositório Flutter e o arquivo **`backend/compose.yml`**. O `build.context: .` é relativo à pasta desse Compose: deve resolver para `backend/`, com `backend/Dockerfile`, nunca para a raiz Flutter. Não incluir fontes/assets do app no contexto. Conferir que `dokploy-network` existe e que o projeto/volume são novos e vazios. Não reutilizar banco ou volume do Drocato. Se já houver uma instalação Cordato, preservar explicitamente o projeto Compose e o volume existentes; mudar a origem Git não autoriza recriar dados.
2. No ambiente privado do **serviço Compose**, configurar as variáveis abaixo. Não usar build args para segredos nem carregar o `.env` remanescente do antigo Node.
3. Na configuração de domínio do Dokploy, usar **`pocketbase.cordato.cloud`**, serviço **`pocketbase`**, porta interna **8090**, caminho `/`, HTTPS com certificado. O TLS termina no Traefik; internamente o serviço usa HTTP. Não publicar 8090 no host.
4. Após autorização operacional, executar o deploy. As migrations pendentes são aplicadas ao iniciar; falha de bootstrap deve interromper o serviço. `--automigrate=false` impede geração automática pelo painel, **não** impede aplicar migrations versionadas.
5. Conferir `/api/health`, painel `https://pocketbase.cordato.cloud/_/`, envio de e-mail e login administrativo com MFA. A saúde HTTP não prova entrega SMTP, isolamento entre contas ou backup recuperável.

| Variável | Uso |
| --- | --- |
| `POCKETBASE_PUBLIC_URL` | URL absoluta HTTPS para os links. Padrão do Compose: `https://pocketbase.cordato.cloud` |
| `POCKETBASE_ADMIN_EMAIL` | E-mail válido do único administrador inicial |
| `POCKETBASE_ADMIN_PASSWORD` | Senha forte inicial do administrador, sob a política nativa de superusuários |
| `SMTP_PASSWORD` | Credencial SMTP Resend, normalmente a API key do provedor |
| `POCKETBASE_ENCRYPTION_KEY` | **Obrigatória em todos os reinícios**, exatamente 32 bytes; usar 32 caracteres ASCII aleatórios |

Gere e armazene a chave em um gerenciador de segredos. Não imprima ambiente resolvido (`docker compose config`), chaves, respostas de autenticação ou links de confirmação em logs compartilhados. Não forneça credenciais na linha de comando.

Administrador e SMTP são provisionados **uma única vez**. Após a migration concluir, `POCKETBASE_ADMIN_EMAIL`, `POCKETBASE_ADMIN_PASSWORD` e `SMTP_PASSWORD` podem sair do ambiente: configurações e hash da senha já estão no volume. Reiniciar com outros valores não rotaciona credenciais nem sobrescreve ajustes feitos no painel. Rotacione pelo painel/API nativos, com autorização e atualização correspondente no provedor. Preserve a chave de criptografia: perdê-la impede ler as configurações; trocá-la diretamente não é uma rotação suportada.

O `.env` do antigo projeto Node permaneceu no diretório anterior e não foi lido nem transferido. Nenhum segredo foi trazido para `backend/`. O Dokploy deve receber somente as variáveis listadas. Para validações Compose pela CLI, use um arquivo privado explícito **fora do repositório**, evitando carregar arquivos `.env` implicitamente.

### Settings iniciais

- Identidade **Cordato**, cor `#237A4B`, remetente `Cordato <contato@cordato.cloud>`.
- SMTP `smtp.resend.com:465`, TLS, usuário `resend`, AUTH `PLAIN`. O domínio remetente precisa estar autorizado no Resend.
- Templates HTML pt-BR de confirmação, recuperação, troca de e-mail, OTP e alerta de login; sem recursos externos. A inicial configura a verificação de `users` para `https://app.cordato.cloud/authentication/confirm-email?token={TOKEN}` e a recuperação de senha de `users` para `https://app.cordato.cloud/authentication/reset-password?token={TOKEN}`; os demais destinos e templates administrativos usam as telas nativas `/_/#/auth/.../{TOKEN}`.
- Todos os templates usam Cordato, nome no topo em 28 px, título em 24 px e corpo em 16 px; OTP em 22 px. Nome no topo e código OTP usam texto verde `#237A4B`, sem faixa de fundo ou linha verde sob o nome. Botões de ação usam fundo verde e texto branco. A cor também é usada no painel e tem contraste de aproximadamente 5,4:1 com branco. Essa identidade está na migration inicial, exclusiva para banco novo; redeploy em banco já provisionado não atualiza a cor do painel nem os templates. Domínio e endereço do remetente permanecem inalterados.
- Superusuário com senha, OTP de seis caracteres/180 segundos, MFA de 600 segundos e alerta de novo login. Não existe conta técnica de worker. Garantir acesso à caixa administrativa e entrega SMTP antes de operar; não desabilitar MFA para contornar problemas de envio.
- Rate limits nativos: `*:auth` **4/3s**, `*:create` **30/6s**, `/api/` **300/10s**, sem IPs excluídos. Batch desabilitado.
- Proxy: `X-Forwarded-For`, `useLeftmostIP=false`. O Traefik precisa normalizar esse header, e a origem não pode ficar exposta diretamente. A rede compartilhada Dokploy não substitui isolamento entre serviços não confiáveis.
- Arquivos e backups locais, S3 desabilitado. Backup automático domingo **00:00 UTC**, retenção de **três** cópias. Logs mantêm defaults nativos; não habilitar debug.

### Persistência e recuperação

Se o início falhar com `registerMigrations: permission denied`, conferir a imagem:
os diretórios de `/opt/cordato/migrations` precisam de permissão `0555` para
travessia pelo usuário `10001:10001`; os arquivos permanecem `0444`. O Dockerfile
normaliza os diretórios após o `COPY`. Publicar a correção e reconstruir a imagem
no mesmo projeto Compose, preservando volume e chave de criptografia; não executar
como root nem recriar o banco para contornar o erro.

O volume `pocketbase_data` monta `/pb/pb_data` e é prefixado pelo projeto Compose. Manter o mesmo projeto/volume nas atualizações. Há somente uma instância; não escalar réplicas compartilhando SQLite. O filesystem da imagem é somente leitura; dados, settings e backups vão ao volume. `/tmp` tem limite de 64 MiB; revisar mediante medição se operações temporárias exigirem mais espaço.

**Não usar `down -v`, reset, `migrate down` ou `history-sync` para resolver falha.** O rollback da inicial é bloqueado. Corrigir variáveis e reiniciar com o mesmo volume retoma a migration pendente; não remove nem adota contas existentes. Esta inicial não atualiza instalações antigas. Mudanças futuras no schema exigem novas migrations.

O backup local não protege contra perda da VPS. Guardar cópia consistente fora do host, preservar a versão da imagem e a chave separadamente e testar restauração em destino descartável. Criptografia protege os **settings**, não todas as despesas, coleções ou arquivos. Build, deploy, restauração e alterações remotas exigem autorização própria.

## Coleções

### `users`

Coleção auth nativa, cadastro público sem aprovação manual. Login exige e-mail confirmado. Usuário verificado consulta, altera e exclui somente a própria conta; sem `manageRule`. Campos administrativos não são liberados ao cliente. Os campos ocultos continuam sob proteção nativa, sem hook customizado.

- `name`: opcional, de 2 a 32 caracteres quando preenchido, sem restrição adicional de formato.
- `avatar`: texto opcional até 2.048 caracteres, usado como seed no Flutter; não há upload de imagem.
- Senha: 6–16 caracteres, com minúscula ASCII, maiúscula ASCII e número. Não altera a política de `_superusers`.
- `created` e `updated`: datas automáticas nativas em UTC, assim como em `expenses`.
- Exclusão do usuário remove todas as suas despesas por cascata.

**Sem hooks, cadastrar não envia confirmação automaticamente.** O Flutter deve criar a conta e chamar o método oficial de verificação:

```dart
await pb.collection('users').create(body: {
  'email': email,
  'password': password,
  'passwordConfirm': password,
});
await pb.collection('users').requestVerification(email);
// Mostrar instrução para confirmar o link recebido; depois fazer login.
```

Reenvio, recuperação e troca de e-mail usam endpoints nativos. O SDK envia o token automaticamente após login. Não enviar senha, tokenKey, verified ou timestamps em atualizações genéricas de perfil.

Antes de provisionar o banco novo com a migration consolidada, hospedar e homologar
os arquivos de associação de `app.cordato.cloud` e instalar o app compatível,
conforme [app_links/README.md](../app_links/README.md). O bootstrap configura
templates, SMTP e administrador uma única vez. Aplicação no servidor exige
autorização operacional separada. Não reaplicar em bancos existentes nem usar
`history-sync` como substituto de um banco novo. Links antigos não são reescritos.

Se um novo e-mail de recuperação ainda apontar para
`pocketbase.cordato.cloud/_/#/auth/confirm-password-reset/`, conferir se
se o serviço usa a revisão com a inicial consolidada e um banco provisionado por
ela. Um redeploy sobre o banco antigo não reaplica a inicial. Após publicar o app,
as associações e provisionar o banco novo, solicitar um novo e-mail.

### `expenses`

Listagem, consulta, criação, alteração e exclusão exigem usuário verificado da coleção `users` e proprietário correto. O frontend envia `owner` na criação; o servidor recusa dono diferente e impede transferência. Superusuários mantêm acesso administrativo nativo completo.

| Campo | Contrato |
| --- | --- |
| `owner` | Relação única obrigatória com `users`, cascata ao excluir a conta |
| `amount` | Centavos inteiros positivos, entre **1 e 9007199254740991** |
| `description` | Texto opcional, limites nativos do campo Text |
| `occurred_on` | Date opcional com data/hora UTC; sem default |
| `category` | Select único opcional, sem default; opções compartilhadas |
| `created` / `updated` | Autodate nativo; cliente não deve informar |

Categoria e data omitidas ficam vazias (`""`), não `null`. **O Date opcional nativo também normaliza uma entrada inválida para vazio**, em vez de retornar erro; o frontend deve validar o valor antes de enviá-lo. O frontend decide valores iniciais e formata a data/hora. Não converter valores monetários para float no modelo de negócio.

```dart
final today = DateTime.now();
await pb.collection('expenses').create(body: {
  'owner': pb.authStore.record!.id,
  'amount': 2590,
  'description': 'Almoço',
  'occurred_on': DateTime.utc(today.year, today.month, today.day).toIso8601String(),
  'category': 'food',
});
```

Categorias: `food`, `pets`, `taxes`, `health`, `travel`, `housing`, `leisure`, `shopping`, `services`, `transport`, `education`, `financing`, `insurance`, `investments`, `personal_care`, `subscriptions`, `gifts_and_donations`, `other`. Traduzir rótulos no Flutter. Somente o superusuário altera as opções no schema; renomear/remover opções exige tratar registros existentes. Como `automigrate` está desabilitado, registrar alterações de schema em migrations futuras para reproduzi-las em outras instalações.

IDs são strings nativas do PocketBase, **não UUIDv7**. API REST e autenticação são nativas PocketBase, não JSON:API/Sanctum: o cliente PHP anterior não é compatível sem adaptação. Este trabalho não migra dados, contas ou sessões do PHP.

### `metrics`

View Collection nativa, somente leitura, com um registro por proprietário/mês
com despesas datadas. Somas e percentuais são calculados em SQL sobre `expenses`,
sem hooks, endpoint customizado, tabela materializada ou cálculo no Flutter.
`listRule` e `viewRule` exigem autenticação na coleção `users`, e-mail verificado
e `owner = @request.auth.id`. Criar, editar e excluir records pela API é bloqueado.
As regras de `expenses` não são herdadas automaticamente por views; por isso a
view tem regras próprias e a subconsulta das categorias usa o mesmo proprietário.

| Campo | Contrato |
| --- | --- |
| `id` | Menor ID de despesa do grupo; pode mudar quando essa despesa é excluída |
| `owner` | Relação com o proprietário, inferida do campo de `expenses` |
| `start_date` / `end_date` | Texto civil `YYYY-MM-DD`, primeiro e último dia do mês |
| `total_amount` | Soma de `CAST(amount AS INTEGER)`, exposta como texto decimal em centavos |
| `categories` | Array JSON de `{ category, total_amount, percentage }`; centavos textuais e percentual numérico com duas casas |

Categorias são ordenadas por total decrescente, com desempate por categoria.
As somas usam INTEGER de 64 bits do SQLite; overflow deve falhar, nunca retornar
dinheiro em ponto flutuante. Percentuais usam ponto flutuante somente por serem
proporções, não dinheiro. Arredondamentos individuais podem somar 99,99% ou 100,01%.
`category` vazio permanece vazio; não é reclassificado como `other`. Despesas sem
`occurred_on` não pertencem a nenhum mês. Não há alteração ou migração dos records.

Consulta do cliente: `GET /api/collections/metrics/records` com
`filter=start_date = "2026-10-01"`, `page=1`, `perPage=2` e `skipTotal=true`.
O segundo item serve para detectar violação da unicidade esperada, não para paginar
despesas. O servidor filtra propriedade; o Flutter não envia um owner arbitrário.
Lista `items: []` representa mês sem despesas e é convertida em zero no adapter.
Erros HTTP, envelope inválido, múltiplos records ou período incorreto falham.

O contrato do repository Flutter admite apenas meses completos. Ambas as datas
ausentes selecionam o mês atual; intervalo incompleto, parcial ou de vários meses
é rejeitado sem request. Não há fallback para `metrics/expenses`. A view reflete
CRUD subsequente nas novas consultas, mas não publica eventos realtime próprios.

A view é criada diretamente na inicial transacional consolidada, somente em banco
novo. Não iniciar serviço, reaplicar bootstrap, resetar volume ou executar deploy
sem autorização operacional.
Até essa aplicação e homologação reais, não afirmar que a view está implantada
ou que o isolamento entre contas foi comprovado em runtime.

## Verificação

Os alvos `make test`, `make test-race`, `make vet` e `make bruno-check` executam
verificações locais. `make check` agrega esses comandos, sintaxe shell,
`shellcheck -e SC1090` dos helpers (o source privado é dinâmico) e whitespace.
CLI Bruno 4+, Node.js e ShellCheck são ferramentas de desenvolvimento necessárias
para esse agregado, não dependências do servidor. `make test-bruno` habilita o
E2E local com a CLI instalada; não executa contra development persistente ou production.

Sem serviços, rede, downloads nem leitura de segredos:

```sh
sh -n docker/entrypoint.sh
git diff --check
```

O backend mantém testes Go locais descritos em **Executável Go Local**. Eles
validam a migration atual em banco novo, preservação após reinício, confirmação de
e-mail com transporte simulado, autenticação, rota protegida, CRUD e isolamento de
despesas/métricas. Não validam SMTP real, interface do painel, realtime, containers
ou integração Flutter. Não há ferramentas Python. As verificações shell acima
cobrem somente sintaxe e whitespace; não substituem os testes Go. Execução de
containers e homologação operacional exigem autorização própria.

**Bruno reduzido a login/upload locais (09/11/2026):** parser e oito testes
offline aprovados em `make bruno-check`; `make test-bruno` aprovado com exatamente
duas requests e usuário/banco/arquivo temporários. O login também foi executado
pela própria CLI com o ambiente privado development e retornou 200 no servidor
local. Não há teste visual do desktop ou upload de gravação real homologado.
Regras e testes Go das APIs permanecem; nenhum deploy ou mudança remota.

**Validação após organização do backend (09/11/2026):** `go test -count=1 ./...`,
`go test -race ./...`, `go vet ./...`, `sh -n docker/entrypoint.sh` e
`git diff --check` aprovados. O E2E também passou no novo caminho:
`CORDATO_HTTP_SMOKE=1 go test -count=1 -run '^TestLocalServerLifecycle$' -v ./tests/e2e/server`.
A composição foi movida para `internal/bootstrap/`, integração/E2E foram isolados
em `tests/` e apenas a saúde customizada da POC foi removida. As verificações de
segurança, APIs nativas, propriedade, migrations e áudio permanecem cobertas;
a ausência da rota antiga agora é testada. Sem bloqueios, mudanças Flutter,
migrations/runtime Docker, SMTP/IA reais ou deploy.

**Validação da entrada de áudio (09/11/2026, anterior à reorganização):** `go test -count=1 ./...`,
`go test -race ./...`, `go vet ./...`, `sh -n docker/entrypoint.sh` e
`git diff --check` aprovados. O smoke
`CORDATO_HTTP_SMOKE=1 go test -count=1 -run '^TestLocalServerLifecycle$' -v ./internal/compatibility`
também passou, incluindo aceite `202`, rejeição sem token e rejeição de MIME por
HTTP real no executável temporário. A suíte padrão não abriu portas; somente o
smoke usou loopback e bancos descartáveis, encerrando os processos por SIGTERM.
Sem bloqueios encontrados, SMTP/IA reais, integração Flutter, alteração de
migrations/runtime Docker ou deploy. O race detector cobre o processo de testes;
o binário filho do smoke usa build normal. Essa evidência não comprova mídia válida,
processamento futuro, TLS/Traefik ou disponibilidade remota da rota.

**Validação local do executável Go (09/11/2026, macOS ARM64, Go 1.27.3):**
`go test ./...`, `go test -race ./...`, `go vet ./...`,
`go build -o .temp/cordato-server ./cmd/cordato`, `sh -n docker/entrypoint.sh` e
`git diff --check` aprovados. Ajuda e versão são exercitadas sem chave ou banco;
os testes também verificam rejeição de chave inválida antes de criar o banco e
ausência de geração automática de migrations pelo painel. Não houve servidor
escutando portas, SMTP real, build/container, alteração de dados existentes,
execução Flutter ou deploy. Os testes reproduzem a montagem HTTP em memória;
não comprovam o ciclo completo do servidor TCP, proxy ou TLS.

**Validação HTTP real posterior (09/11/2026):** o comando opcional com
`CORDATO_HTTP_SMOKE=1` passou em macOS ARM64, incluindo inicialização pelo executável,
três ciclos de servidor, login, CRUD isolado e encerramento limpo por `SIGTERM`.
O banco e o executável foram temporários; a migration não foi reaplicada nos
reinícios. Isso cobre TCP local, não TLS/Traefik, SMTP real, interface visual,
realtime, integração Flutter ou deploy. Nenhum arquivo do runtime Docker foi alterado.
Após adicionar o teste opcional, `go test -count=1 ./...`,
`CORDATO_HTTP_SMOKE=1 go test -race -count=1 ./...`, `go vet ./...`,
`sh -n docker/entrypoint.sh` e `git diff --check` também passaram. O race detector
instrumenta o processo dos testes; o executável filho deste teste usa build normal.

Na integração da view mensal, `sh -n docker/entrypoint.sh` e `git diff --check`
passaram. A SQL foi preparada por `EXPLAIN QUERY PLAN` no SQLite do sistema,
contra uma tabela vazia em memória com as colunas necessárias, sem acessar dados
da aplicação. Isso verifica a preparação da consulta, não a execução da migration,
inferência dos campos pelo PocketBase, totais com dados reais ou isolamento entre
contas. Nenhum serviço, container ou binário PocketBase foi iniciado nesta etapa.

### Evidências históricas

Consolidação das migrations (03/11/2026): `sh -n docker/entrypoint.sh`,
`node --check pb_migrations/1793491200_initial.js` e `git diff --check` aprovados.
Não houve execução do PocketBase, build, reset de VPS/volume ou deploy.
A sintaxe JavaScript não comprova a aplicação da migration em runtime.

Os registros abaixo são anteriores à remoção da suíte e às alterações atuais de
identidade dos e-mails. Não comprovam validação da imagem ou dos templates atuais.

**Evidências locais (01/11/2026):** build Linux ARM64 aprovado no Podman, SHA-256 do ZIP oficial conferido e saída `pocketbase version 0.41.1` validada. Imagem final `8378990f13b1eb70773dca966736900d36579ec279add5e47bdaf5a1913abfab`: **41.583.014 bytes (~39,66 MiB)** descompactada, binário ~30,4 MiB, usuário `10001:10001`. Sem curl, unzip ou tzdata no runtime; UTC não exige pacote de fusos. Cinco testes rápidos, quatro nativos e oito HTTP aprovados. O único ajuste necessário nos testes nativos foi recarregar o cache de settings entre migrations antes de conferir o bootstrap.

O ZIP Darwin 0.41.1 em Downloads confere com o checksum oficial, mas o executável local encerrou com `SIGKILL` e não estava mais disponível no caminho após a tentativa; por isso a validação foi feita com o **binário Linux dentro de containers**, não alterando proteções do macOS nem copiando executáveis para o Git. Docker não está instalado; build e runtime foram verificados com Podman, não com Docker Compose ou Dokploy. A arquitetura da VPS ainda deve ser conferida antes do rollout; amd64 e arm/v7 estão configuradas com checksums próprios, mas não foram executadas nesta rodada.

Ainda faltam validação no Dokploy/Traefik/HTTPS, entrega real Resend/OTP, homologação Flutter, medição de desempenho/carga, cópia externa e restauração de backup e deploy. A imagem é enxuta e a versão é travada; isso **não** equivale a otimização de performance medida nem reprodução byte a byte dos pacotes APK obtidos durante builds futuros. Atualizar a versão PocketBase exige revisar URL, checksums e verificação explícita da versão; não há `latest` nem fallback silencioso.

Referências: [migrations](https://pocketbase.io/docs/js-migrations/), [regras](https://pocketbase.io/docs/api-rules-and-filters/), [produção e criptografia](https://pocketbase.io/docs/going-to-production/), [checksums oficiais 0.41.1](https://ganigeorgiev.com/meta/pocketbase/pocketbase/download/v0.41.1/checksums.txt).

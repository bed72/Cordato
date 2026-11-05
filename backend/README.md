# Cordato — PocketBase

Serviço independente **PocketBase 0.41.1** para contas, despesas pessoais e métricas mensais, preparado para Docker Compose no Dokploy. Sem Node, hooks, worker, IA ou Batch API.

O backend vive em `backend/` no repositório do aplicativo Flutter, mas tem build, serviço e volume próprios. Execute os comandos deste documento **a partir de `backend/`**. A transferência dos arquivos não integra nem migra o cliente Flutter para a API PocketBase.

## Escopo E Fontes De Verdade

Este documento descreve o serviço existente, sua operação e limites de validação.
As camadas do aplicativo e as diferenças de integração estão em
[ARCHITECTURE.md](../ARCHITECTURE.md#backend-pocketbase-e-limite-de-integração);
o panorama do produto está no [README da raiz](../README.md). As orientações
específicas de manutenção ficam em [AGENTS.md](AGENTS.md).

- **Implementado na configuração:** contas individuais e despesas próprias,
  autenticação/verificação nativas, regras de propriedade e cascata, além da view
  somente leitura `metrics` com agregações por proprietário/mês.
- **Ausente nesta configuração:** agregações por intervalos arbitrários, insights, endpoints
  customizados de sugestões, orçamentos e família. O Flutter obtém sugestões por
  GET filtrado do histórico pessoal, sem recurso adicional no servidor.
- **Cliente Flutter:** Authentication, Session, User, Expense e Metrics usam APIs nativas.
  Expense envia `owner` na criação, categoria `other` e a data civil codificada
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

Os exemplos Dart abaixo ilustram chamadas pelo SDK PocketBase, não integrado ao
aplicativo, que utiliza `IHttpClient` diretamente. As evidências locais ao
final são registros anteriores, não verificações executadas nesta revisão.

## Arquivos

- `compose.yml`: um serviço `pocketbase`, volume persistente e rede externa `dokploy-network`.
- `Dockerfile`: base Alpine fixada por digest e binário oficial Linux verificado por SHA-256, com suporte amd64, arm64 e arm/v7; execução sem root. Atualizações da base exigem revisão do digest.
- `docker/entrypoint.sh`: exige chave de criptografia de 32 bytes, fixa opções seguras e inicia o serviço.
- `pb_migrations/1793491200_initial.js`: única migration transacional, **exclusiva para banco novo**. Consolida schema, permissões, superusuário, settings, view `metrics` e links de verificação e recuperação de `users` para o app. Templates administrativos permanecem nativos. As quatro migrations incrementais foram incorporadas e removidas; esta revisão não atualiza bancos existentes.
- `.env.example`: nomes das variáveis, sem segredos.

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

Sem serviços, rede, downloads nem leitura de segredos:

```sh
sh -n docker/entrypoint.sh
git diff --check
```

O backend não mantém suíte de testes automatizados nem ferramentas Python por
decisão do projeto. As verificações acima cobrem somente sintaxe shell e problemas
de whitespace; não validam migrations, regras de acesso, HTML dos e-mails ou runtime.
Build, execução de containers e homologação operacional exigem autorização própria.

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

# Worker Node-RED

Infraestrutura independente do Flutter e do PocketBase, preparada para Docker Compose
local e Dokploy. Imagem oficial **Node-RED 5.0.9 / Node.js 24**, fixada por tag e
digest no Dockerfile. Sem bibliotecas npm adicionais.

Versão estável mais recente conferida no npm e Docker Hub em 10/11/2026. A imagem
selecionada contém Node.js 24.22.2, compatível com o mínimo 22.9 exigido pelo
Node-RED 5. O manifesto oficial oferece Linux amd64 e arm64, sem suporte arm/v7.

O flow [Áudio → Despesa](flows/audio/README.md) recebe uma despesa por áudio,
valida a sessão e usa IA por Chat Completions + API nativa PocketBase, com logs somente
de metadados. O padrão é OpenRouter com `google/gemini-3.8-flash`.
Responde `202` após validar upload/sessão e continua em memória, sem fila persistente.
Flutter possui envio, sem polling ou atualização automática; ainda sem homologação remota.
Recusas da IA recebem diagnóstico por códigos locais sanitizados no log seguro,
sem registrar corpo remoto, áudio ou credenciais; consulte o README do flow.
`worker/flows.json` começa vazio: o flow de áudio exige importação manual.
A lógica fica nos nós Function do JSON; editar/importar e usar Deploy basta para
mudar timeout, payload ou validação. Rebuild é somente para infraestrutura/dependências.

## Estrutura

- `Dockerfile`: imagem e configuração versionada fora do volume.
- `compose.yml`: serviço, ambiente obrigatório, volume e proteções comuns.
- `compose.local.yml`: porta publicada somente em `127.0.0.1`.
- `compose.dokploy.yml`: rede externa `dokploy-network`, sem publicar porta no host.
- `settings.js`: autenticação, criptografia e configuração do runtime.
- `middleware/audio_upload_gate.js`: proteção pré-parser, correlação e admissão de upload.
- `flows.json`: flows revisados, usados como base na primeira inicialização.
- `flows/audio/`: export importável, implementação JavaScript e contrato do áudio.
- `docker/entrypoint.sh`: valida configuração e semeia flows somente quando ausentes.

## Ambiente e credenciais

Execute os comandos desta pasta. Copie o exemplo e preencha localmente:

```sh
cp .env.example .env
```

| Variável | Valor |
| --- | --- |
| `NODE_RED_ADMIN_USERNAME` | Usuário administrativo escolhido por você. |
| `NODE_RED_ADMIN_PASSWORD_HASH` | Hash bcrypt da senha, nunca texto puro. |
| `NODE_RED_CREDENTIAL_SECRET` | Chave aleatória estável com pelo menos 32 caracteres. |
| `POCKETBASE_URL` | Raiz HTTPS do PocketBase, padrão `https://pocketbase.cordato.cloud`. |
| `AI_BASE_URL` | Base HTTPS Chat Completions, padrão `https://openrouter.ai/api/v1`, sem `/chat/completions`. |
| `AI_MODEL` | Identificador do modelo, padrão `google/gemini-3.8-flash`; deve aceitar M4A, schema JSON e reasoning low. |
| `AI_API_KEY` | Chave privada do endpoint de IA, obrigatória para áudio, não para abrir o painel. |

Para gerar o hash com a ferramenta oficial, o comando abaixo baixa a imagem e
executa um container temporário interativo, sem iniciar o serviço. Digite a senha
no prompt, não na linha de comando:

```sh
docker run --rm -it --entrypoint node-red nodered/node-red:5.0.9-24 admin hash-pw
```

No `.env` do Compose, envolva o hash em **aspas simples** para preservar `$`,
como `NODE_RED_ADMIN_PASSWORD_HASH='hash-gerado-no-prompt'`. Esse texto ilustrativo
não é um hash válido. No Dokploy, configure o valor literal no gerenciador de
variáveis e confira como a plataforma trata `$`; não coloque o hash no YAML.
Não compartilhe saídas de `docker compose config` com valores resolvidos.

Gere a chave em ambiente privado, por exemplo com `openssl rand -hex 32`, e salve
no gerenciador de segredos. Preserve a mesma chave em reinícios, rebuilds e
restaurações: sua perda/troca impede recuperar credenciais criptografadas existentes.
O startup recusa configuração ausente ou malformada, sem senha/chave padrão.
A validação do hash verifica sintaxe, não a força da senha escolhida.

O JWT do usuário chega somente na requisição e não é configurado no ambiente.
Não há credencial administrativa PocketBase. A IA recebe somente sua própria chave;
PocketBase recebe somente o token do usuário. Nunca conecte Debug à mensagem completa.
`.env`, dados e backups ficam fora do Git e do contexto de build.

Substitua `GEMINI_MODEL`/`GEMINI_API_KEY` pelas três variáveis `AI_*`; não há leitura
ou migração automática das chaves antigas. Use um endpoint confiável: ele recebe
o áudio e a chave configurada. O formato é Chat Completions, não a API Interactions
do Gemini. Para OpenRouter, configure créditos/permissões e privacidade na conta.
`AI_API_KEY` deve ser uma chave OpenRouter, não a antiga chave Google.
O flow desabilita fallback de provedor e filtra coleta de dados, sem prometer retenção zero.

O Compose encaminha explicitamente `AI_*` ao serviço. Alterar essas variáveis exige
recriar o container com o Compose atualizado e preservar `/data`, não rebuild da imagem.
Uma instância antiga que encaminha só `GEMINI_*` não passa as novas variáveis apenas
por adicioná-las ao ambiente de interpolação do Dokploy. A lógica do flow continua
sendo publicada separadamente por importação e Deploy no editor.

## Execução local

Após preencher `.env`, os comandos abaixo constroem e iniciam a infraestrutura:

```sh
docker compose -f compose.yml -f compose.local.yml config --quiet
docker compose -f compose.yml -f compose.local.yml up -d --build
```

Abra **http://127.0.0.1:1880/admin/** e use o usuário e a senha escolhidos.
O HTTP local fica restrito ao loopback; não publique essa porta na rede.
Para parar preservando os dados:

```sh
docker compose -f compose.yml -f compose.local.yml down
```

Não use `down -v` para manutenção: esse comando remove o volume persistente.

## Dokploy

Domínio reservado: **`worker.cordato.cloud`**, com CNAME na Hostinger para
`dokploy.cordato.cloud` e TTL de 300 segundos. O DNS aponta para o servidor,
mas não cria o serviço, o roteamento ou o certificado no Dokploy. Após configurar
e publicar o serviço, o editor será acessível em
**https://worker.cordato.cloud/admin/**.

1. Crie um serviço Compose com contexto de build em `worker/`.
2. Configure a composição equivalente a
   `docker compose -f compose.yml -f compose.dokploy.yml`. Se os caminhos partirem
   da raiz do repositório, use os dois com prefixo `worker/`; o contexto de build
   deve continuar sendo `worker/`.
3. Defina as variáveis administrativas e, para áudio, as variáveis Gemini/PocketBase
   no ambiente privado do Dokploy, conforme [configuração do áudio](flows/audio/README.md).
4. Confirme a rede externa `dokploy-network` e preserve o identificador do
   projeto/volume entre implantações; trocar o projeto pode selecionar outro volume.
5. Configure `worker.cordato.cloud` para o serviço **`node-red`**, porta interna
   **1880**, caminho **`/`**, sem remover prefixos. O editor usa `/admin/`.
6. Habilite HTTPS e redirecionamento HTTP → HTTPS no proxy, com suporte a WebSocket.
   TLS termina no proxy, não no Node-RED.
7. Após deploy autorizado, confira login obrigatório, rejeição de senha incorreta,
   HTTPS e preservação de flows após recriar o container.

Não use o override local no servidor. O proxy acessa o serviço pela rede interna,
sem publicação de 1880 no host. Restrinja também acesso ao Dokploy e ao Docker.
O editor permite executar lógica no servidor: somente administradores confiáveis
devem possuir acesso.

O healthcheck consulta a página do editor sem credenciais: comprova somente HTTP,
não autenticação, HTTPS ou integrações. Tokens administrativos expiram em 12 horas;
troca de senha não é garantia de revogação imediata dos tokens já emitidos.

## Flows no Git e persistência

Os flows importáveis ficam separados por funcionalidade em `flows/<nome>/`, cada
um com `flows.json` completo e README próprio. O flow disponível é
[Áudio → Despesa](flows/audio/README.md), com código completo nos próprios nós
Function, sem helper global ou lógica de processamento na imagem. Esses arquivos
não são carregados automaticamente. Hello World foi removido do Git; exclua sua aba
manualmente na instância remota se ela ainda existir.

O `worker/flows.json` da raiz continua sendo somente a base inicial do container,
vazia nesta etapa; não é um agregado automático das funcionalidades.

O volume `node_red_data`, montado em `/data`, contém flows ativos, credenciais
criptografadas e estado interno. A configuração de segurança vem da imagem em
`/opt/cordato/settings.js`, não de um arquivo antigo no volume.

A imagem copia os flows versionados somente quando `/data/flows.json` não existe.
**Rebuild não substitui flows existentes.** Para versionar mudanças do painel:

1. Use Export → current flow → JSON formatado para exportar somente a aba da funcionalidade.
2. Revise para remover segredos, tokens, dados pessoais e payloads reais.
3. Salve em `worker/flows/<nome>/flows.json` e revise o diff no Git.

Para aplicar uma versão do Git em uma instância com volume existente:

1. Exporte uma cópia privada dos flows atuais.
2. Importe o JSON revisado e substitua explicitamente os flows antigos, evitando
   duplicar nós/IDs. Confira as alterações antes de usar Deploy no editor.
3. Reconfigure credenciais privadas quando necessário e valide o comportamento.

Deploy no editor publica flows, não infraestrutura. Não há sincronização automática
entre painel e Git. Faça backup privado de `/data` com o serviço parado e guarde
a chave separadamente. Não versione `flows_cred.json`, volume ou backups.
A restauração exige a mesma chave e conferência dos flows.

Na migração do áudio antigo, importe e publique primeiro a aba autônoma. Ela é
compatível com a admissão da imagem atual e dispensa rebuild. Atualizar a imagem
posteriormente remove o helper global legado; essa imagem não executa flows antigos
que ainda dependam dele. Alterar infraestrutura, bibliotecas ou segurança continua
exigindo atualização da imagem, sem sobrescrever `/data`.

Instalações pela paleta, módulos externos de Function e Projects estão desabilitados.
Dependências futuras devem ser explícitas e fixadas na imagem. Contexto de Function
é em memória por padrão; o volume não o transforma em fila durável. Não registre
áudio, transcrições ou credenciais em nós Debug/logs.

## Verificação

O primeiro deploy no Dokploy falhou antes de iniciar o Node-RED com
`exec /opt/cordato/entrypoint.sh failed: Permission denied`. O Dockerfile agora
define explicitamente permissão de travessia em `/opt` e `/opt/cordato`, execução
do entrypoint e verificações de acesso no build como `node-red`. Root é usado
somente na construção da imagem; o runtime continua sem privilégios. Após a correção,
o usuário confirmou acesso ao painel e execução manual do Hello World. Isso não
comprova homologação do flow de áudio. Na organização atual, a imagem fornece
somente infraestrutura; mudanças de lógica são aplicadas por importação/Deploy.

Sem iniciar infraestrutura ou instalar dependências:

```sh
node --check settings.js
node --check middleware/audio_upload_gate.js
node --test test/*.test.js
sh -n docker/entrypoint.sh
shellcheck docker/entrypoint.sh
git diff --check
```

Registro da infraestrutura inicial: **11 testes aprovados**, sintaxe JavaScript e
shell válidas, ShellCheck e `git diff --check` sem problemas; `flows.json` também
foi validado como JSON vazio. Testes cobrem configuração pura e recusa de variáveis
ausentes/inválidas, sem UI, rede ou segredos reais.

Na configuração genérica de IA/OpenRouter (11/11/2026), os 192 testes locais passaram,
incluindo funções compiladas do JSON real, sandbox sem módulo da imagem, edição de
timeout somente no flow, URL/modelo/chave configuráveis, Chat Completions, respostas
incompletas, configuração, admissão e logs seguros. Sintaxe JavaScript,
shell, ShellCheck e diff também foram verificados. Sem Docker disponível, os pares
Compose e a imagem não foram revalidados; sem build, container, deploy ou chamadas
remotas. Isso não comprova homologação de áudio/OpenRouter/PocketBase. Nenhum arquivo do
aplicativo foi alterado nesta mudança; a suíte Flutter não foi executada.

Referências: [Docker oficial](https://nodered.org/docs/getting-started/docker),
[segurança](https://nodered.org/docs/user-guide/runtime/securing-node-red) e
[configuração](https://nodered.org/docs/user-guide/runtime/configuration).

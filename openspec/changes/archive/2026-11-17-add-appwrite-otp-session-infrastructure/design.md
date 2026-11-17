# Design

## Context

Veja proposal.md para a motivação. Não há repositories ou bindings PocketBase.
Por correção explícita do usuário, o transporte segue o histórico 019734f:
IHttpClient/HttpClient, Requests, Responses e exceções próprias, sem Either ou
PocketBase. IHttpClient, Dio e PersistCookieJar são lazy singletons no core sem
path. A composição configura Dio e o injeta obrigatoriamente em HttpClient.new;
não há create ou Dio opcional no client. Os consumidores usam somente IHttpClient.
ResponseMapper preserva status/type Appwrite sem conteúdo remoto.

O contrato antigo exigia senha, cadastro, recuperação e verificação por link. Por correção explícita do usuário na step 1, ele foi removido e substituído pelo único `IAuthenticationRepository` descrito abaixo. Os consumidores visuais antigos não foram migrados nesta etapa e permanecem incompatíveis com os métodos removidos.

## Goals / Non-Goals

**Goals:** fornecer uma fronteira OTP utilizável por futuros consumidores, implementar `ISessionRepository` e estabelecer efeitos de cookie/sessão testáveis sem UI.

**Non-Goals:** alterar apresentação, navegação ou Settings; implementar cooldown visual; remover arquivos de senha ainda consumidos; entregar um app integralmente funcional; migrar outros adapters ou serviços.

## Decisions

### 1. Contrato único de autenticação

Substituir o contrato anterior por `IAuthenticationRepository` em application de Authentication com `requestCode(email:)`, `confirmCode(userId:, code:)` e `signOut()`. A solicitação retorna `Future<String>` com o `userId`, sem entidade wrapper; confirmação e logout retornam `Future<void>`. Não retornar o secret do serviço nem cookies. A infraestrutura não normaliza e-mail ou código: isso pertence ao futuro formulário. Nomes públicos de autenticação não especificam OTP.

Não preservar interface antiga, contrato paralelo ou interface Legacy. Não criar métodos de senha que lançam `UnimplementedError`, retornam sucesso ou simulam ausência de sessão. Os erros de compilação dos consumidores antigos devem ser registrados até sua migração/remoção em tarefa própria, sem apagar cobertura nem conectar o fluxo de senha ao novo contrato artificialmente.

Manter `ISessionRepository.loadSession()` e `sessionChanges`, compatíveis com a apresentação existente, sem editar o SessionBloc. Usar `AuthenticationException` e `SessionException` para falhas remotas esperadas, preservando `ErrorsEntity`. Falhas de storage e de programação permanecem observáveis, não mascaradas como erro de credenciais.

### 2. REST pelo transporte existente

Solicitar código com `POST account/tokens/email`, corpo `userId: unique()` e `email`, conforme o contrato da versão instalada; `unique()` é o sentinela REST, não uma dependência do SDK. Reenvio é uma nova chamada explícita, com retorno do novo desafio. Não inferir se a conta já existia. Não pedir security phrase nesta primeira versão.

Confirmar com POST account/sessions/token, corpo userId e secret recebido de code.
Após cookies processados, consultar GET account antes de publicar autenticação.
Usar sucesso HTTP 2xx do HttpClient, sem parsing de campos da conta nem status
específicos. O envelope segue Responses: objeto JSON ou corpo vazio; outros
corpos de sucesso falham visivelmente. Restauração usa o mesmo GET. Logout exclui
somente account/sessions/current.

Os caminhos devem compor `/v1/account/...` preservando o prefixo do endpoint mesmo sem barra final. Verificar a resolução de URI do Dio em testes, em vez de assumir que a concatenação é correta. Confirmar status, payloads e cookies com documentação compatível com a versão instalada antes de fixar fixtures. Acesso remoto de escrita, disparo de e-mail ou alteração de configuração não fazem parte desta criação de spec nem são necessários para testes automatizados.

#### Referência REST verificada para a step 1

Em 17/11/2026, a consulta pública somente leitura
`GET https://console.cordato.cloud/v1/health/version` retornou
`{"version":"2.7.2"}`. A [referência Client REST Account](https://appwrite.io/docs/references/cloud/client-rest/account)
consultada apresenta exemplos com `X-Appwrite-Response-Format: 2.7.2`, compatíveis
com essa versão. As operações e schemas constam também nos dados OpenAPI
incorporados nessa página. Não foi adicionado esse header ao transporte nesta
etapa; nenhuma fixture de repository foi criada ainda.

| Operação | Request JSON | Sucesso documentado | Projeção a consumir |
| --- | --- | --- | --- |
| `POST /v1/account/tokens/email` | `userId: "unique()"`, `email` original; `phrase` omitido (default false) | 201, JSON Token | `userId` String não vazio para o desafio |
| `POST /v1/account/sessions/token` | `userId` original, `secret` com o `code` original | 201, JSON Session | Nenhum DTO público; aguardar cookies e consultar conta |
| `GET /v1/account` | Sem corpo | 200, JSON User | Corpo ignorado; sucesso HTTP confirma sessão |
| `DELETE /v1/account/sessions/current` | Sem corpo | 204, sem conteúdo | Nenhuma resposta pública |

O Token documentado contém `$id`, `$createdAt`, `userId`, `secret`, `expire` e
`phrase`; `secret` é vazio em chamadas de cliente sem API key e não deve ser usado
como código retornado. O código vem do e-mail e vale 15 minutos segundo a
referência. Para e-mail existente, o serviço ignora o ID enviado e retorna o ID
da conta; para novo e-mail, cria a conta. A aplicação sempre utiliza o `userId`
retornado, sem inferir existência anterior. A referência limita emissão a 10
requests/hora por e-mail/projeto/URL e por IP/URL, e confirmação a 10/hora por
usuário/projeto/URL e por IP/usuário/URL; 429 é falha esperada, não gatilho de retry.

A [documentação REST](https://appwrite.io/docs/apis/rest#client-integration)
confirma persistência por `Set-Cookie` e envio de `Cookie` em consultas seguintes,
com exemplos `a_session_<projectId>` e `a_session_<projectId>_legacy`, atributos
de domínio/path, expiração, Secure e HttpOnly. A mesma documentação define o
sentinela REST `"unique()"` sem SDK. O jar existente deve respeitar os atributos
efetivamente recebidos; não criar credencial a partir do corpo Session nem
fallback bearer/`X-Fallback-Cookies`. A expiração segue o Set-Cookie do servidor,
sem limpeza manual de cookies pelo client de sessão.

Os tratamentos de 401 como ausência e de falhas de cookies são políticas locais
das decisões 4 e 5, não garantias de que toda falha remota revogou ou preservou
sessão. Não houve POST, DELETE, envio de e-mail ou mudança de configuração remota.
A conferência documental não homologa SMTP, atributos reais de cookies ou o fluxo
autenticado da instância; isso continua sendo verificação separada.

### 3. Coordenação compartilhada específica de sessão

ISessionClient é um contrato puro em core/application/clients, implementado por
SessionClient e registrado no core como lazy singleton. Consumidores dependem
da interface, sem importar a implementação concreta.
O stream é ISessionClient.session. SessionRepository o repassa como
ISessionRepository.sessionChanges, sem alterar o contrato usado pelo Bloc.
SessionClient recebe somente IHttpClient e usa Requests/Responses e
HttpResponseException, sem Dio. Publica booleanos em stream broadcast sem replay.
Cookies ficam com o transporte existente, sem SDK, AuthStore ou persistência
paralela. AuthenticationRepository usa a mesma fronteira. SessionRepository delega
loadSession e converte HttpClientException por ResponseMapper para SessionException,
sem fechar o client ou o stream compartilhado. Ambos têm bindings lazy singleton
nos módulos existentes sem path.

Authentication solicita o código por IHttpClient e delega confirmação/logout à
coordenação; Session delega restauração/observação. Tipos Dio ficam somente em
core/infrastructure/clients/http e na composição core_module.dart. Não há import entre Authentication e Session,
interpretação de campos da conta, perfil ou entidade adicional.

`AuthenticationRepository` recebe IHttpClient e ISessionClient. A solicitação usa POST
com `userId: unique()` e e-mail original, lê somente `userId` como String não
vazio e retorna esse valor sem wrapper. Confirmação e saída delegam à coordenação
existente. Os três métodos capturam somente HttpClientException e usam ResponseMapper;
não há helper genérico, data source ou validação da conta adicionada ao repository.

Alternativas rejeitadas: evento global vindo de interceptor HTTP, reuso de AuthStore removido ou importação de Session por Authentication. Todas ampliam acoplamento ou reintroduzem mecanismos abandonados.

### 4. Serialização dos efeitos, não apenas dos eventos

Uma fila simples ordena requests, processamento de Set-Cookie e publicação. Confirmação mantém POST e GET na mesma unidade. Logout aguarda operações anteriores, inclusive timeout. A fila continua após falhas, sem retries automáticos.

Por solicitação de simplificação, não há compartilhamento, cache ou deduplicação de restaurações: cada chamada é enfileirada e consulta a conta. Cancelar uma assinatura não cancela transporte nem fecha as demais. `close()` aguarda a fila e fecha apenas o stream.

Esta escolha evita que um simples contador descarte eventos mas deixe `CookieManager` persistir `Set-Cookie` obsoleto. O custo é um logout aguardar o timeout de uma operação anterior. Não usar flags de UI nem interceptors de autenticação para contornar a ordem.

### 5. Políticas de ausência, falha e logout

GET account com sucesso HTTP confirma sessão sem validar campos. Somente
HttpResponseException 401 confirma ausência; rede, 403, 5xx e erros locais não
publicam logout. Erros de cookies viram HttpUnexpectedException no transporte,
não HttpResponseException, e não são confundidos com ausência.

Mantida a simplificação: sem limpeza manual, tombstones ou desembrulhamento
nativo nos consumidores. HttpClient normaliza falhas para exceções próprias,
preservando Error/FormatException inesperados. ResponseMapper usa status/type de
HttpResponseException e fallback local para rede/erro local; envelope inválido
vira FormatException visível. Sem Set-Cookie de expiração, não se promete
exclusão local ou retry de persistência incompleta.

Política adotada como recomendação conservadora: falha remota de logout não inicia limpeza local nem publica saída. Isso não promete que um request com timeout não revogou a sessão no servidor. A resposta futura de restauração reconcilia a realidade. Um POST de confirmação aceito seguido de GET falho também é incerto: não publicar sucesso nem repetir POST automaticamente; permitir restauração explícita posterior.

### 6. Composição e transição sem UI

Registrar a capacidade compartilhada no core sem `path`, o contrato OTP no módulo existente de Authentication e `ISessionRepository` no módulo de Session. Não criar módulos dependencies/form/routes. Composição isolada deve comprovar que ambos compartilham transporte e coordenação sem visitar rotas.

Os binds de Authentication e Session estão presentes. Isso não entrega Settings
homologada nem um app completo funcional. Outras features seguem sem adapters.
A remoção do contrato antigo deixa consumidores de senha e seus testes incompatíveis
até migração própria. O teste de resolução real de Authentication existe, mas sua
execução é bloqueada pelos imports desses Blocs no módulo; Session e core são testados
isoladamente com transporte fake. Composição com mocks não comprova integração remota.

## Risks / Trade-offs

- [Contrato OTP/versionamento self-hosted] → verificar referência da versão instalada e registrar fixtures/status usados; homologação remota separada.
- [Cookies recebidos antes de uma falha] → testar efeitos reais do CookieManager e reconciliação; não prometer rollback de requisições remotas.
- [Fila aguarda rede] → manter timeouts existentes e testes determinísticos com Completer; documentar que não há cancelamento remoto.
- [Arquivos sem criptografia adicional] → decisão vigente preservada; não adicionar Secure Storage nesta mudança.
- [Consumidores de senha incompatíveis] → registrar bloqueios de compilação após remoção explícita do contrato antigo, sem restaurar métodos nem criar interface paralela.
- [UI ainda oferece senha] → registrar limitação em README/arquitetura, sem conectar botões antigos ao fluxo novo.

## Migration Plan

Implementar por contratos, coordenação, repositories e DI, verificando cada camada sem UI. Atualizar documentação somente para refletir o que foi implementado, sem declarar migração visual ou homologação. Não há deploy ou migração de dados. Se a infraestrutura precisar ser retirada, remover apenas os novos bindings e adapters; não restaurar backend antigo nem descartar alterações de terceiros.

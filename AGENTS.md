# AGENTS.md

## Migração Appwrite: Remoção Completa Do Client Anterior

Por correção explícita do usuário, o transporte segue o client do histórico
`019734f`: `IHttpClient`/`HttpClient`, `Requests`, `Responses` e exceções HTTP
próprias, sem Either, PocketBase ou envelope de erros JSON:API. Dio fica privado
em HttpClient. Core configura e registra Dio com CookieManager/jar e restrição
de origem, e injeta essa instância obrigatória em IHttpClient por HttpClient.new.
Não há create, Dio opcional ou criação de transporte dentro de HttpClient.
SessionClient e repositories não importam Dio nem capturam DioException.
Esta decisão substitui as instruções
anteriores de consumir Dio diretamente ou não restaurar a fronteira HTTP própria.

Por solicitação explícita posterior, `IAuthenticationRepository` agora contém
somente `requestCode(email:)`, `confirmCode(userId:, code:)` e `signOut()`.
O contrato antigo de senha/cadastro/recuperação/verificação foi removido, sem
interface paralela ou contrato legado. Os nomes públicos não usam `Otp`:
`requestCode` retorna `Future<String>` com o userId, sem entidade wrapper. Consumidores antigos ainda
não migrados apresentam incompatibilidades de compilação; não restaure métodos
removidos, crie stubs ou apague testes para mascará-las. Esta decisão prevalece
sobre as referências à preservação do contrato antigo abaixo.

A única coordenação de sessão é `SessionClient` em
`core/infrastructure/clients/session/`, recebendo somente IHttpClient.
Por solicitação explícita de simplificação, usa o sucesso HTTP de `/account`,
sem parsing ou validação própria da conta. Uma fila simples ordena cada chamada,
sem cache/compartilhamento de restaurações, retries ou implementação paralela.
Cookies e suas falhas seguem o transporte existente: não há limpeza
manual ou tombstones. Somente HttpResponseException 401 de conta ou
logout confirma ausência, mas não promete remoção local sem Set-Cookie remoto.
Falhas de transporte/storage não são convertidas em ausência.
ISessionClient é o contrato puro em core/application/clients/interface_session_client.dart.
SessionClient implementa esse contrato e o core o registra como lazy singleton.
Expõe `session` (Stream<bool>), `loadSession`, `confirmCode`, `signOut` e `close`.
O adapter SessionRepository expõe esse mesmo stream como `sessionChanges`,
preservando o contrato de aplicação existente sem depender da classe concreta.
AuthenticationRepository é o primeiro consumidor: recebe IHttpClient e ISessionClient,
solicita código por REST retornando userId como String e delega confirmação/logout.
Não há wrapper de desafio, métodos de senha, retry ou implementação paralela.
HttpClientException passa por ResponseMapper para AuthenticationException, sem conteúdo
remoto; parsing e erros inesperados não são convertidos em sucesso.
Os repositories têm bindings lazy singleton nos módulos existentes sem path. Consumidores
dependem de ISessionClient, não da implementação concreta em infrastructure.
Não restaure o refresh/AuthStore anterior nem conecte os consumidores de senha
artificialmente ao novo fluxo. Os contratos de Session e seu Bloc não mudaram.

Por solicitação posterior restrita a Blocs e testes, SignInBloc agora solicita
requestCode com evento contendo somente email e emite SignInSuccess(userId:).
Esse sucesso significa código solicitado, não sessão autenticada. ResendEmailBloc
também usa requestCode e emite o novo userId em cada sucesso. ResendEmailStartedEvent
sem parâmetros inicia somente o cooldown do código já solicitado, sem outro request;
submissões explícitas reenviam após o prazo e reiniciam os 60 segundos após sucesso.
ConfirmCodeBloc recebe userId/code somente no evento, aguarda confirmCode e não
armazena código nos estados. Os três usam droppable, erros originais e retry manual.
ConfirmCodeBloc ainda não tem bind ou tela; não conecte a navegação de senha a
esses estados incidentalmente. Telas, rotas, previews e os outros Blocs de senha
continuam pendentes e incompatíveis. SessionBloc e LogoutBloc não foram alterados
nessa etapa; os Blocs antigos ainda consumidos não foram apagados.

Para continuar esta migração, siga os contratos existentes: IHttpClient fica
junto de HttpClient no transporte histórico; ISessionClient fica em application
do core. A composição importa implementações e registra pelos contratos.
Não injete Dio ou SessionClient concreto nos repositories, crie wrappers extras
ou restaure variantes paralelas. AuthenticationRepository e SessionRepository estão
registrados pelos contratos nos respectivos módulos; as telas de senha
continuam incompatíveis e não devem ser atendidas por stubs.

Por solicitação explícita, PocketBase foi removido de todo o Flutter, não apenas
do core: repositories concretos, bindings, testes exclusivos, fixtures e mocks.
Não restaure o SDK, seus adapters, AuthStore ou testes de endpoints anteriores.
`flutter_secure_storage` também foi retirado, pois não tem mais consumidores.
Os serviços independentes em `backend/` e `worker/` e documentos arquivados não
foram alterados: são históricos/isolados, não dependências do Flutter atual.

O transporte preparatório Appwrite segue sem SDK:
HttpClient recebe Dio obrigatório por construtor e somente executa requests e
traduz respostas/falhas. Endpoint, projeto, timeouts e interceptors pertencem
à composição em core_module.dart, sem factory auxiliar, SDK Appwrite, wrapper
de CRUD, logger HTTP ou dependências do backend removido.
Esta é uma exceção localizada às referências abaixo sobre ausência de Dio.
`main.dart` obtém o diretório de suporte e chama
`appModule(directory: directory)`, sem criar módulo intermediário.
O módulo raiz registra o `Directory`. `lib/factory.dart`, o observer customizado
e Talker foram removidos, incluindo o teste exclusivo do observer; não os restaure.
O core é
`final coreModule = createModule(...)`, sem parâmetros e sem `path`, como os
demais módulos compartilhados. Não há inicialização, bind ou consumidor
PocketBase no Flutter atual. O Modular cria um
`PersistCookieJar`, um Dio e um IHttpClient por `addLazySingleton`, compartilhados no core sem
`path`, injetando o `Directory` nos cookies. Não há factories auxiliares nem
validação própria de endpoint/projeto.
`OriginInterceptor` restringe a origem. O client não acessa diretórios nem resolve
dependências globalmente; Authentication é seu primeiro consumidor em infrastructure.
Contratos, domínio, Blocs, telas, rotas, serialização pura e seus testes foram
preservados. Authentication e Session têm adapters de produção registrados nesta fase.
Os contratos de User, Expense, exportação de Expense, Metrics e áudio ainda não têm adapters.
Não crie implementações vazias, retornos de sucesso ou ausência de sessão
presumida para esconder essa lacuna. O app completo exige a migração desses
adapters e da composição: OTP existe em infraestrutura com bindings e nos Blocs,
sem telas migradas; métricas e envio de áudio Appwrite continuam ausentes.
Cookies são arquivos no diretório de suporte, sem criptografia adicional por
decisão explícita; melhorias de persistência segura ficam adiadas.
`ResponseMapper` usa exceções próprias e preserva status/type Appwrite sem
conteúdo remoto. Error/FormatException encapsulados por Dio propagam no
transporte; falhas de cookies viram HttpUnexpectedException, nunca 401 remoto.
Sucesso com corpo não vazio/não objeto gera HttpInvalidResponseException, que
o mapper mantém como FormatException visível, sem fingir autenticação.
Os testes do transporte usam Dio real com adapter fake e diretório temporário,
sem rede ou UI. Testes de composição, incluindo `test/app_module_test.dart`,
fornecem mocks dos contratos de aplicação, sem fixture/backend anterior.
Isso comprova composição e comportamento com contratos fornecidos, não uma
integração Appwrite funcional. Os testes de Session também usam o core real com
adapter HTTP fake; os do módulo Authentication continuam bloqueados pelos imports
dos Blocs de senha. Para substituir um repository já registrado em testes de
composição, use replaceInstance após bootstrap, sem duplicar o registro do contrato.
Não apague cobertura independente do backend.
Um teste de arquitetura bloqueia a reintrodução do SDK/adapters removidos em
`lib/`, `test/` e `pubspec.yaml`.

## Histórico: SDK PocketBase Removido

Esta seção e demais descrições específicas de PocketBase abaixo são históricas,
não requisitos para os adapters futuros. Os consumidores e bindings SDK foram
removidos por solicitação explícita. Em conflito, prevalece a seção Appwrite
acima; não restaure esse transporte nem suas garantias incidentalmente.

A infraestrutura HTTP própria foi removida por solicitação explícita.
Authentication, Session, User, Expense e Metrics já usam o SDK, com testes de
repositories e DI migrados. Dio e talker_dio_logger não são dependências do app.
A análise e a suíte Flutter globais estão limpas após adaptar os testes do core
à factory e ao observer atuais. Isso não comprova build nativo nem homologação remota e não autoriza
restaurar o client removido ou apagar/enfraquecer testes de comportamento.
Por solicitação explícita, testes exclusivos de HTTP/Dio e seus mocks/fakes também
foram removidos. A cobertura atual usa o SDK real com transporte mockado; não
restaure os testes da abstração removida nem suas garantias de persistência.

O bootstrap aguarda `createDependencies` de
`lib/factory.dart`, que aguarda `PocketBaseFactory.create`; esta cria o storage
antes de `runApp`. `createAppModule` e
`createCoreModule` recebem somente o PocketBase pronto; repositories de
infrastructure recebem diretamente o `PocketBase` compartilhado pela DI, sem
Future de inicialização. Falhas de leitura inicial propagam antes de montar o app,
sem ausência de sessão presumida, limpeza ou retry automático; SDK e
`RecordModel` não atravessam os contratos
de application nem chegam ao domínio ou à apresentação. Não crie wrapper de CRUD.
O transporte dos repositories existentes foi migrado para o SDK. `IHttpClient`,
`IStorageClient`, Requests, Responses, Dio e interceptors próprios não fazem parte
da infraestrutura disponível. Homologação remota é uma verificação separada.

`PocketBaseFactory.create` configura o `AsyncAuthStore` oficial com callbacks do
`FlutterSecureStorage` diretamente, sem `IStorageClient`, classe AuthStore própria
ou bind separado na DI. O storage não é exposto pelos módulos.
No SDK PocketBase 0.26, a factory desativa `autoClearAuthStore` pela API nativa
para preservar a política existente: expiração local e 401 de requests comuns
não limpam a sessão. Session continua limpando explicitamente em 401 de refresh.
Fixtures do SDK usam a mesma configuração, coberta por testes da factory com
transporte mockado e storage pelo canal simulado.
Expense não usa mais o storage legado. A única
chave nova é `@cordato.pocketbase_auth`; não há leitura, cópia ou migração das
chaves antigas. Sessões anteriores exigirão novo login.
Por simplificação explicitamente aprovada, o SDK atualiza memória e publica
mudanças de sessão antes de concluir a persistência. `save` e `clear` retornam
void; não há Future `persistence`, rollback ou propagação das falhas de gravação
ao Future de autenticação. Isso substitui as garantias anteriores de espera no
login/logout. A leitura inicial ainda é aguardada e
suas falhas propagam. Não prometa confirmação durável do logout nem atomicidade.
Authentication e Session usam somente o AuthStore compartilhado para credenciais
e observação, sem ler/gravar `StorageKeyEnum.token` ou `userId`. Cadastro não cria
sessão e logout limpa apenas o AuthStore. Troca de senha lê o ID por
`pocketBase.userId()`, atualiza pelo SDK e deixa o logout ao Bloc. Ausência de
identidade propaga a exceção compartilhada do core e ChangePasswordBloc preserva
seus erros como falha esperada, sem logout ou telemetry. O PATCH não captura
snapshots nem limpa a sessão em 401; apenas `signOut()` executa a limpeza explícita.
O SDK decide sucesso pelos seus
contratos; repositories não reimplementam validação de status 2xx específicos.
`PocketBaseMapper` preserva status, ordem, code, pointer e parameter nativos
em `ErrorsEntity`, com fallback de transporte e propagação de Error/FormatException
encapsulados pelo SDK. Tipos e mensagens remotas não chegam diretamente à UI.
Session compartilha refresh pendente da mesma sessão e observa `authStore.onChange`.
Por solicitação explícita de segurança, usa `send<Map<String, dynamic>>` do SDK
compartilhado no endpoint nativo de auth-refresh e parsing por `RecordAuth`.
Compara token, identidade do record e mudanças do AuthStore durante a operação
antes de salvar ou limpar. Respostas e falhas esperadas obsoletas são descartadas;
um refresh tardio não restaura logout nem substitui login novo. HTTP 401 limpa
somente a sessão de origem ainda atual; 403/rede atuais preservam o AuthStore e falham.
`PocketBaseExtension.hasSession` lê somente a presença local de token, sem validar
JWT ou autorização. Parsing e defaults da resposta seguem o SDK.
Não há refresh periódico nem retry automático. DTOs próprios de sign-in/refresh
foram removidos; os contratos de application, Blocs, telas e rotas permanecem.

User recebe o PocketBase pronto e usa `getOne`, `update` e `delete` de users.
O ID vem do auth record atual em cada operação, nunca do storage legado.
`PocketBaseExtension.userId()` centraliza a leitura e rejeita ID ausente, vazio
ou só com espaços, sem normalizar ou alterar sessões. A falha propaga diretamente
como `MissingAuthenticatedUserException` de application do core, com `ErrorsEntity`
próprio; os consumidores de User a tratam como esperada, assim como `UserException`.
`UserResponse` converte o record em entidade pura, com casts estritos e avatar
vazio como ausência. Update envia somente nome/avatar fornecidos, sem normalizar;
o SDK atualiza o auth record correspondente. Delete usa o sucesso nativo do SDK,
que limpa o AuthStore da conta correspondente e notifica Session sem aguardar
persistência durável. UserRepository não gerencia sessões: falhas, inclusive 401,
são mapeadas sem limpar o AuthStore ou capturar snapshots de sessão. Os efeitos automáticos
de update/delete seguem a comparação de ID/coleção do SDK, não uma garantia
adicional de proteção contra respostas antigas para o mesmo usuário.

## Objetivo E Fonte De Verdade

Estas regras orientam alterações no aplicativo Flutter Cordato e em seus testes.
A arquitetura canônica está em [ARCHITECTURE.md](ARCHITECTURE.md); o início rápido
e o estado do produto estão em [README.md](README.md).

O serviço PocketBase independente está isolado em `backend/`, com orientações
próprias em [backend/AGENTS.md](backend/AGENTS.md). A presença do backend neste
repositório não comprova homologação remota: o Flutter já consome a API nativa pelo
SDK. Não alterar o cliente Flutter nem executar deploy como parte de manutenção
localizada do backend.

PocketBase é o backend adotado. Sign-in, cadastro, solicitação e confirmação de verificação
usam os endpoints nativos `collections/users/auth-with-password`,
`collections/users/records`, `collections/users/request-verification` e
`collections/users/confirm-verification`.
Sign-out é local: chama `authStore.clear()`, sem endpoint HTTP ou revogação do JWT
no servidor. Por solicitação explícita, não há saída global nem hook customizado
de logout. A persistência assíncrona segue as limitações descritas acima.
Expense usa o SDK compartilhado diretamente em `collections/expenses/records`
para CRUD e sugestões por histórico, com JSON plano e paginação nativa.
Criação lê `owner` por `pocketBase.userId()`; ausência propaga a exceção compartilhada
do core e o ExpenseBloc preserva seus erros como falha esperada. Expense não
gerencia sessões nem limpa o AuthStore em 401. Delete segue o sucesso nativo do SDK.
Listagem recebe `int page = 1` e devolve `ExpensePageEntity` com `int? nextPage` e
itens imutáveis; não há URLs, cursores opacos ou DTO próprio de página. O Bloc
reenvia os filtros em cada página e retorna à primeira no refresh. Valores dos
filtros são escapados por `PocketBase.filter`, sem parsing próprio de URL/query.
Novas despesas enviam a categoria selecionada pelo valor de `ExpenseCategoryEnum`,
com `other` como padrão quando não informada. Atualizações enviam categoria somente
quando fornecida, inclusive `other`, sem alterar o proprietário. A data civil é
representada como
meia-noite UTC sem conversão de fuso; filtros finais incluem todo o dia escolhido.
Sugestões consultam até 30 registros recentes e deduplicam descrições sem
diferenciar maiúsculas/minúsculas, sem endpoint customizado ou classificação.
Sugestões incluem a categoria tipada do registro mais recente para cada descrição;
aceitar uma sugestão aplica essa categoria no formulário, inclusive `other`,
preservando a data e o valor manual. A projeção consulta `id,description,amount,category`.
Não há migração de registros existentes nem fallback para categoria/data vazias.
Metrics consulta `collections/metrics/records`, uma view mensal
somente leitura com isolamento por proprietário. Totais em centavos e percentuais
são calculados no PocketBase, nunca no Flutter. O repository aceita meses civis
completos; sem datas usa o mês atual, mas rejeita intervalo parcial/incompleto.
Recebe o PocketBase compartilhado e usa `send<Map<String, dynamic>>` nativo no
endpoint relativo `/api/collections/metrics/records`, com filtro por `PocketBase.filter`.
`getList` não é usado nessa consulta porque seus defaults transformam `items`
ausente/nulo em lista vazia; Metrics exige casts estritos antes de publicar zero.
Não há wrapper HTTP/CRUD, filtros locais de proprietário ou gestão de sessão,
inclusive em 401. Erros nativos passam por `PocketBaseMapper` para `MetricsException`.
Lista vazia representa mês sem despesas; resposta inválida ou falha HTTP não
vira sucesso com zero. UI, contratos de apresentação e navegação ficam preservados.
User também usa `collections/users/records/{id}` para consulta, PATCH com JSON
plano de nome/avatar e exclusão. Não há `status` em `UserEntity`; não o derive
de `verified`. Nome vazio é exibido como `Cordato` somente na apresentação.
Edição valida 2–32 caracteres Unicode após trim e mapeia erros 400 de `/name`
ao campo. Avatar vazio do PocketBase vira ausência de seed em infrastructure.
O JWT pertence ao AuthStore do SDK, persistido em `@cordato.pocketbase_auth`, sem
migração das chaves anteriores. Cadastro não cria sessão. Após criar a conta, a
tela de confirmação solicita automaticamente o primeiro e-mail de verificação.
Falha de envio não refaz o cadastro e permite reenvio manual imediato.
O cooldown de 60 segundos pertence ao ResendEmailBloc e começa somente após sucesso.
Callback recebe exatamente um `token` na query, nunca uma URL remota para GET.
Token de verificação não pertence ao estado do Bloc nem aos logs.
Recuperação de senha usa `collections/users/request-password-reset` e
`collections/users/confirm-password-reset`, pelos métodos públicos nativos do SDK.
A confirmação do envio é neutra quanto à existência da conta. `EmailCooldown`
compartilha os 60 segundos com a verificação, iniciados somente após sucesso.
As duas etapas de solicitação compartilham o Bloc da rota. O callback de reset
recebe exatamente um token não vazio na query e aguarda `signOut()` antes de
habilitar o formulário; a exclusão durável não é aguardada pelo SDK. Senha segue as regras
do cadastro e a confirmação deve coincidir. Token e senhas não ficam nos estados
nem nos logs. O logger omite operações de reset e URLs com token. Sucesso e erro
400 em `/token` voltam ao sign-in com toast; falhas de rede e de campos preservam
a tela. Os novos Blocs de recuperação pertencem exclusivamente ao `provide` das
rotas; screens e previews recebem instâncias com proprietário externo explícito.
Senha usa regra única no app: 6–16 code points Unicode, com minúscula ASCII,
maiúscula ASCII e número ASCII, sem trim/normalização; espaços contam no limite.
Cadastro, sign-in, recuperação e troca usam `PasswordValidation` compartilhado.
Dados pessoais abre `/authentication/change-password`, rota autenticada com
`ChangePasswordBloc` pertencente exclusivamente ao `provide`. Authentication possui
o fluxo e o contrato `changePassword(oldPassword:, password:, passwordConfirm:)`;
User somente navega, sem importar sua apresentação. Senha atual é obrigatória,
mas não passa pela política de criação. Nova senha deve diferir exatamente da
atual; confirmação deve coincidir. PATCH nativo de users envia somente os três
campos, lê ID do auth record e não faz logout internamente.
Após confirmação remota, o Bloc aguarda `signOut`; falha de limpeza permite
somente retry de logout, nunca novo PATCH. Controllers são limpos após o PATCH.
Sucesso leva ao sign-in com “Senha alterada. Entre novamente”. A composição root
possui `SessionRedirectDeferral`, não global, exposto por inherited widget do core:
a tela adia redirecionamentos somente da própria rota enquanto a operação está
pendente e libera ao falhar o PATCH, concluir a navegação ou ser descartada.
Authentication e Session continuam sem importar uma à outra. Não há logger HTTP,
Talker ou observer customizado de debug. Não adicione logs de payloads, estados
completos, credenciais ou URLs com token.
Descrições JSON:API e token opaco em documentos históricos não são requisitos
para recriar a API antiga no PocketBase. Não trate troca de `BASE_URL` como
homologação da integração. Diferenças e lacunas
estão em [ARCHITECTURE.md](ARCHITECTURE.md#backend-pocketbase-e-limite-de-integração);
alterações de contrato exigem tarefa explícita com consumidores e testes.

Authentication/Sign-in é a implementação de referência para novas features e
migrações. O padrão obrigatório é:

```text
Screen/Widget -> Bloc -> contrato de repository em application
                           ^
                repository em infrastructure -> SDK PocketBase / clients do core
```

O Bloc chama o contrato; o módulo injeta a implementação. Contratos retornam
dados por `Future<T>` e falhas esperadas por exceções de aplicação. Não use
`Either`, `Left`/`Right`, `response<T>`, CommandIt ou data sources como padrão
para código novo ou para um fluxo migrado.

Há código legado incompatível com esse desenho. Sua existência não constitui
uma exceção arquitetural aprovada. A migração do transporte para o SDK não implica
migração de todo ownership de Bloc ou homologação remota. Não amplie uma tarefa
localizada para migrar outros fluxos sem solicitação.
Specs OpenSpec arquivadas e registros de execução são históricos. Em conflitos,
prevalecem estas regras e `ARCHITECTURE.md`; consulte `openspec/README.md`.
Não restaure Supabase/RPC, commands ou ownership antigo por uma descrição histórica.

O serviço Node-RED independente está isolado em `worker/`, com orientações em
[worker/AGENTS.md](worker/AGENTS.md). Inclui infraestrutura e flow importável de
áudio → IA por Chat Completions → despesa PocketBase, configurado por `AI_BASE_URL`,
`AI_MODEL` e `AI_API_KEY`, com OpenRouter como padrão e envio Flutter implementado,
ainda sem homologação remota completa. Logs do worker são somente metadados,
nunca conteúdo ou credenciais.
Não alterar Flutter ou backend nem executar deploy incidentalmente ao manter esse serviço.

## Antes De Alterar

- Leia a feature afetada, os componentes compartilhados usados e seus testes.
- Confira `git status` e preserve alterações existentes, inclusive fora do escopo.
- Faça a menor alteração que satisfaça a tarefa; não reformate áreas não relacionadas.
- Não faça commit, push, reset ou exclusões destrutivas sem solicitação explícita.
- Atualize contratos, consumidores, bindings e testes na mesma mudança.
- Registre bloqueios reais de análise, compilação e testes, sem ocultá-los.
- Não adicione comentários de linha, bloco ou documentação ao código. Explicações
  ficam em Markdown; preserve comentários existentes fora do escopo.

## Produto E Limites

A captura de áudio na Dashboard usa `record`, sem transcrição ou logs de conteúdo,
inclusive em debug. O widget, seus gestos e animações permanecem preservados.
O adapter grava AAC em `.m4a` temporário por até 30 segundos; X, lifecycle e
cancelamento da observação liberam o microfone e removem o arquivo. A seta finaliza
a captura e envia multipart ao worker. Somente `202` válido confirma aceite para
processamento, nunca cadastro da despesa; não há polling ou atualização automática.
O usuário recarrega as despesas depois. O worker processa em memória, sem fila
persistente; reinícios podem perder áudios aceitos e falhas posteriores ficam nos logs.
O fluxo usa `IAudioRepository` → `AudioRepository` → `IRecordingClient` /
`RecordingClient`. `RecordingEvent` é a única família de notificações de captura,
repassada sem duplicação ou mapper; o Bloc e os tipos da Dashboard usam `Audio`,
não `Speech`. O client separa preparação, observação, finalização e limpeza, sem
misturar essas responsabilidades em callbacks extensos. O uso de `http` e
`http_parser` em produção foi explicitamente autorizado para esse envio, diretamente
no repository, sem restaurar o client HTTP genérico removido. `WORKER_URL` é uma
origem HTTPS separada da `BASE_URL`; o JWT atual vai somente ao worker configurado,
sem redirecionamentos, retries ou gestão da sessão nesse fluxo.
O contrato remoto é POST `/api/collections/audio/process`, multipart
com campo `file` de tipo `audio/mp4`; `202` representa somente aceite para
processamento e `415` formato não suportado. A resposta `202` exige `request_id`
não vazio e `status: processing`. Falha de transporte/timeout/resposta incerta
orienta conferir despesas antes de reenviar. Isso não comprova homologação remota.
Não interpretar nem cadastrar despesas no Flutter neste fluxo.

Cordato é um aplicativo de finanças pessoais e familiares. Cada pessoa é dona
dos próprios dados; família é uma lente autorizada de leitura, não dona do dinheiro.

| Feature/contexto | Responsabilidade                                                                 |
| ---------------- | -------------------------------------------------------------------------------- |
| `authentication` | Entrada, cadastro, confirmação de e-mail, reenvio e logout.                      |
| `session`        | Validação inicial via auth-refresh e observação da presença do token.            |
| `user`           | Dados pessoais, nome, avatar e exclusão da conta.                                |
| `expense`        | Fatos atômicos de gastos individuais.                                            |
| `metrics`        | Agregações financeiras somente leitura.                                          |
| `budget`         | Planejado: tetos por intervalo de datas.                                         |
| `family`         | Planejado: organização de membros e leitura combinada.                           |
| `dashboard`      | Apresentação e composição, não um bounded context financeiro.                    |
| `root`           | Composição visual global e entrada do app.                                       |
| `information`    | Termos, privacidade e ajuda públicos, com conteúdo local e sem camadas de dados. |

Não crie `identity` para reproduzir o backend legado. `chat` está fora do escopo.
O Kotlin legado é referência de domínio, não de estrutura Flutter.

Preserve as invariantes:

- Dinheiro em centavos inteiros de BRL; nunca use `double` para valores monetários.
- Gasto não referencia orçamento; pertencimento é derivado da data civil.
- Orçamentos vivos da mesma pessoa não podem se sobrepor.
- Família não concede escrita nos dados de outro membro.
- Sair ou encerrar família não altera os dados individuais.
- Visões combinadas são derivadas dos dados proprietários.
- Não apresente autorização do backend como garantia implementada pelo Flutter.

## Camadas E Arquivos

```text
lib/features/<feature>/
  <feature>_module.dart
  domain/
    entities/
    enums/
    value_objects/
  application/
    exceptions/
    repositories/interface_<feature>_repository.dart
  infrastructure/
    repositories/<feature>_repository.dart
    responses/
  presentation/
    screens/<screen>/
      <screen>_screen.dart
      bloc/
      mixins/
      widgets/
    validators/
    widgets/
    previews/
```

Crie somente diretórios necessários. Features exclusivamente visuais não precisam
de domínio ou repository. Não adicione use cases, inputs, outputs, services,
data sources, BaseBloc ou stores globais sem necessidade concreta aprovada.

- `domain`: tipos e regras puros, sem Flutter, Bloc, HTTP, storage ou application.
- `application`: contratos de operações e exceções esperadas, sem adapters ou UI.
  Contratos de repository ficam aqui, não em `domain/repositories/`.
- `infrastructure`: implementa os contratos, usa o SDK PocketBase compartilhado
  diretamente e converte records/payloads em tipos próprios. Capacidades nativas
  compartilhadas, como home_widget, usam contratos de clients do core.
- `presentation`: Bloc, estados, eventos, telas, validação e feedback. Conhece
  contratos e exceções de aplicação, nunca repositories concretos ou clients.
- Módulos fazem a composição e podem importar implementações concretas.
- `core` contém capacidades realmente compartilhadas; não mova regras de uma
  feature para ele apenas para contornar um limite de dependência.

Authentication e Session não importam uma à outra; comunicam-se pelo AuthStore
do SDK compartilhado. Expense e Budget não dependem de outros contextos financeiros.
Settings possui o Bloc da interação de logout e consome somente contrato e exceção
de aplicação de Authentication, nunca sua apresentação ou repository concreto.
Family deve consultar contextos proprietários por contratos próprios
com adapters em infrastructure, sem dependência reversa. Dashboard pode compor
contratos de aplicação dos contextos que consulta.

A feature Insight foi removida, incluindo composição, consulta remota, seção da
Dashboard, previews e testes próprios. Não restaurá-la a partir de specs históricas.

## Repositories, HTTP E Falhas

- Use parâmetros nomeados e tipos simples quando suficientes. Repository e Bloc
  não normalizam entradas que pertencem ao formulário.
- Retorne `Future<void>` quando o consumidor precisa somente da conclusão;
  não exponha token, DTO ou envelope JSON:API à apresentação.
- Parsing e montagem de payload pertencem a infrastructure. DTOs usam Dart puro
  e casts; não esconda `TypeError` ou `FormatException` como falhas de negócio.
- Repository usa o SDK PocketBase diretamente, sem data sources intermediários.
  Trate `ClientException` e preserve os erros nativos convertidos para `ErrorsEntity`
  por `PocketBaseMapper`; use fallback nas falhas de transporte.
- Lance exceção específica de aplicação, como `AuthenticationException`.
  Não introduza `catch` genérico no repository para mascarar erros inesperados.
- Preserve ordem e metadados dos erros, incluindo `pointer` e `parameter`.
  Não converta exceções inesperadas ou falhas de storage em sucesso.
- Não exiba `title` ou `detail` remotos diretamente em campos, toasts ou telas.
  A apresentação usa mensagens locais em português, mapeadas por status, código,
  campo e contexto da operação, com fallback seguro. `ErrorMessageFormatter`
  contém somente mensagens compartilhadas; regras de campos pertencem aos
  formatadores de cada feature. Preserve o `ErrorsEntity` original nos contratos
  e estados. Testes de formatadores são unitários, sem montar UI.
- A persistência de autenticação segue o AsyncAuthStore nativo: não há espera
  durável, transação ou rollback nas operações de login/logout.
- Endpoints, payloads nativos e headers de autenticação são geridos pelo SDK.
- Não coloque credenciais, tokens ou segredos no código, fixtures reais ou logs novos.

## Bloc E Estado De Tela

- Use Bloc para operações assíncronas e estado de execução da apresentação.
  Não introduza commands nos fluxos novos ou migrados.
- Organize eventos e estados em `screens/<screen>/bloc/`, junto ao Bloc.
- Prefira eventos concretos e estados sealed, imutáveis, mutuamente exclusivos,
  como `SignInInitial`, `SignInSubmitting`, `SignInSuccess` e `SignInFailure`.
- Derive disponibilidade de ações do estado (`canSubmit`, `isSubmitting`);
  não mantenha flags locais espelhando loading, resultado ou erro do Bloc.
- Não armazene senha, token ou credenciais no estado. O evento de submissão pode
  transportar a entrada somente pelo tempo necessário à operação.
- Defina concorrência explicitamente. Submissões como sign-in usam `droppable`:
  eventos durante envio são descartados, não enfileirados; sucesso bloqueia
  novos envios e falha permite retry manual, sem retry automático.
- Falha esperada preserva a mesma `ErrorsEntity` no estado. Falha inesperada
  usa fallback seguro e `addError(error, stackTrace)`; não injete CrashClient
  ou callback de telemetry no Bloc.
- Antes de publicar após `await`, respeite `isClosed` e `emit.isDone`.
  Fechar Bloc ou invalidar handler não cancela HTTP nem persistência.
- Use o lifecycle nativo do Bloc, sem flags paralelas ou override de `close()`
  para reproduzir o fechamento da biblioteca.

## Screens, Formulários E Lifecycle

- Sign-in usa o escopo de página do Modular V7: registre o Bloc somente no
  `provide` da rota com `scope.addBloc<SignInBloc>(SignInBloc.new)`, usando a
  extension do core. A screen recebe a instância e não cria nem fecha o Bloc;
  Modular é o único dono do fechamento. Mantenha `BlocBuilder`/`BlocConsumer`
  e listeners com a instância explícita. Testes/previews fornecem um proprietário
  externo explícito. Não duplique o bind do Bloc no módulo.
- Os demais fluxos ainda não migrados recebem uma factory estável
  `Bloc Function()` por construtor, criam a instância e possuem seu fechamento.
  Não converta essas telas incidentalmente: migre rota, consumidores, previews
  e testes juntos quando a tarefa incluir a adoção do escopo Modular.
- `ExpenseSuggestionsBloc` também usa `provide` e `addBloc` na rota de Expense;
  screen/formulário recebem a instância e não a fecham. Isso não migra o
  `ExpenseBloc`, que continua com factory estável e ownership pela screen.
- Para os fluxos com ownership pela screen, crie em `initState`, feche em
  `dispose` e feche/substitua em `didUpdateWidget`
  somente quando a factory mudar. Rebuild comum não cria outro Bloc.
- Use `BlocBuilder` para renderização e `BlocListener`/`BlocConsumer` para efeitos
  únicos. Não mostre toast, navegue ou envie operações durante o build.
- Se usar `BlocProvider.value`, a propriedade do fechamento continua com a screen.
- Session é uma observação contínua com proprietário no nível da composição:
  `AppWidget` recebe a factory estável, inicia e fecha seu único SessionBloc.
  `AppScreen` é apenas visual; não cria, compartilha por singleton ou fecha outro
  Bloc. A leitura inicial não sobrescreve eventos de token/watch mais recentes;
  falha de storage não é ausência confirmada nem deve apagar o token.
- Session valida o token inicial pelo endpoint nativo de auth-refresh via `send`
  do SDK compartilhado e `RecordAuth`, salvando somente se a sessão de origem
  continuar atual. Sem token não há request. Chamadas da mesma sessão compartilham
  a operação; sessão substituta pode iniciar outra. Não há retry automático.
  Respostas/falhas esperadas obsoletas não alteram o AuthStore; a observação temporária
  é cancelada ao concluir. Erros atuais preservam `ErrorsEntity` em
  `SessionException`/`SessionFailure`; 403/rede não apagam a sessão e 401 limpa
  somente a sessão de origem. Não criar wrapper HTTP, AuthStore próprio ou DTO de refresh.
- Não restaure o interceptor HTTP antigo. Autenticação dos requests pertence ao
  SDK, que deve ser usado somente para a origem configurada do PocketBase.
- Formulário mantém entrada, validação e erros por campo localmente. No sign-in,
  o validator remove espaços do e-mail, mas preserva a senha; Bloc e repository
  delegam os valores recebidos sem outra normalização.
- Quando `next` leva a outro campo de texto, a ação aponta explicitamente ao
  `FocusNode` desse campo por `onEditingComplete`, sem depender da ordem
  automática que também inclui botões auxiliares. O mixin do formulário possui
  e descarta esses nós; ações finais preservam a submissão existente.
- Desabilite campos e envio conforme o estado. No sign-in, mapeie erros PocketBase
  400 pelos pointers `/identity` (e-mail) e `/password`, preservando `code` e
  `parameter` na conversão HTTP. Erros 422 legados conhecidos por pointer continuam
  aceitos. Mostre somente os restantes em toast, com fallback seguro.
- No cadastro, erros PocketBase 400 com `/email` vão ao e-mail e `/password` ou
  `/passwordConfirm` à senha; preserve os erros 409/422 legados conhecidos.
- Preserve entrada após falha; editar limpa somente o erro do campo correspondente.
- No sign-in, sucesso não navega diretamente: a observação global da sessão
  continua responsável pelo redirecionamento.
- Ações de navegação novas usam as extensões de `BuildContext` do Modular no
  widget responsável, não callbacks transportados pela rota nem `Modular.to`.
  Preserve callbacks legados até migrar seus consumidores explicitamente.

Extraia lifecycle, controllers, timers e handlers substanciais para mixin
específico com `on State<Widget>`. A screen mantém composição visual. O mixin
não acessa repository, HTTP ou storage e descarta todo recurso que cria.
Helpers usam o `context` do próprio State, sem repasse redundante.
Lógica visual pura de StatelessWidget pode usar mixin próprio com
`on StatelessWidget`, sem recursos mutáveis ou operações assíncronas.

## Dart, Imports E Componentes

Strings nativas Android usam `<tipo>_<contexto>_<descricao>` em `snake_case`
inglês, separadas em `res/values/strings_<contexto>.xml`; `strings.xml` pertence
ao contexto `app`. Os prefixos são `failure_`, `success_`, `label_`, `action_`,
`cd_`, `msg_` e `config_`, conforme `android/README.md`. Não misture strings com
cores e estilos; agrupe tipos por linhas em branco, sem comentários no código.
Configurações técnicas usam `translatable="false"`. Renomeações atualizam XML,
Kotlin e testes de referências/app links na mesma mudança, preservando URLs e
placeholders posicionais.

### Legibilidade E Coesão

- Não use `var`, inclusive em testes, previews e ferramentas. Use `final` para
  variáveis que não são reatribuídas e tipo explícito para variáveis mutáveis.
- Use nomes que expressem o significado do dado ou da operação. É proibido nomear
  variáveis, parâmetros, campos ou getters como `result`, inclusive em testes,
  previews e ferramentas. Prefira nomes como `passwordCheck`, `createdExpense`
  ou `confirmedDate`; não substitua por outro nome genérico sem significado.
- Métodos devem ter uma responsabilidade identificável. Separe validação,
  atualização de erros de campo, envio de eventos, feedback e navegação quando
  estiverem misturados em um handler extenso. O método coordenador deve deixar
  explícita a sequência da operação, sem esconder efeitos em getters.
- Separe etapas lógicas por linhas em branco. Use blocos com chaves em `if`,
  `else` e laços; não comprima guarda e ação na mesma linha.
- Prefira guard clauses para pré-condições e `switch` com pattern matching para
  estados ou alternativas mutuamente exclusivas. Evite cascatas de `if/else`
  e ternários aninhados; um `if` simples ou ternário simples continua permitido.
- Formatação e classificação de erros remotos pertencem a formatters puros da
  feature, com testes unitários, não a handlers de tela ou callbacks de build.
- Estados visuais alternativos não devem formar árvores de ternários. Use seleção
  explícita por estado e extraia blocos visuais substanciais em widgets públicos
  em arquivos próprios, preservando ownership, foco, controllers e acessibilidade.
- Não crie services, stores, flags espelhadas, hierarquias de mixins ou helpers
  genéricos apenas para reduzir linhas. Extrações precisam reduzir acoplamento
  ou nomear uma responsabilidade real, mantendo o comportamento e seus testes.
- Estas regras valem para todo o projeto. Ao alterar um fluxo, revise também seus
  consumidores; não mova complexidade para outro arquivo nem enfraqueça testes
  para apenas aparentar conformidade.

- Flutter `>=3.50.0` e SDK Dart `^3.14.0`; use primary constructors em declarações novas elegíveis.
  Campos induzidos imutáveis têm tipo explícito e `final`; preserve `const`.
- Parâmetros usados só para inicialização não induzem campos. Construtores com
  lifecycle ou múltiplos caminhos generativos exigem avaliação semântica.
- Não introduza construtor primary vazio em interfaces, mixins, States ou mocks.
- Widgets novos são públicos, `final`, com sufixo `Widget`, arquivo próprio,
  parâmetros nomeados, `required` e `super.key`; use `const` quando possível.
- Não extraia componentes visuais privados dentro do arquivo de outra tela.
- Imports da aplicação usam `package:cordato/`, nunca caminhos relativos de `lib/`.
- UI Material usa `package:material_ui/material_ui.dart`, não
  `package:flutter/material.dart`. Imports Flutter especializados são permitidos
  para símbolos não exportados. Remova imports não utilizados; não crie barrels.
- Reutilize botões, fields, `BounceWidget`, animações e imagens do core antes
  de criar componentes. Botões compartilhados incorporam o bounce de pressão.
- Ícones explícitos usam `Icons` e `IconData` do Material pelo `IconWidget`
  estático do core. Não adicione bibliotecas, controllers, scopes ou listeners
  para animar ícones. Preserve semântica, cores do tema e estado desabilitado.
- Use `context.colors`, `context.typography` e `context.radius`; não duplique
  extensões ou tokens. Scaffold herda o tema; não fixe fundo sem necessidade.
- Recuos externos de telas e bottom sheets usam 16 pixels lógicos, além dos
  insets seguros e do teclado. O botão de voltar de 48 ocupa uma área leading
  de 80, centralizado ou com padding horizontal simétrico de 16. Cabeçalhos
  expandidos começam 16 abaixo da toolbar. Preserve espaçamentos internos dos
  componentes, reservas para ações flutuantes e limites de largura de leitura.
- Animações customizadas respeitam `MediaQuery.disableAnimationsOf` (Android)
  ou `MediaQuery.reduceMotionOf` (iOS), sem substituir uma preferência pela outra.
  Os contratos de configuração do SDK, imports de design e leitura dessas
  preferências são verificados em `test/architecture/`, sem montar UI.
- Assets ficam em `AssetEnum` e `pubspec.yaml`; use `ImageWidget` para imagens.
- Reutilize `ErrorScreen` para erro de tela; preserve acessibilidade, rolagem,
  textos ampliados e exclusão semântica de imagens decorativas e skeletons.

## Módulos E Rotas

O widget externo de cadastro usa `home_widget` por `IHomeWidgetClient`, contrato
em `core/application/clients/`, com adapter em infrastructure. Esse client não
entra em widgets/mixins/Blocs: Root usa `HomeWidgetLaunchBloc` →
`IHomeWidgetLaunchRepository` para leitura inicial e observação de lançamentos;
o repository filtra URIs nativas antes de expor sinais à apresentação. AppWidget
recebe factories de Blocs, nunca o client nem streams nativos. Root possui o
intent pendente e aguarda Session antes de abrir Dashboard → Nova despesa.
Não importe o plugin na apresentação, não compartilhe JWT com o widget
e não faça cadastro em background. Preserve criações abertas sem confundir edição
por ID. No Modular 7, `routeState` representa a base e `Page.name` não identifica
as rotas empilhadas; use os estados reais de `popUntil` na coordenação do atalho.

O resumo mensal do widget usa somente o total do mês atual retornado por Metrics,
nunca somas locais ou filtros históricos da Dashboard. Expense sinaliza mutações
confirmadas pelo client compartilhado, sem importar Metrics/Root. Root compõe os
contratos em `HomeWidgetSyncRepository` e possui um único `HomeWidgetSyncBloc`
sob ownership do AppWidget. Não o registre como singleton nem o recrie em rebuild.
O próprio Bloc observa pedidos de atualização pelo repository com `emit.onEach`,
em handler contínuo distinto dos eventos restartable; não assine esse stream no
widget. Launch e Sync usam o lifecycle nativo para cancelar suas observações.
Preserve revisões e serialização de publicações/limpeza no client para bloquear
respostas antigas após mutação/logout. Snapshot nativo contém somente mês e
centavos, sem credenciais; mês incompatível mostra “Abra para atualizar”. iOS usa
o App Group `group.com.bed.cordato` nos dois targets. Não faça HTTP no widget nativo
nem converta dinheiro para double ao formatá-lo.

Use a API funcional `createModule` do `flutter_modular` 7. Registre contratos
apontando para implementações. Para estado de página novo ou explicitamente
migrado, prefira `provide: (scope) => scope.addBloc<MyBloc>(MyBloc.new)` com
`BlocScopedExtension` em `core/presentation/extensions/`. A rota lê a instância
por `context.read<MyBloc>()` e a entrega à screen. Não registre o mesmo Bloc
também no módulo nem feche na tela uma instância pertencente ao escopo.

Nos fluxos ainda com ownership pela screen, registre Bloc por factory e injete
o tear-off estável, como `bloc: inject<ExpensesBloc>`, sem closures novas a cada
rebuild. Nunca use singleton de Bloc compartilhado entre telas. Session continua
global sob ownership de `AppWidget`; não o transforme em estado de página.

Módulos com `path` possuem binds de feature, disponíveis somente enquanto uma
rota da feature estiver ativa. Dependências consumidas entre features precisam
de módulo compartilhado sem `path`; não dependa de ter visitado uma rota irmã.
Registro no catálogo não comprova resolução de DI: teste o consumidor isoladamente.

Módulos pertencem à feature. Authentication e Expense usam um único módulo por
feature, sem `path`, com binds root-owned e URLs completas de `RouteEnum`.
Não fragmente esses módulos em dependencies/form/list/routes nem use `path: '/'`
em features irmãs: no Modular 7.1.1 o mesmo path identifica o mesmo escopo e seus
binds podem ser sobrescritos. Sem path não significa singleton de Bloc: `add`
continua factory e o dono da instância continua responsável pelo fechamento.
`provide` mantém ownership de página independente do escopo do módulo.
Outras features com paths exclusivos permanecem como estão até migração explícita.
`app_module.dart` faz a composição global.

Navegação pertence ao widget/mixin responsável, por extensões de `BuildContext`.
Argumentos de rota transportam dados, não callbacks. Use resultados tipados de
`pushNamed<T>` e `pop(result)` quando a operação devolve dados confirmados.
`ExpensesScreen` abre edição diretamente e recebe `ExpenseEntity?` no retorno;
Dashboard e Metrics recarregam ao voltar da listagem, mesmo sem alteração, sem
interceptar botão do sistema ou gesto para transportar flags. Callbacks locais
de composição visual, como Metrics notificar Dashboard, continuam permitidos.

## Testes Obrigatórios

Os testes seguem a mesma arquitetura, não o padrão antigo de data sources ou
commands. Espelhe o caminho de produção em `test/features/<feature>/`.

Não adicionar Python ao projeto, inclusive em scripts, fakes e fixtures.
Não manter nem criar testes de UI: telas, widgets, goldens, integração visual
ou flows Maestro. Previews manuais permanecem disponíveis. Preserve testes
unitários de Bloc, validação, formatação, contratos, infraestrutura e arquitetura.

| Alvo                         | Cobertura mínima                                                                                                               |
| ---------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| Domain                       | Invariantes, imutabilidade e semântica dos valores, sem SDKs.                                                                  |
| Application                  | Contratos puros e preservação de erros nas exceções.                                                                           |
| Repository em infrastructure | SDK real com transporte mockado; payload, conversão, erros nativos, parsing inválido, efeitos no AuthStore e falhas inesperadas. |
| Bloc                         | Estado inicial, sequência de estados, delegação, falha esperada/inesperada, concorrência, retry e fechamento pendente.         |
| Modular/rotas                | Catálogo de rotas e resolução de dependências/factories sem montar UI.                                                         |
| Architecture                 | Imports, camadas, contextos e isolamento de contratos; DI/rotas exigem testes próprios.                                        |

- Use `mocktail`, `bloc_test` e `flutter_test`. Em teste de Bloc ou composição,
  mocke o contrato de repository, não um SDK removido. O transporte atual usa
  Dio real com adapter fake; capacidades nativas auxiliares usam clients mockados.
- Os testes exclusivos da factory PocketBase e seu canal simulado de Secure
  Storage foram removidos com a implementação, assim como os testes e fixtures
  exclusivos dos repositories anteriores. Testes de domínio, contratos, Blocs,
  formatação, serialização e DI permanecem sem esse backend.
  O observer customizado e seus testes foram
  removidos junto ao Talker; não adicione um substituto incidentalmente.
- Controle operações pendentes com `Completer` ou sinais observáveis; não dependa
  de sleeps arbitrários para provar concorrência.
- Organize suítes extensas em `group` por operação ou responsabilidade. Separe
  preparação, ação e verificações; extraia montagem repetida para helpers locais.
  Sucesso e falha com expectativas diferentes ficam em cenários próprios, não em
  condicionais dentro das asserções. Matrizes com o mesmo comportamento continuam
  parametrizadas e precisam de nomes que identifiquem cada cenário.
- Testes de tempo/debounce de lógica usam `fake_async`, sem `WidgetTester`
  nem montagem de widgets. Crie e descarte recursos na zona de tempo do cenário.
- Políticas puras dos widgets nativos usam JUnit em `android/app/src/test/` e
  XCTest em `test/native/ios/`, compilando os arquivos de produção sem UI.
  Execute `dart run tool/test_home_widget_native.dart`, com argumento opcional
  `android` ou `ios`. Swift exige macOS/Xcode; isso não substitui build iOS ou
  conferência manual de tamanhos, valores longos e acessibilidade. Não execute
  instâncias concorrentes de `dart run`, pois os build hooks compartilham arquivos.
- Mocks/fakes/adapters públicos ficam em arquivos próprios sob
  `test/support/<feature>/mocks/` ou `fakes/`, nunca dentro de `*_test.dart` ou `lib/`.
- Reutilize um double por contrato; instâncias, stubs e fixtures de cenário são
  locais a cada teste. Imports de suporte usam caminhos relativos explícitos.
- Cancele subscriptions, conclua Futures controlados e descarte recursos criados.

## Previews E Verificação

Previews usam `@CordatoPreview`, tema real, localização e toast compartilhados.
Ficam em `presentation/previews/`; fakes de catálogo não usam rede, storage ou
mocktail. Mantenha um único dono de cada recurso, inclusive Bloc. Sign-in e sugestões de Expense recebem
uma instância com ownership externo; a screen não fecha o Bloc. Use
`PreviewResourceWidget` quando o recurso não pertencer ao lifecycle da tela.
Execute `dart run tool/widget_preview.dart`; `.widget_preview/` não é versionado.

Quando aplicável, execute nesta ordem:

```bash
flutter pub get
flutter analyze
flutter test
```

Verificação focada: `flutter test test/architecture` e testes da feature afetada.
Registre os comandos executados, os resultados e os bloqueios anteriores à tarefa.
Mudança exclusivamente documental não exige executar o app ou a suíte Flutter.

O release Android no GitHub usa `.github/workflows/android-release.yml`, manual
e restrito à `main`, sem publicação no Play ou commits de versão. A versão visível
vem do `pubspec.yaml`; `tool/android_release_version.sh` define o código por
`GITHUB_RUN_NUMBER + 5`, com testes unitários em `test/architecture/`.
Reexecuções mantêm o código; novos códigos exigem novo dispatch. Não alterar o
offset ou recriar o workflow sem considerar o maior código já usado no Play.
Secrets pertencem ao environment `android-release`, nunca ao código ou aos
artefatos. Mudanças no workflow exigem `actionlint`, no script `shellcheck`, além
das verificações Flutter aplicáveis. Setup e limites estão em `android/README.md`.

## Revisão E Pendências

Mudanças estruturais atualizam `ARCHITECTURE.md`; convenções e testes atualizam
este arquivo; estado do produto/configuração atualizam `README.md`. Release
Android atualiza `android/README.md`.

Antes de concluir, confira: camadas corretas, contrato puro, Bloc sem SDKs,
efeitos fora do build, ownership único, testes nas camadas corretas, documentação
coerente e ausência de comentários novos no código.

O estado de transição está registrado em `ARCHITECTURE.md`. Não restaure
dependências removidas nem enfraqueça testes arquiteturais para tornar o legado
aparentemente compatível. Migre cada fluxo completo, com seus consumidores e
testes, quando isso fizer parte da tarefa solicitada.

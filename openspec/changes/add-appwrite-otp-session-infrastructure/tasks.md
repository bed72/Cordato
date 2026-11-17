# Tasks

## 1. Contratos e fronteira de migração

- [x] 1.1 Conferir AGENTS.md, arquitetura, transporte, contratos e testes atuais; registrar baseline de `git status`, `flutter analyze` e `flutter test` e eventuais bloqueios sem restaurar dependências removidas.
- [x] 1.2 Registrar em design.md a referência compatível com a versão Appwrite instalada, formatos/status de OTP, conta e logout e comportamento esperado de cookies; verificar com documentação, sem disparar e-mails ou requests de escrita remotos.
- [x] 1.3 Substituir o contrato antigo pelo único IAuthenticationRepository com requestCode retornando Future<String> com userId, confirmCode e signOut, sem entidade wrapper, nomes públicos com OTP ou contrato legado; verificar testes de contrato e ausência de senha/SDK/Dio nos tipos públicos.
- [x] 1.4 Atualizar ARCHITECTURE.md para explicar a fronteira temporária entre contrato OTP e apresentação antiga; conferir que não declara migração de telas nem funcionamento de Settings.

## 2. Coordenação compartilhada de sessão

- [x] 2.1 Implementar GET de conta por IHttpClient, sem validação de campos da conta ou limpeza manual; verificar `/v1`, cookies pelo transporte, sucesso 2xx, 401, 403, 5xx e falhas de cookies com adapter fake e diretório temporário.
- [x] 2.2 Implementar observação broadcast e restauração por chamada explícita, sem cache/deduplicação; verificar subscribers independentes, cancelamento e ordem das consultas.
- [x] 2.3 Implementar serialização completa de efeitos de restauração, confirmação e logout; verificar com Completer que a fila continua após falha e que operações antigas não sobrescrevem cookies ou estado depois de mutações posteriores.
- [x] 2.4 Documentar em ARCHITECTURE.md ownership, ordem de operações, espera por timeouts e ausência de interceptor de sessão; conferir com testes de arquitetura e implementação efetiva.

## 3. Repository OTP e logout

- [x] 3.1 Implementar solicitação e reenvio explícito de OTP; verificar payload REST `userId: unique()`, e-mail inalterado, desafio retornado, parsing inválido, limite de requests, timeout e ausência de retry/autenticação antecipada.
- [x] 3.2 Implementar confirmação por código e consulta subsequente da conta na unidade serializada; verificar payload com `secret`, cookies processados antes da consulta, evento autenticado após sucesso HTTP do GET e falha incerta quando GET falhar após criação.
- [x] 3.3 Implementar revogação da sessão atual com cookies geridos pelo transporte; verificar sucesso, 401 já ausente, erro remoto sem saída publicada e falha de persistência sem limpeza manual ou garantia adicional de retry.
- [x] 3.4 Mapear HttpClientException para AuthenticationException com ResponseMapper; verificar preservação de status/type e propagação de erros inesperados sem conteúdo remoto, credenciais ou logs.
- [x] 3.5 Documentar em README.md a política de logout, confirmação incerta e infraestrutura OTP ainda sem telas; conferir que não promete login utilizável ou revogação remota em timeout.

## 4. Repository Session e composição

- [ ] 4.1 Implementar ISessionRepository por ISessionClient, repassando session como sessionChanges sem alterar SessionBloc; verificar loadSession, stream, SessionException com ErrorsEntity original e falhas de transporte/cookies sem ausência presumida.
- [ ] 4.2 Registrar capacidade no core e repositories nos módulos existentes sem paths novos; verificar resolução isolada dos contratos Authentication e Session sem visitar rotas, compartilhamento das dependências e ausência de métodos de senha.
- [ ] 4.3 Testar restauração com uma nova instância do jar no mesmo diretório, expiração de cookies e recusa de outra origem/redirect; verificar com Dio real e adapter fake, sem rede nem UI.
- [ ] 4.4 Testar ponta a ponta da infraestrutura OTP → cookies → conta → observação → logout, incluindo confirmação/restauração concorrentes com logout; verificar estado final e conteúdo efetivo do jar sem sleeps arbitrários.
- [ ] 4.5 Atualizar AGENTS.md, ARCHITECTURE.md e README.md com bindings efetivamente disponíveis e adapters ainda ausentes; verificar que apresentação, User, Expense, Metrics, áudio e serviços independentes continuam fora do escopo.

## 5. Verificação integrada

- [ ] 5.1 Executar `flutter pub get`, `flutter analyze` e `flutter test` sequencialmente, incluindo testes de arquitetura e features afetadas; registrar resultados e bloqueios sem remover cobertura ou introduzir testes de UI.
- [ ] 5.2 Revisar o diff final e comparar com os cenários das três specs; verificar ausência de alterações em telas, Blocs, rotas, navegação, backend e worker, comentários novos no código, segredos e dependências removidas reintroduzidas.

## Workflow follow-up

- Migrar ou remover consumidores visuais de senha em mudança própria para resolver as incompatibilidades após remoção explícita do contrato antigo na step 1.
- Homologar OTP, cookies e logout na instância real mediante autorização específica; testes automatizados sem rede não comprovam entrega de e-mail ou integração remota.
- Arquivar a mudança apenas após revisão e conclusão das tarefas de infraestrutura; não marcar a migração visual como entregue.

## Registro de execução — step 1 (17/11/2026)

- Escopo: tarefas 1.1–1.4, sem iniciar coordenação, adapters, bindings ou migração visual.
- Baseline de `git status --short`: somente `?? openspec/changes/add-appwrite-otp-session-infrastructure/`, planejamento existente preservado.
- Baseline: `flutter analyze` sem issues; `flutter test --reporter failures-only` com 1.157 testes aprovados, sem bloqueios anteriores.
- Conferidos AGENTS.md, ARCHITECTURE.md, contratos Authentication/Session, transporte Dio, políticas de origem/mapeamento e cobertura atual de arquitetura/contratos.
- Referências REST e versão 2.7.2 registradas em design.md, somente com leituras públicas. Nenhum e-mail, request remoto de escrita ou deploy.
- Adicionados contrato OTP paralelo, desafio imutável, mock dedicado e nove testes de contrato, domínio e arquitetura. Esses testes verificam a fronteira pública com mock, não comportamento de um adapter de produção.
- Verificação final sequencial: `flutter pub get` concluído sem mudança de dependências; `flutter analyze` sem issues; `flutter test --reporter failures-only` com 1.166 testes aprovados, incluindo arquitetura e Authentication.
- `openspec validate add-appwrite-otp-session-infrastructure --strict` aprovado; `git diff --check` sem problemas.
- Uma execução intermediária da análise detectou um caminho relativo incorreto no novo teste de contrato; corrigido antes da verificação final. Nenhum bloqueio pendente.
- ARCHITECTURE.md registra a coexistência dos contratos e a ausência de adapters/bindings. Settings, telas, Blocs, rotas, serviços independentes e os contratos antigos não foram alterados.

### Correções explícitas do usuário após a primeira implementação

- Substituído o contrato antigo pelo único `IAuthenticationRepository`, removendo a interface paralela e os métodos de senha, cadastro, recuperação e verificação por link. Nenhuma interface Legacy foi criada.
- Nomes públicos simplificados para `requestCode`, `confirmCode` e `signOut`. `requestCode` retorna diretamente `Future<String>` com o userId; entidade wrapper e seus testes foram removidos.
- Reutilizado `AuthenticationRepositoryMock`, sem mock duplicado. Design, spec, arquitetura e AGENTS.md atualizados para refletir essas decisões, que substituem o relato inicial acima.
- `flutter analyze` após a substituição apontou 93 issues nos consumidores antigos e testes dos métodos removidos; não são bloqueios anteriores à tarefa. Não foram criados stubs nem removidos testes antigos para mascarar as incompatibilidades.
- A tentativa de suíte global foi interrompida e não comprova aprovação. A migração/remoção dos consumidores antigos continua pendente.
- Verificação após simplificar para String: `flutter test test/architecture/authentication_contract_test.dart test/features/authentication/application --reporter failures-only`, nove testes aprovados.

## Registro inicial — step 2 (17/11/2026, substituído pela simplificação abaixo)

- Antes de implementar, todas as alterações pendentes foram commitadas a pedido do usuário: `3074c08` (`refactor: replace authentication contract with code-based operations`).
- Implementadas tarefas 2.1–2.4 em `SessionClient`, a única coordenação de sessão; não havia repository/client de sessão legado em produção para preservar ou duplicar. Dio, CookieManager e jar existentes foram reutilizados.
- GET de conta com parsing estrito, observação broadcast, compartilhamento de restauração pendente e fila de restauração/confirmação/logout incluindo efeitos de cookies. Sem wrapper de entidade, nomes públicos com OTP, SDK, AuthStore ou camada legada paralela.
- Remoção persistida somente dos cookies de sessão do projeto aplicáveis à conta, preservando outros cookies/origens. Tombstones de valor vazio permitem retry explícito de escrita incompleta, inclusive após remoção em memória. Falhas de CookieManager propagam sua causa original.
- Adicionado fake de storage delegado a FileStorage real e estendido o adapter fake existente para respostas assíncronas. Os 37 testes de SessionClient usam diretório temporário, jar real e Completer, sem rede, UI ou sleeps.
- `flutter pub get` concluído, sem alteração de dependências. `flutter analyze` permanece com as mesmas 93 issues dos consumidores de senha da step 1, sem diagnóstico nos arquivos desta step. Um import desnecessário introduzido durante o desenvolvimento foi removido.
- `dart analyze lib/features/core/infrastructure/clients/session test/features/core/infrastructure/clients/session test/support/core/fakes/cookie_storage_fake.dart test/support/core/fakes/http_client_adapter_fake.dart`: sem issues.
- `flutter test test/features/core/infrastructure/clients/session/session_client_test.dart test/features/core/infrastructure/clients/http --reporter failures-only`: 54 aprovados.
- `flutter test test/architecture test/features/core test/features/session test/features/authentication/application --reporter failures-only`: 301 aprovados.
- `flutter test --reporter failures-only`: 1.095 aprovados e 13 falhas de carregamento/compilação por consumidores dos métodos removidos de Authentication (incluindo composição global e Settings). A primeira tentativa foi interrompida pela reconexão do ambiente; o comando foi repetido até concluir. Nenhuma cobertura antiga foi apagada ou mascarada.
- ARCHITECTURE.md e AGENTS.md registram ownership, ordem dos efeitos, espera por timeout e ausência de interceptor de sessão. Repositories, bindings e migração visual seguem pendentes, conforme as steps seguintes.
- `openspec validate add-appwrite-otp-session-infrastructure --strict` aprovado após mover o cenário de consumidores antigos para fora do requisito excessivamente longo. `git diff --check` e verificação de formatação sem problemas.

### Simplificação solicitada pelo usuário

- Substituído o SessionClient de 145 por 66 linhas, recebendo somente Dio. Mantidos requests diretos, stream broadcast e uma fila simples que continua após falhas.
- Removidos `_validateAccount`, parsing de identidade, validação adicional de status, cache/compartilhamento de restaurações, limpeza manual, tombstones e desembrulhamento próprio de erros de cookies.
- Cada chamada de restauração consulta `/account`. Sucesso segue o Dio; 401 de resposta confirma ausência. A confirmação mantém POST e GET na mesma operação antes de publicar autenticação.
- Cookies ficam exclusivamente com CookieManager/jar. Sem expiração enviada pelo servidor, não se promete remoção local ao receber 401 ou concluir logout. Não há recuperação adicional de gravações incompletas.
- Design, specs, ARCHITECTURE.md e AGENTS.md atualizados para essas decisões. Os testes específicos das garantias removidas foram substituídos por cenários da política simplificada; cobertura independente e consumidores antigos não foram apagados para esconder falhas.
- `flutter test test/features/core/infrastructure/clients/session/session_client_test.dart --reporter failures-only`: 26 aprovados.
- `flutter test test/architecture test/features/core test/features/session test/features/authentication/application --reporter failures-only`: 290 aprovados.
- Análise focada do client, seus testes e fakes sem issues. `flutter analyze` permanece com as mesmas 93 issues nos consumidores dos métodos de senha removidos; nenhum diagnóstico nos arquivos da simplificação.
- `openspec validate add-appwrite-otp-session-infrastructure --strict` e `git diff --check` aprovados. Sem nova dependência, commit, deploy ou migração visual.

## Registro de execução — step 3 (17/11/2026)

- Todas as pendências anteriores, incluindo a simplificação e ajustes locais existentes, foram commitadas a pedido do usuário em `a31da8a` (`feat: add simple cookie-backed session coordination`).
- Implementadas tarefas 3.1–3.5 em `AuthenticationRepository`, pelo único IAuthenticationRepository: POST de solicitação retorna userId como String, confirmação/logout delegam ao SessionClient. Sem nova interface, SDK, entidade wrapper, data source, retry, método de senha ou política extra de cookies.
- Captura somente DioException e usa ResponseMapper para AuthenticationException, preservando status/type sem conteúdo remoto; parsing e erros inesperados propagam. Nenhum binding ou consumidor visual foi modificado; SessionRepository e composição seguem na step 4.
- 48 testes próprios com Dio/SessionClient/jar reais, adapter fake e diretório temporário: payloads originais, reenvio explícito, parsing inválido, erros remotos/transporte, propagação inesperada, cookies antes do GET, confirmação incerta e saída com/sem expiração remota, incluindo falha de persistência.
- `flutter pub get` concluído, sem alteração de dependências. `flutter analyze` permanece com as 93 issues conhecidas dos consumidores de senha removidos; nenhum diagnóstico nos arquivos do repository. `dart analyze lib/features/authentication/infrastructure test/features/authentication/infrastructure`: sem issues.
- `flutter test test/features/authentication/infrastructure/repositories/authentication_repository_test.dart --reporter failures-only`: 48 aprovados.
- A primeira verificação ampliada encontrou timeouts em testes da step 2 que aguardavam o evento antes de chamar loadSession. Corrigida somente a ordem da ação/asserção, preservando o restante dos ajustes existentes e as expectativas; sem mudar SessionClient ou enfraquecer cobertura.
- `flutter test test/architecture test/features/core test/features/session test/features/authentication/application test/features/authentication/infrastructure --reporter failures-only`: 338 aprovados após essa correção.
- `flutter test --reporter failures-only`: 1.132 aprovados e as 13 falhas de compilação/carregamento conhecidas nos consumidores antigos, Settings e composição global. Nenhuma falha foi ocultada com stubs ou exclusão de testes.
- README.md registra infraestrutura ainda sem telas/bindings, confirmação incerta e limites de logout/cookies. ARCHITECTURE.md, AGENTS.md e design.md refletem o primeiro repository consumidor.
- `openspec validate add-appwrite-otp-session-infrastructure --strict` e `git diff --check` aprovados. Sem chamadas remotas, deploy ou commit das alterações da step 3.

### Correção da estratégia HTTP solicitada pelo usuário

- Consultado o client do histórico `019734f` e substituída a factory que retornava Dio pela fronteira IHttpClient/HttpClient com Requests, Responses e exceções próprias. Sem Either, PocketBase, envelope JSON:API, copyWith sem consumidor ou camada de data source.
- HttpClient encapsula Dio, configura projeto/origem/timeouts/cookies existentes e implementa get/put/post/patch/delete. Core registra IHttpClient e o jar; não registra Dio. SessionClient e AuthenticationRepository não importam Dio ou DioException.
- HTTP 401 chega como HttpResponseException; falhas de cookies são HttpUnexpectedException, sem saída presumida. Status/type Appwrite continuam mapeados sem mensagem remota. Envelope de sucesso inválido permanece falha visível; Error/FormatException inesperados são propagados no transporte.
- Testes de transporte, mapper, sessão, repository e composição adaptados à API própria, mantendo Dio/jar reais com adapter fake. Cobertura de erros nativos deslocada para o transporte; DI verifica contrato compartilhado e ausência de bind Dio, e persistência é conferida por novo jar.
- Adicionado teste arquitetural que restringe imports Dio ao transporte HTTP. Modelos e exceções não importam SDK; não há interface/implementação paralela.
- `flutter pub get` concluído sem mudança de dependências. Análise focada sem issues; `flutter analyze` mantém as mesmas 93 issues conhecidas dos consumidores de senha removidos, sem diagnósticos novos.
- `flutter test test/architecture test/features/core test/features/session test/features/authentication/application test/features/authentication/infrastructure --reporter failures-only`: 357 aprovados.
- `flutter test --reporter failures-only`: 1.151 aprovados e as mesmas 13 falhas de compilação/carregamento antigas. Sem stubs ou remoção de cobertura para ocultá-las.
- Documentação e specs atualizadas; validação OpenSpec estrita e git diff --check aprovados. SessionRepository, bindings de Authentication/Session e UI não foram implementados nesta correção. Sem commit ou chamadas remotas.

### Injeção obrigatória de Dio por construtor

- Por solicitação do usuário, removidos HttpClient.create, Dio opcional e fallback interno. HttpClient exige Dio no construtor e somente executa/traduz requests.
- core_module.dart configura e registra o Dio técnico com endpoint, projeto, timeouts, CookieManager e OriginInterceptor. IHttpClient é registrado por HttpClient.new e recebe esse Dio compartilhado. Isso substitui a decisão anterior de não registrar Dio; SessionClient e repositories continuam sem imports ou dependência direta de Dio.
- Testes fornecem transportes configurados externamente. A composição real verifica a instância compartilhada, opções e envio dos cookies pelo contrato com adapter fake. O teste de arquitetura permite Dio somente em HTTP e na composição do core e bloqueia a volta de create/fallback.
- `flutter test test/architecture test/features/core test/features/session test/features/authentication/application test/features/authentication/infrastructure --reporter failures-only`: 357 aprovados.
- Análise focada sem issues; flutter analyze mantém as mesmas 93 issues conhecidas dos consumidores de senha, sem diagnóstico nesta alteração. OpenSpec estrito e git diff --check aprovados.
- Documentação atualizada. Sem nova dependência, commit, chamada remota ou mudança de comportamento da autenticação/sessão.

### Inversão da dependência de sessão

- Adicionado ISessionClient puro em core/application/clients, com as operações e observação existentes. SessionClient implementa o contrato, sem mudança de comportamento; AuthenticationRepository recebe ISessionClient e não importa a implementação concreta.
- A pedido do usuário, o bind de ISessionClient foi incluído no core por SessionClient.new. Os repositories de aplicação e os demais itens da step 4 continuam pendentes; não foram registrados consumidores de senha ou adapters parciais.
- Adicionados mock compartilhado, testes de delegação de confirmação/logout pelo contrato, resolução isolada do singleton e proteção arquitetural contra import concreto no repository. Os testes de transporte existentes continuam usando a implementação real.
- Verificação focada de arquitetura/core/session/contratos e infraestrutura Authentication: 361 testes aprovados. Análise focada sem issues; flutter analyze mantém as mesmas 93 issues conhecidas dos consumidores antigos de senha.
- Documentação atualizada; validação OpenSpec estrita e git diff --check aprovados. Sem commit, nova dependência ou alteração em UI.

### Consolidação documental e commit solicitado

- AGENTS.md, ARCHITECTURE.md, README.md e openspec/README.md consolidados para seguir a estratégia atual: Dio obrigatório e configurado na DI, HttpClient sem create/fallback e consumidores por IHttpClient/ISessionClient, sem Either ou PocketBase.
- Registrado o nome atual ISessionClient.session e o repasse futuro para ISessionRepository.sessionChanges; preservados os ajustes locais existentes de código e testes.
- Arquitetura documenta o fluxo e os binds efetivamente disponíveis. AuthenticationRepository continua sem bind e SessionRepository pendente; não se declara migração visual ou app completo funcional. Histórico e mudanças arquivadas não foram reescritos.
- Verificação imediatamente anterior ao commit: 361 testes focados aprovados; flutter analyze com as mesmas 93 issues conhecidas dos consumidores de senha removidos, sem novos diagnósticos. OpenSpec estrito e git diff --check aprovados.
- Todas as alterações pendentes serão incluídas no commit por autorização explícita do usuário, sem push ou deploy.

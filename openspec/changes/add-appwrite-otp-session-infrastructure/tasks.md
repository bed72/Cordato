# Tasks

## 1. Contratos e fronteira de migração

- [x] 1.1 Conferir AGENTS.md, arquitetura, transporte, contratos e testes atuais; registrar baseline de `git status`, `flutter analyze` e `flutter test` e eventuais bloqueios sem restaurar dependências removidas.
- [x] 1.2 Registrar em design.md a referência compatível com a versão Appwrite instalada, formatos/status de OTP, conta e logout e comportamento esperado de cookies; verificar com documentação, sem disparar e-mails ou requests de escrita remotos.
- [x] 1.3 Substituir o contrato antigo pelo único IAuthenticationRepository com requestCode retornando Future<String> com userId, confirmCode e signOut, sem entidade wrapper, nomes públicos com OTP ou contrato legado; verificar testes de contrato e ausência de senha/SDK/Dio nos tipos públicos.
- [x] 1.4 Atualizar ARCHITECTURE.md para explicar a fronteira temporária entre contrato OTP e apresentação antiga; conferir que não declara migração de telas nem funcionamento de Settings.

## 2. Coordenação compartilhada de sessão

- [ ] 2.1 Implementar consulta estrita de conta na capacidade compartilhada com Dio e jar injetados; verificar GET com URI preservando `/v1`, cookies, 401, 403, 5xx, payload inválido e falhas de leitura/limpeza usando adapter fake e diretório temporário.
- [ ] 2.2 Implementar observação de estados confirmados e compartilhamento de restauração pendente; verificar subscribers independentes, cancelamento e validação única por sessão sem mutação intermediária.
- [ ] 2.3 Implementar serialização completa de efeitos de restauração, confirmação e logout; verificar com Completer que a fila continua após falha e que operações antigas não sobrescrevem cookies ou estado depois de mutações posteriores.
- [ ] 2.4 Documentar em ARCHITECTURE.md ownership, ordem de operações, espera por timeouts e ausência de interceptor de sessão; conferir com testes de arquitetura e implementação efetiva.

## 3. Repository OTP e logout

- [ ] 3.1 Implementar solicitação e reenvio explícito de OTP; verificar payload REST `userId: unique()`, e-mail inalterado, desafio retornado, parsing inválido, limite de requests, timeout e ausência de retry/autenticação antecipada.
- [ ] 3.2 Implementar confirmação por código e validação subsequente da conta na unidade serializada; verificar payload com `secret`, cookies persistidos antes da validação, evento autenticado apenas após GET válido e falha incerta quando GET falhar após criação.
- [ ] 3.3 Implementar revogação da sessão atual e limpeza local aguardada; verificar sucesso, 401 já ausente, erro remoto sem saída publicada, falha de persistência após revogação e retry explícito que conclui a limpeza sem atingir outras origens.
- [ ] 3.4 Mapear falhas remotas para AuthenticationException com ResponseMapper; verificar preservação de status/type e propagação de erros inesperados sem conteúdo remoto, credenciais ou logs.
- [ ] 3.5 Documentar em README.md a política de logout, confirmação incerta e infraestrutura OTP ainda sem telas; conferir que não promete login utilizável ou revogação remota em timeout.

## 4. Repository Session e composição

- [ ] 4.1 Implementar ISessionRepository pela capacidade compartilhada, sem alterar SessionBloc; verificar loadSession, stream, SessionException com ErrorsEntity original e propagação de parsing/storage inesperados.
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

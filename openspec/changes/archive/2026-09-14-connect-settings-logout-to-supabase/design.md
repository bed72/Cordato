## Context

O logout já está implementado em `IAuthenticationRepository`, `AuthenticationRepository`, `AuthenticationDataSource` e `SupabaseAuthenticationClient`, e essas camadas possuem testes de sucesso, falha e delegação. O client usa a mesma instância de Supabase observada por `ExternalClient`; quando `signOut` emite `signedOut`, o estado global se torna `unauthenticated` e `SessionGuardWidget` encaminha a navegação para welcome.

A lacuna está em Settings: o módulo fornece um callback vazio, não existe command para consumir o repository e a apresentação não mostra execução nem falha. A confirmação visual já fecha o bottom sheet com um resultado booleano antes de qualquer efeito externo.

## Goals / Non-Goals

**Goals:**

- Conectar a confirmação de Settings ao repository de Authentication por um command observável.
- Reutilizar a cadeia repository, datasource e client Supabase existente sem duplicação.
- Bloquear tentativas concorrentes e representar loading no botão fixo de logout.
- Mostrar `LogoutFailure` como feedback localizado e permitir nova tentativa.
- Manter a transição para welcome reativa ao estado global de sessão.
- Cobrir o novo command e preservar a cobertura das camadas existentes.
- Atualizar previews e documentação canônica afetada.

**Non-Goals:**

- Criar outro repository, datasource, client Supabase ou contrato de logout.
- Limpar secure storage manualmente ou alterar o escopo de `Supabase Auth.signOut`.
- Navegar diretamente para welcome na screen, no mixin ou no command.
- Alterar magic link, restauração de sessão, schema, migrations, RLS ou banco.
- Adicionar Bloc, Provider, Riverpod ou testes Flutter de widgets, screens, módulos e rotas.
- Criar nesta mudança uma nova infraestrutura E2E ou fixture autenticada para Maestro.

## Decisions

### Colocar `LogoutCommand` na apresentação de Settings

`LogoutCommand` viverá em `settings/presentation/commands` porque representa a operação assíncrona da tela que inicia o fluxo. Ele implementará `ICommand`, exporá `signOut` como um `Command<void, void>` sem parâmetro, chamará `IAuthenticationRepository.signOut` e transformará `Left` no mesmo erro tipado observado por `command_it`.

A alternativa de colocar o command em `authentication/presentation` foi rejeitada porque faria Settings depender da apresentação de outra feature. A dependência escolhida é `settings/presentation -> authentication/domain`, sem acesso a implementações externas.

### Reutilizar integralmente a cadeia de Authentication

Nenhum novo repository, datasource ou client será criado. O fluxo continuará sendo `LogoutCommand.signOut -> IAuthenticationRepository.signOut -> AuthenticationRepository.signOut -> IAuthenticationDataSource.signOut -> AuthenticationDataSource.signOut -> IAuthenticationClient.signOut -> SupabaseAuthenticationClient.signOut -> auth.signOut`.

Como módulos com `path` no Flutter Modular 7 possuem bindings ativados somente durante a permanência em suas próprias rotas, a cadeia compartilhada ficará em `_supabaseModule`, um módulo privado sem `path` incluído por `authenticationModule`. Assim, o repository é root-owned e pode ser resolvido pelo command feature-scoped de Settings, enquanto validators, commands e rotas de Authentication permanecem no módulo externo e preservam seu ciclo de vida.

Os testes existentes dessas três camadas serão tratados como regressão obrigatória e ajustados apenas onde faltar afirmar ambos os resultados ou a delegação exatamente uma vez. Isso evita testes duplicados sem deixar a integração sem cobertura.

### Tornar o command uma dependência explícita da screen

`SettingsScreen` substituirá `onLogoutPressed` por um `LogoutCommand` exigido no construtor. `settingsModule` registrará o command como lazy singleton e o injetará na rota usando o `IAuthenticationRepository` registrado no injector raiz por `_supabaseModule`, eliminando a possibilidade de produção fornecer um callback vazio.

O command pertence ao ciclo de vida do módulo e será descartado pelo contrato `ICommand`. Commands criados manualmente em previews e testes serão descartados explicitamente.

### Manter confirmação e tratamento no mixin da screen

`SettingsScreenStateMixin` continuará abrindo o bottom sheet. Após resultado `true` e verificação de `mounted`, ele executará o command; `false` e `null` não produzirão efeito. O mixin registrará um listener nos resultados para mostrar um toast de erro com título “Não foi possível sair” e descrição obtida da falha, removendo o listener em `dispose`.

O sucesso não produzirá toast nem navegação local. O evento de sessão pode desmontar Settings antes ou depois de o command publicar sucesso, portanto todo listener verificará `mounted`.

### Representar execução em `SettingsLogoutWidget`

`SettingsLogoutWidget` observará o command com `CommandBuilder`. No estado running, renderizará `DangerButtonWidget` com loading e callback nulo; nos estados idle, success e error, renderizará o botão habilitado apontando para a confirmação. Isso impede novo sheet e nova execução enquanto a operação estiver em andamento.

A alternativa de manter um booleano duplicado em `setState` foi rejeitada porque `command_it` já é a fonte observável do estado assíncrono.

### Deixar a navegação com o estado global de sessão

O client bem-sucedido chama somente `auth.signOut`. `ExternalClient` continuará convertendo `AuthChangeEvent.signedOut` em estado `unauthenticated`, e `SessionGuardWidget` continuará chamando o callback global que navega para welcome. Settings não importará o router e não removerá rotas manualmente.

Isso mantém uma única autoridade para login, logout e restauração. Navegar no sucesso do command foi rejeitado porque poderia competir com o evento emitido pelo Supabase e esconder divergência entre resultado local e sessão real.

### Usar fakes somente nos previews

O preview de `SettingsScreen` criará `LogoutCommand` com um fake local de `IAuthenticationRepository` e usará `PreviewResourceWidget` para descarte. O preview isolado de `LogoutBottomSheetWidget` continuará sem command, repository ou serviço externo.

Não será usado `mocktail` em previews. O preview compacto será ajustado para o novo construtor sem simular Supabase.

### Atualizar documentação e regressões

`ARCHITECTURE.md` registrará `LogoutCommand`, seu binding em Settings, a dependência de `IAuthenticationRepository` e a navegação reativa por `SessionGuardWidget`. A suíte obrigatória incluirá o novo teste de command, os testes existentes da cadeia de Authentication, `ExternalClient` e os testes de arquitetura.

## Risks / Trade-offs

- [Settings passa a depender do domínio de Authentication] → A dependência fica restrita ao command e ao contrato estável `IAuthenticationRepository`; data, infrastructure e SDK permanecem inacessíveis.
- [O command pode concluir depois que o evento de sessão desmontar Settings] → Listeners verificam `mounted`, e não há efeito local no sucesso.
- [Toques rápidos podem tentar iniciar mais de um fluxo] → O botão observa running, fica desabilitado e o handler rejeita abertura enquanto o command já executa.
- [A rota depende de binding compartilhado de Authentication] → `authenticationModule` inclui `_supabaseModule` sem `path`, mantendo o repository root-owned e disponível quando a rota feature-scoped de Settings é ativada.
- [Não há teste Flutter automatizado do fluxo visual completo] → A política do projeto reserva widgets e rotas para Maestro; command, camadas, estado de sessão e limites arquiteturais permanecem cobertos por testes unitários.

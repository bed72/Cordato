## Why

A confirmação de logout em Settings termina em um callback vazio e ainda não encerra a sessão autenticada. O fluxo precisa acionar o Supabase por meio das camadas existentes, expor execução e falha na apresentação e deixar a navegação pós-logout sob responsabilidade do observador global de sessão.

## What Changes

- Criar um `LogoutCommand` na apresentação de Settings usando o contrato `IAuthenticationRepository` já existente.
- Conectar o command ao módulo, à screen e ao mixin de Settings, substituindo o callback vazio de produção.
- Mostrar loading e bloquear novas tentativas enquanto o logout estiver em execução.
- Mostrar feedback localizado quando o repository retornar `LogoutFailure`, mantendo a pessoa em Settings e permitindo nova tentativa.
- Em sucesso, aguardar o evento `signedOut` do Supabase para que `SessionGuardWidget` navegue reativamente para welcome, sem navegação direta pela feature Settings.
- Reutilizar `AuthenticationRepository`, `AuthenticationDataSource` e `SupabaseAuthenticationClient`; não criar uma segunda cadeia de autenticação.
- Registrar a cadeia compartilhada de Authentication em um módulo sem `path`, para que o command feature-scoped de Settings possa resolvê-la sem ativar uma rota de Authentication.
- Adicionar testes unitários do command e manter os testes de repository, datasource, client Supabase, estado global de sessão e arquitetura como regressão obrigatória.
- Atualizar previews com um fake de repository e descarte correto do command, sem inicializar Supabase ou módulos.
- Atualizar a documentação de arquitetura para registrar o novo command, binding e fluxo de logout.
- **BREAKING (internal)**: substituir `onLogoutPressed` no construtor de `SettingsScreen` pela dependência necessária para executar e observar `LogoutCommand`.

## Capabilities

### New Capabilities

- `authentication-session-logout`: define a execução em camadas do logout, a tradução de falhas e a transição reativa da sessão autenticada para welcome.

### Modified Capabilities

- `settings-screen-ui`: conecta a confirmação visual ao command, acrescenta loading, bloqueio de repetição, feedback de falha e previews sem serviços externos.

## Impact

- Afeta presentation e módulo de Settings, além da composição compartilhada dos bindings de Authentication, usando apenas o contrato de domínio de Authentication.
- Reutiliza sem duplicação o repository, datasource, client Supabase e observador global de sessão existentes.
- Adiciona testes em `test/features/settings/presentation/commands` e executa as suítes existentes de authentication, core e arquitetura.
- Atualiza a documentação canônica de módulos, dependências e fluxo de sessão.
- Não altera schema, migrations, RLS, storage, protocolo de magic link ou dependências externas.

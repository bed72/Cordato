## 1. Command E Testes De Camada

- [x] 1.1 Criar `LogoutCommand` em `settings/presentation/commands`, implementando `ICommand`, executando `IAuthenticationRepository.signOut`, expondo `LogoutFailure` pelo `command_it` e descartando o command interno.
- [x] 1.2 Adicionar `logout_command_test.dart` cobrindo sucesso, propagação do `LogoutFailure`, chamada única ao repository e descarte de listeners e command.
- [x] 1.3 Revisar e complementar os testes existentes de `AuthenticationRepository`, `AuthenticationDataSource` e `SupabaseAuthenticationClient` para afirmar sucesso, falha, tradução e delegação única do logout sem duplicar cenários já cobertos.

## 2. Integração De Settings

- [x] 2.1 Registrar `LogoutCommand` no `settingsModule`, injetá-lo na rota e remover o callback de logout vazio de produção.
- [x] 2.2 Substituir `onLogoutPressed` por `LogoutCommand` no contrato de `SettingsScreen` e encaminhar o command ao widget de logout.
- [x] 2.3 Atualizar `SettingsScreenStateMixin` para registrar e remover o listener do command, executar logout somente após confirmação e mostrar toast localizado em `LogoutFailure`, sem navegar diretamente.
- [x] 2.4 Atualizar `SettingsLogoutWidget` para observar o command com `CommandBuilder`, mostrar loading e desabilitar a ação durante execução, reabilitando-a após erro.
- [x] 2.5 Extrair os bindings compartilhados de Authentication para `_supabaseModule`, módulo privado sem `path` incluído por `authenticationModule`, permitindo que o `LogoutCommand` feature-scoped resolva `IAuthenticationRepository` sem uma rota de Authentication ativa.

## 3. Previews

- [x] 3.1 Criar fake de preview de Settings que implemente `IAuthenticationRepository` sem Supabase, storage ou `mocktail`.
- [x] 3.2 Atualizar os previews de `SettingsScreen` para criar `LogoutCommand` com o fake e descartá-lo por `PreviewResourceWidget`, preservando as variações existentes quando aplicáveis.
- [x] 3.3 Confirmar que o preview isolado de `LogoutBottomSheetWidget` continua sem command, módulo, repository concreto ou serviço externo.

## 4. Arquitetura E Documentação

- [x] 4.1 Atualizar a documentação de arquitetura com `LogoutCommand`, binding de Settings, dependência sobre `IAuthenticationRepository` e navegação reativa pelo estado global de sessão.
- [x] 4.2 Ampliar o teste arquitetural para rejeitar imports de `data` e `infrastructure` pela presentation e confirmar que a nova dependência de Settings aponta somente para Authentication domain.
- [x] 4.3 Documentar o escopo root-owned dos bindings compartilhados de Authentication e preservar commands e rotas no módulo feature-scoped.

## 5. Verificação

- [x] 5.1 Formatar somente os arquivos alterados e executar os testes direcionados de command, Authentication, `ExternalClient` e arquitetura.
- [x] 5.2 Executar `flutter analyze` e corrigir todos os diagnósticos causados pela mudança.
- [x] 5.3 Executar `flutter test` e registrar qualquer falha anterior ou não relacionada.
- [x] 5.4 Compilar e inspecionar os previews atualizados no Flutter Widget Previewer.
- [x] 5.5 Executar `openspec validate connect-settings-logout-to-supabase` e confirmar todos os artefatos e tarefas prontos para implementação.
- [x] 5.6 Reexecutar análise, testes, previews e validação OpenSpec após corrigir a composição de DI entre Authentication e Settings.

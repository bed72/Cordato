## 1. Conteúdo Da Confirmação

- [x] 1.1 Criar `LogoutBottomSheetWidget` como widget público e final, compondo `OutlineButtonWidget` “Voltar” e `ElevatedButtonWidget` “Sair” em largura total e na ordem especificada.
- [x] 1.2 Fazer as ações do widget fecharem o bottom sheet com resultado `true` para “Sair” e `false` para “Voltar”, sem acessar sessão, command, repository, Supabase ou router global.

## 2. Fluxo Na Tela De Configurações

- [x] 2.1 Atualizar `SettingsScreen` para abrir `showBottomSheetWidget<bool>` com o título “Deseja sair?”, a descrição “Você precisará entrar novamente para acessar sua conta.” e o novo widget ao tocar no logout habilitado.
- [x] 2.2 Aguardar o resultado do bottom sheet e invocar `onLogoutPressed` exatamente uma vez somente quando o resultado for `true`, tratando `false` e `null` como cancelamento.
- [x] 2.3 Preservar o botão “Sair” desabilitado e impedir a abertura do bottom sheet quando `onLogoutPressed` não for fornecido.

## 3. Preview

- [x] 3.1 Manter o preview habilitado de `SettingsScreen` apto a abrir a confirmação sem inicializar módulos ou serviços externos.
- [x] 3.2 Adicionar preview específico do conteúdo de confirmação dentro de `BottomSheetScaffoldWidget`, usando o título, a descrição e o tema reais.

## 4. Verificação

- [x] 4.1 Formatar os arquivos alterados e confirmar imports por `material_ui` e caminhos `package:cordato/`.
- [x] 4.2 Inspecionar no Widget Previewer a hierarquia, os dois botões em largura total, a ordem das ações e os estados habilitado e desabilitado.
- [x] 4.3 Executar `flutter analyze` e corrigir todos os diagnósticos causados pela mudança.
- [x] 4.4 Executar `flutter test` e registrar qualquer falha anterior ou não relacionada.

## 5. Ajustes Visuais

- [x] 5.1 Tornar o `useSafeArea` de `showBottomSheetWidget` configurável com padrão `true` e desativá-lo somente na confirmação de logout.
- [x] 5.2 Aplicar `SafeArea` somente inferior no conteúdo da confirmação e ordenar `OutlineButtonWidget` “Voltar” acima de `ElevatedButtonWidget` “Sair”.
- [x] 5.3 Atualizar o preview, formatar os arquivos alterados e repetir `flutter analyze`, `flutter test` e a validação OpenSpec.

## 6. Estado De UI Da Screen

- [x] 6.1 Converter `SettingsScreen` para `StatefulWidget` sem alterar seu contrato de construtor ou seus previews.
- [x] 6.2 Criar `SettingsScreenStateMixin on State<SettingsScreen>` e mover para ele a abertura assíncrona do logout, a verificação de `mounted` e a delegação do callback confirmado.
- [x] 6.3 Manter `_SettingsScreenState` restrito à composição visual e repetir formatação, análise, testes e validação OpenSpec.

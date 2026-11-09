## 1. Política compartilhada e validações

- [x] 1.1 Atualizar `PasswordValidation` para 6–16 code points, minúscula ASCII, maiúscula ASCII e número ASCII, preservando a entrada e usando mensagens locais.
- [x] 1.2 Cobrir ausência de cada classe, entrada vazia, limites 5/6/12/13/16/17, espaços, caracteres suplementares e classes não ASCII com testes unitários.
- [x] 1.3 Revisar cadastro, recuperação, sign-in e seus textos/fixtures/previews/testes para a política única, sem duplicar o validator ou alterar incidentalmente seus lifecycles.
- [x] 1.4 Criar validação pura da nova senha diferente da atual e reutilizar/ajustar a confirmação; cobrir três iguais, nova igual à atual com confirmação diferente, divergência, confirmação vazia e comparações exatas sem trim.

## 2. Contrato remoto e segurança

- [x] 2.1 Adicionar `changePassword` ao contrato de Authentication e atualizar todos os fakes/adapters públicos afetados, sem expor DTO, token ou dados de sessão.
- [x] 2.2 Implementar leitura do ID atual, validação de ID ausente/vazio e PATCH nativo com somente `oldPassword`, `password` e `passwordConfirm`, exigindo HTTP 200 e mantendo logout separado.
- [x] 2.3 Cobrir payload exato, ID codificado, autenticação pelo interceptor existente, ID ausente/vazio, status inesperado, preservação dos erros HTTP, falhas de rede e propagação de falhas inesperadas/storage; provar ausência de gravações, logout, refresh e retry no método.
- [x] 2.4 Estender o filtro comum do logger para bodies com campos de senha e revisar observadores de Bloc para não serializar entradas sensíveis; preservar os filtros existentes de reset/token/Authorization.
- [x] 2.5 Cobrir filtros de request/response/error da troca e operações sensíveis existentes, garantindo que PATCH comum de nome/avatar não seja excluído apenas pelo endpoint.

## 3. Bloc e mensagens do fluxo

- [x] 3.1 Criar eventos e estados sealed de alteração e logout, sem senhas no estado, com disponibilidade derivada e política droppable compartilhada entre tipos de evento.
- [x] 3.2 Implementar alteração seguida de logout aguardado; separar falha de PATCH de falha de limpeza e permitir retry exclusivamente de logout após confirmação remota.
- [x] 3.3 Cobrir estado inicial, delegação exata, sequências de sucesso, erros esperados preservados, falhas inesperadas com `addError`, retry de alteração antes de sucesso, bloqueio após sucesso e retry de logout sem novo PATCH.
- [x] 3.4 Usar Completers para provar descarte de eventos concorrentes, espera da limpeza e ausência de emissões após fechamento em cada etapa, sem sleeps arbitrários.
- [x] 3.5 Implementar mensagens locais por contexto/código para `/oldPassword`, `/password` e `/passwordConfirm`, fallback seguro e testes unitários do formatter sem montar UI.

## 4. Tela, rota e entrada em Dados pessoais

- [x] 4.1 Adicionar rota de troca ao catálogo e ao módulo existente de Authentication com `provide/addBloc`, classificada como autenticada; não duplicar bind ou ownership.
- [x] 4.2 Criar tela e componentes necessários reutilizando campos/botões do app, com senha atual, nova, confirmação, autofill, erros por campo, rolagem e desabilitação conforme estado; concentrar controllers/handlers/lifecycle em mixin específico.
- [x] 4.3 Aplicar validações relacionais, preservar entrada em falha anterior ao sucesso remoto e limpar somente o erro do campo editado; descartar controllers sensíveis após confirmação do PATCH.
- [x] 4.4 Apresentar falha de limpeza via `ErrorScreen` com retry somente de logout e impedir retorno do fluxo ao formulário de alteração já concluída.
- [x] 4.5 Adicionar Alterar senha abaixo do e-mail em Dados pessoais, respeitando `canEdit` e usando navegação via `BuildContext`, sem callback de rota ou import de apresentação de Authentication em User.
- [x] 4.6 Coordenar conclusão e observação de Session para terminar no sign-in, remover o fluxo anterior e mostrar “Senha alterada. Entre novamente” uma única vez, preservando os demais fluxos de logout.
- [x] 4.7 Cobrir catálogo de proteção, resolução isolada de dependências, factories/ownership e decisões puras de navegação afetadas sem testes de widget, integração visual ou montagem de UI.
- [x] 4.8 Criar previews offline com proprietário externo do Bloc para formulário, envio, erros por campo e falha de logout.
- [ ] 4.9 Revisar manualmente acessibilidade, textos ampliados e sequência de navegação da troca de senha em dispositivo. Catálogo compilado/servido sem cliente conectado não comprova esta etapa.

## 5. Documentação e verificação

- [x] 5.1 Atualizar `AGENTS.md`, `ARCHITECTURE.md` e `README.md` com política única, contrato/rota de troca, ownership, proteção dos logs e semântica de alteração seguida de logout, sem editar histórico arquivado.
- [x] 5.2 Executar testes focados de Authentication, User, core afetado, módulos/rotas e `test/architecture`, sem criar testes de UI ou enfraquecer restrições arquiteturais.
- [x] 5.3 Executar `flutter pub get`, `flutter analyze` e `flutter test` nessa ordem; preparar previews com `dart run tool/widget_preview.dart` quando aplicável e registrar resultados e bloqueios reais.
- [x] 5.4 Revisar diff final: sem credenciais, comentários novos em código, alterações de backend/schema, dependências desnecessárias, migração incidental ou deploy; validar a change com OpenSpec e registrar verificações efetivamente executadas.

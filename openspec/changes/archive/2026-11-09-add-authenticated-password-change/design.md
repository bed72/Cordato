## Context

`UserScreen` apresenta nome e e-mail; seu Bloc ainda pertence à screen. Authentication já possui contrato puro, repository com HTTP/storage, logout local e formulários de cadastro/recuperação. `PasswordValidation` também é usado no sign-in e atualmente aceita 6–12 caracteres sem exigir minúscula; o schema PocketBase exige 6–16 e as classes ASCII `[a-z]`, `[A-Z]` e `[0-9]`.

O endpoint nativo de atualização aceita `oldPassword`, `password` e `passwordConfirm`. A coleção permite alterações pelo próprio usuário verificado e não possui `manageRule`. O logger atual omite reset por endpoint, mas não omite automaticamente PATCH de usuário com senhas. A composição global de Session redireciona rotas protegidas para welcome ao remover o token; esse comportamento precisa ser coordenado com a chegada explícita ao sign-in após a troca.

## Goals / Non-Goals

**Goals:**

- Permitir alteração autenticada da própria senha a partir de Dados pessoais.
- Alinhar a política compartilhada ao backend, com erros locais consistentes.
- Separar alteração remota de encerramento local para não repetir o PATCH após sucesso.
- Preservar limites entre features, ownership único, segurança dos logs e cobertura unitária.

**Non-Goals:**

- Alterar schema, regras de autorização, migrações, dados existentes ou publicar backend/app.
- Reautenticar automaticamente ou preservar a sessão após a troca.
- Migrar UserBloc/EditBloc ou os lifecycles legados de cadastro.
- Introduzir services, use cases, data sources, testes de UI ou novas dependências.

## Decisions

### 1. Authentication possui o fluxo; User somente inicia a navegação

Adicionar `ChangePasswordScreen` e seu Bloc em Authentication, com rota `/authentication/change-password` em `RouteEnum`, registrada no módulo sem path existente e classificada como autenticada. O item **Alterar senha** em User usa as extensões de `BuildContext` diretamente; não recebe callback pela rota nem importa apresentação de Authentication.

O Bloc é registrado exclusivamente em `provide` por `scope.addBloc`, lido pela rota e entregue explicitamente à tela. Previews têm proprietário externo. Nenhuma alteração incidental ao ownership de User é necessária.

Alternativa rejeitada: colocar a operação em `IUserRepository` e importar validators/widgets de Authentication na apresentação de User. A alteração é de credencial e o fluxo dedicado permite reutilização dentro do contexto que já possui autenticação e logout, sem dependência entre apresentações.

### 2. Uma política compartilhada e validações relacionais de formulário

Atualizar `PasswordValidation` para 6–16 caracteres e presença das três classes ASCII. Contar caracteres Unicode por code points, consistente com o campo textual do backend, sem trim, normalização ou transformação; espaços e outros caracteres são permitidos e contam no limite, mas não substituem as classes ASCII exigidas. Revisar todos os consumidores, textos e fixtures, incluindo sign-in, mantendo a política num único validator.

No novo formulário, senha atual é obrigatória e será verificada remotamente; não precisa satisfazer a política de criação para poder ser enviada. Nova senha usa a política compartilhada. Um validator puro específico compara nova e atual e outro confirma igualdade com a nova. Se nova igual à atual, mostrar somente em **Nova senha**: “A nova senha não pode ser igual à senha atual”. Se a confirmação divergir, mostrar nela: “As senhas não coincidem”. Quando as três coincidirem, existe apenas o erro de reutilização, além de eventuais violações próprias da política. Comparações são exatas e sem trim.

Alternativa rejeitada: duplicar a expressão regular em cada formulário ou condicionar reutilização à igualdade das três entradas. A proibição depende somente da senha nova e da atual.

### 3. Operação remota independente de signOut

Adicionar ao contrato `IAuthenticationRepository` a operação `changePassword({required String oldPassword, required String password, required String passwordConfirm}) -> Future<void>`. O repository lê `StorageKeyEnum.userId`, rejeita ID ausente/vazio sem HTTP e envia PATCH relativo a `collections/users/records/{id}` com ID codificado e somente os três campos de senha. Bearer continua no interceptor existente, sem autenticação genérica de outras coleções.

Sucesso exige HTTP 200; o corpo do record não precisa atravessar o contrato nem ser convertido em `UserEntity`. `HttpResponseException` preserva `ErrorsEntity` em `AuthenticationException`; demais falhas do client usam fallback. Falhas inesperadas e de storage propagam. A operação não grava credenciais, token ou sessão, não executa logout e não faz GET/refresh/retry.

O Bloc chama `changePassword` e, somente após sucesso, chama `signOut`. A separação permite repetir exclusivamente a limpeza local caso ela falhe.

### 4. Estados distinguem formulário, alteração e limpeza local

Usar eventos concretos e estados sealed, com fluxo equivalente a:

```text
Initial/Failure -> Submitting -> SigningOut -> Success
                        |           |
                     Failure   SignOutFailure
                                    |
                         retry -> SigningOut
```

Submissão e retry de logout compartilham uma política `droppable` para evitar concorrência entre tipos de evento. `Submitting`, `SigningOut`, `SignOutFailure` e `Success` não aceitam nova alteração. `SignOutFailure` aceita somente retry de logout; não volta ao formulário. Senhas não entram em estados, logs ou telemetria e controllers são limpos quando o PATCH termina com sucesso, inclusive quando o logout falha. Eventos transportam entradas somente durante a operação necessária.

Falhas esperadas preservam os mesmos erros; inesperadas usam fallback e `addError`. Após cada await, respeitar `isClosed`/`emit.isDone`; fechamento não cancela a requisição nem desfaz uma alteração remota. Não há retry automático. Falha de rede com resultado remoto desconhecido permanece uma falha, sem prometer rollback; a pessoa pode usar recuperação se já não conseguir autenticar.

### 5. UX e navegação coordenadas com Session

Adicionar o item abaixo do e-mail, disponível quando `state.canEdit`. A tela tem campos ocultos com controle de visibilidade reutilizado, autofill apropriado, formulário rolável e botão **Salvar senha**. Recursos, controllers e handlers substanciais ficam em mixin específico. Campos e submissão ficam desabilitados durante a operação; após alteração confirmada, a tela de falha de logout usa `ErrorScreen` e ação **Tentar novamente**, sem solicitar as senhas de novo.

Erros 400 com `/oldPassword`, `/password` e `/passwordConfirm` são mapeados a cada campo usando mensagens locais por código/contexto. Restantes usam toast seguro. Editar limpa somente o erro do campo editado; erros locais relacionais são reavaliados na próxima validação. Usar as extensões de navegação no listener/mixin, nunca no build.

Após `signOut` concluído, navegar para sign-in removendo o fluxo anterior e mostrar “Senha alterada. Entre novamente”. A rota nova deve integrar o catálogo de proteção. Coordenar os efeitos com a observação global do token para que o redirecionamento de Session não substitua sign-in por welcome nem cause navegação/toast duplicados; preservar o comportamento dos demais logouts. Nenhum sucesso de logout deve ser confirmado quando a limpeza do storage falhar.

Na implementação, essa coordenação usa `SessionRedirectDeferral`, um recurso puro local à composição root, exposto por `SessionRedirectScopeWidget` do core. A tela retém uma liberação idempotente antes da submissão; root adia somente a decisão para a rota retida, e a retenção persiste durante falha/retry da limpeza. Falha de PATCH, navegação concluída e dispose liberam e reavaliam a sessão atual. `SessionRoutePolicy` extrai a decisão já existente para teste unitário sem UI. Não há store global nem import entre Authentication e Session. Isso evita o caso em que o watch do token informa ausência antes de `clear()` concluir.

Na reavaliação motivada exclusivamente pela liberação, uma observação ainda autenticada não dispara redirecionamento a Dashboard: o watch também pode chegar depois do sucesso de `clear()`. Novas observações de Session continuam usando a regra normal, sem espelhar a sessão em flags locais.

Os ajustes adicionais de abertura de teclado, centralização, cabeçalhos e rolagem foram desfeitos por solicitação explícita. As telas preexistentes e o piloto anterior de Expense retornam à composição original; a nova troca de senha usa app bar e formulário com rolagem simples, sem layout ou tratamento especial de inset. Permanecem as ações Próximo/Enviar dos campos, o subtítulo sobre novo login e o toast com título “Senha alterada” e descrição “Entre novamente.”.

### 6. Logger identifica payload sensível, não desliga todo PATCH de perfil

Estender o filtro comum de request/response/error para omitir integralmente requests cujo body JSON contenha `oldPassword`, `password` ou `passwordConfirm`. Assim, o PATCH sensível não imprime corpo ou erro e futuras operações com os mesmos campos também ficam protegidas; manter filtros existentes de reset/token e headers ocultos. Não registrar entradas de eventos nos observers. Atualizações comuns de nome/avatar continuam logáveis segundo a política atual.

Alternativa rejeitada: filtrar apenas o nome do endpoint, pois o mesmo PATCH também atualiza campos de perfil, ou esconder apenas o body de request, deixando respostas de erro e outros canais expostos.

## Risks / Trade-offs

- [PATCH concluído, clear falhou] → Estado separado bloqueia reenvio de senha e permite somente retry de logout; não promete atomicidade entre servidor e storage.
- [Rota fechada durante HTTP] → Respeitar lifecycle; não publicar estados após fechamento nem alegar cancelamento/rollback da operação remota.
- [Session redireciona antes do feedback] → Coordenar listener e navegação com a observação existente; validar lógica de decisão sem montar UI e conferir em preview/manual.
- [Mudança compartilhada afeta sign-in] → Revisar todos os consumidores e fixtures, não somente cadastro/reset; senha atual da troca exige apenas preenchimento.
- [Contagem Dart diverge de Unicode do backend] → Usar code points e casos com caracteres suplementares nos limites, mantendo classes exigidas ASCII.
- [Logs ou observer incluem credenciais] → Cobrir request/response/error no filtro HTTP e revisar observadores existentes antes da implementação do evento novo.
- [App valida, backend rejeita] → Backend segue autoridade; preservar erros remotos sem exibir suas mensagens diretamente.

## Migration Plan

Implementar e verificar apenas o cliente e seus testes; o backend já suporta o contrato. Atualizar documentação atual na implementação, sem editar specs arquivadas. Executar `flutter pub get`, `flutter analyze` e `flutter test`, registrando bloqueios reais; usar suítes focadas durante o desenvolvimento. Preparar previews com `dart run tool/widget_preview.dart` quando aplicável.

Não há migração de registros ou sessões nem deploy nesta change. Reverter a funcionalidade remove a rota/item e restaura o cliente anterior, mas não desfaz senhas já alteradas no servidor. A criação desta proposta não executa nenhuma dessas etapas.

## Open Questions

Nenhuma dúvida de produto pendente. O comportamento de navegação global e as garantias efetivas do PocketBase devem ser conferidos durante a implementação sem ampliar o escopo para refatorações de Session ou mudanças no backend.

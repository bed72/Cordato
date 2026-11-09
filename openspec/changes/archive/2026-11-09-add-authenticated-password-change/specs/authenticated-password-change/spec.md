## ADDED Requirements

### Requirement: Acesso autenticado por Dados pessoais

Dados pessoais SHALL apresentar a ação Alterar senha abaixo do e-mail, habilitada quando a edição de dados estiver disponível. A ação SHALL abrir uma rota autenticada com senha atual, nova senha, confirmação e botão Salvar senha. O novo Bloc SHALL pertencer exclusivamente ao escopo da rota, sem alterar ownership dos Blocs legados de User.

#### Scenario: Abertura do formulário
- **WHEN** a pessoa autenticada aciona Alterar senha em Dados pessoais
- **THEN** a nova rota apresenta os três campos ocultos e o botão Salvar senha
- **AND** o formulário aplica a capacidade `shared-password-policy`

#### Scenario: Dependências independentes de visita anterior
- **WHEN** a rota é resolvida sem visitar cadastro ou outra rota de Authentication
- **THEN** o módulo resolve contrato, validator e Bloc da página
- **AND** o escopo de página é o único proprietário do fechamento do Bloc

#### Scenario: Ações do teclado
- **WHEN** a pessoa usa Próximo em Senha atual ou Nova senha
- **THEN** o foco avança diretamente ao campo de senha seguinte, sem fechar o teclado ou focar o botão de visibilidade
- **AND** a ação Enviar em Confirmar nova senha executa a mesma validação e submissão de Salvar senha, respeitando a disponibilidade do Bloc

#### Scenario: Ausência de sessão
- **WHEN** a composição observa ausência de sessão na nova rota
- **THEN** a rota recebe a proteção global existente para páginas autenticadas

### Requirement: Alteração nativa limitada ao usuário atual

A operação SHALL retornar `Future<void>`, ler o ID atual do storage e enviar PATCH autenticado para `collections/users/records/{id}` com JSON contendo somente `oldPassword`, `password` e `passwordConfirm`. Ela SHALL exigir HTTP 200 para concluir a alteração, não executar logout internamente e não expor o record retornado à apresentação.

#### Scenario: Atualização válida
- **WHEN** a entrada é válida e o storage contém o ID do usuário
- **THEN** o repository envia os três valores exatos no PATCH ao ID codificado
- **AND** HTTP 200 conclui a alteração sem gravar credenciais ou reautenticar

#### Scenario: ID ausente
- **WHEN** o storage retorna ID ausente ou vazio
- **THEN** a operação falha com erro de aplicação sem executar HTTP

#### Scenario: Resposta ou client falha
- **WHEN** o servidor rejeita a alteração ou o client falha
- **THEN** erros HTTP são preservados em exceção de aplicação e demais falhas do client usam fallback seguro
- **AND** nenhum logout ou retry automático ocorre

#### Scenario: Status inesperado ou falha inesperada
- **WHEN** o PATCH retorna status diferente de 200 ou o storage lança uma falha inesperada
- **THEN** a operação não confirma a alteração como sucesso
- **AND** falhas inesperadas do storage propagam sem mascaramento

### Requirement: Erros locais e remotos por campo

O formulário SHALL mapear erros PocketBase 400 de `/oldPassword`, `/password` e `/passwordConfirm` aos respectivos campos com mensagens locais por contexto/código, sem exibir title/detail remotos. Os demais erros SHALL usar feedback seguro. Falhas anteriores à confirmação remota SHALL preservar entradas, e edição SHALL limpar somente o erro do campo editado.

#### Scenario: Senha atual incorreta
- **WHEN** PocketBase retorna erro 400 identificado por `/oldPassword`
- **THEN** Senha atual apresenta uma mensagem local apropriada
- **AND** o formulário preserva entradas e permite correção e reenvio manual

#### Scenario: Erro de nova senha ou confirmação
- **WHEN** PocketBase retorna erros 400 em `/password` ou `/passwordConfirm`
- **THEN** cada erro aparece no campo correspondente com mensagem local
- **AND** os erros originais permanecem preservados no contrato e estado

#### Scenario: Falha de rede
- **WHEN** o PATCH falha por rede sem confirmação de sucesso
- **THEN** o formulário permanece disponível para retry manual com fallback seguro
- **AND** o app não promete que a alteração remota foi desfeita

### Requirement: Concorrência e lifecycle seguros

O Bloc SHALL bloquear envios concorrentes e novos envios após alteração confirmada, usando política droppable explícita compartilhada entre submissão e retry de logout. Senhas SHALL existir somente na entrada de formulário/evento durante o tempo necessário, nunca nos estados. O Bloc SHALL preservar erros esperados, reportar falhas inesperadas com `addError` e respeitar fechamento/invalidação após awaits.

#### Scenario: Duplo envio
- **WHEN** chegam novas submissões enquanto uma alteração ou logout está pendente
- **THEN** os novos eventos são descartados sem PATCH ou limpeza adicionais

#### Scenario: Fechamento com operação pendente
- **WHEN** o escopo fecha o Bloc durante uma operação pendente
- **THEN** a conclusão não emite novos estados nem efeitos de apresentação
- **AND** o app não descreve o fechamento como cancelamento HTTP ou rollback

### Requirement: Logout obrigatório após alteração confirmada

Após confirmação do PATCH, o fluxo SHALL descartar entradas sensíveis e aguardar `signOut()` local. Somente a conclusão da limpeza SHALL habilitar o sucesso completo, o destino sign-in e o feedback “Senha alterada. Entre novamente”. A navegação SHALL remover o fluxo anterior e ser coordenada com Session sem duplicar efeitos ou terminar em welcome.

#### Scenario: Alteração e logout concluídos
- **WHEN** PATCH e limpeza local concluem com sucesso
- **THEN** a pessoa chega ao sign-in com o feedback de senha alterada
- **AND** voltar não reabre o formulário de troca concluído

#### Scenario: Limpeza local falha após PATCH
- **WHEN** a alteração foi confirmada e `signOut()` falha
- **THEN** o fluxo informa que precisa encerrar a sessão e permite Tentar novamente
- **AND** senhas são descartadas, o formulário permanece indisponível e não há sucesso completo nem novo PATCH

#### Scenario: Retry somente de logout
- **WHEN** a pessoa tenta novamente após falha de limpeza local
- **THEN** o Bloc executa somente `signOut()`
- **AND** sucesso leva ao sign-in e nova falha mantém disponível exclusivamente esse retry

### Requirement: Nenhuma exposição de senhas nos logs

O app SHALL omitir do logger HTTP os canais de request, response e error de operações com campos de senha no body, inclusive PATCH de users. Estados e observadores SHALL não registrar as entradas sensíveis do evento. Os filtros existentes de reset, token e Authorization SHALL permanecer preservados.

#### Scenario: PATCH de senha nos três canais
- **WHEN** uma operação com `oldPassword`, `password` ou `passwordConfirm` no body gera request, response ou error
- **THEN** esses canais não imprimem a operação sensível nem seus valores

#### Scenario: PATCH comum de perfil
- **WHEN** uma atualização de nome/avatar não contém campos de senha nem outro motivo de exclusão
- **THEN** ela permanece sujeita à política normal de logs, sem exclusão apenas por usar o endpoint users

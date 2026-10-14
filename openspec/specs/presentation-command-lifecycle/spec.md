# presentation-command-lifecycle Specification

## Purpose
TBD - created by archiving change align-command-it-presentation-errors. Update Purpose after archive.
## Requirements
### Requirement: Propriedade segue registros reais do Modular

ICommand SHALL continuar integrando Disposable sem mudança de API. Commands factory SHALL pertencer ao consumidor que recebe a instância; lazy singletons de feature SHALL ser descartados pelo Modular quando seu escopo terminar; singletons root SHALL NOT ser descartados na saída de uma tela. A propriedade SHALL ser confirmada pelo código instalado, não somente pela presença da interface.

#### Scenario: Factory injetada na Dashboard
- **WHEN** a Dashboard deixa definitivamente a árvore
- **THEN** remove assinaturas próprias e descarta suas instâncias factory
- **AND** não presume que o injector reteve essas instâncias para descarte automático

#### Scenario: Tela sai de um escopo ainda ativo
- **WHEN** EditUser deixa a árvore enquanto o módulo User continua com rota ativa
- **THEN** remove seu listener sem descartar UpdateUserCommand compartilhado pelo escopo

#### Scenario: SignIn deixa a árvore
- **WHEN** a rota de entrada é substituída
- **THEN** a tela remove sua assinatura e não descarta SignInCommand root

### Requirement: Assinaturas pertencem à instância observada

Cada consumidor com command substituível SHALL remover a assinatura da instância anterior antes de observar a nova. Dispose SHALL cancelar a assinatura efetiva, mesmo que widget.command já aponte para outra instância. SHALL NOT criar registry genérico de listeners; ListenableSubscription ou remoção explícita em didUpdateWidget SHALL ser usados conforme legibilidade local.

#### Scenario: Command substituído com listener ativo
- **WHEN** SignIn, SignUp, ResendEmail, EditUser, Settings ou Root recebe command diferente
- **THEN** o listener antigo é removido e o novo é instalado uma vez
- **AND** resultado antigo não produz efeito na tela atual

#### Scenario: Descarte depois de substituição
- **WHEN** a tela é descartada após receber nova dependência
- **THEN** a última assinatura efetiva é cancelada
- **AND** não sobra callback preso ao objeto antigo

### Requirement: Observação declarativa não executa efeitos

CommandBuilder SHALL construir widgets e não navegar, mostrar toast, emitir alteração financeira ou limpar formulário em callbacks de build. onData/onNullData SHALL ser utilizados quando a composição consome retorno. onSuccess SHALL permanecer permitido para layout que ignora dados. Listeners de efeitos SHALL filtrar início/terminal e usar snapshot, não value antigo.

#### Scenario: Builder reconstruído repetidamente
- **WHEN** um resultado de sucesso é renderizado em vários rebuilds
- **THEN** nenhum toast ou navegação é repetido por esses rebuilds

#### Scenario: Botão sem interesse nos dados
- **WHEN** um builder de botão precisa apenas representar idle e loading
- **THEN** pode manter onSuccess/onError sem interpretação do retorno
- **AND** o handler contextual continua responsável pela operação terminal

### Requirement: Estado de campos e temporizadores continua local

Controllers, texto digitado, erros de validação local, seed temporária, cooldown e timers SHALL permanecer nas telas/mixins proprietários. Erro remoto adaptado SHALL alimentar o feedback contextual sem apagar dados ou timers indevidamente. SHALL NOT mover esses recursos para commands apenas para diminuir o mixin.

#### Scenario: Nome inválido recebido da API
- **WHEN** UpdateUserCommand lança falha com pointer de name
- **THEN** EditUser apresenta a mensagem no campo e preserva texto
- **AND** edição posterior pode limpar essa mensagem local sem resetar o command

#### Scenario: Reenvio confirmado
- **WHEN** ResendEmailCommand publica true
- **THEN** o listener inicia o cooldown de sessenta segundos e o toast existente uma vez
- **AND** o timer é cancelado no descarte da tela

### Requirement: Avatar mantém escolha temporária e confirmação de seed

UserScreen SHALL manter autosave de dois segundos, seed temporária, cache confirmado quando necessário e verificação de que a API devolveu a seed enviada. Falha SHALL preservar escolha e mostrar erro sem retry automático. Troca de dependências, confirmação de exclusão e dispose SHALL cancelar o timer. UpdateAvatarCommand SHALL publicar UserEntity ou falha tipada sem conhecer timer ou UI.

#### Scenario: Várias regenerações antes do prazo
- **WHEN** a pessoa regenera o avatar repetidamente antes de dois segundos
- **THEN** somente a última seed é enviada após reiniciar o prazo
- **AND** nenhuma seed obrigatória é gerada no sign-up por causa dessa mudança

#### Scenario: API não devolve seed solicitada
- **WHEN** a atualização retorna UserEntity cujo avatar difere da seed pendente
- **THEN** a tela não anuncia persistência bem-sucedida
- **AND** mantém escolha e fallback de erro existentes

#### Scenario: Falha após avatar confirmado
- **WHEN** um save posterior falha
- **THEN** a apresentação não perde a informação confirmada necessária ao desenho
- **AND** não remove avatarUser apenas por existir resultado no command

### Requirement: Authentication e Settings preservam fluxo de sessão

SignIn, SignUp, ResendEmail e Logout SHALL consumir seus novos resultados mantendo a API HTTP, armazenamento, confirmação e navegação existentes. Erros remotos SHALL continuar distribuídos por pointer ou toast. Sessão SHALL continuar sendo observada por Root, sem navegação dentro dos commands e sem reintrodução de Supabase.

#### Scenario: SignIn falha com erros de campos
- **WHEN** o repository devolve Left com falhas de credenciais
- **THEN** o command adapta a falha e a tela mantém mensagens nos campos ou toast contextual
- **AND** não cria sessão nem navega por onSuccess do builder

#### Scenario: Logout falha
- **WHEN** LogoutCommand lança falha esperada ou inesperada
- **THEN** o fluxo mantém sessão conforme o repository atual e apresenta um único feedback
- **AND** não limpa storage nem força navegação na UI para compensar o erro

#### Scenario: Logout confirmado
- **WHEN** o repository revoga o token e limpa storage com sucesso
- **THEN** a observação de sessão existente conduz a navegação global
- **AND** o command não recebe BuildContext ou callbacks de router

### Requirement: Callback conserva coordenação de link e dependência

CallbackScreenStateMixin SHALL preservar revisão da URL, bloqueio do fluxo local, tentativa já iniciada e espera da confirmação em andamento. Mudança de command SHALL invalidar o ciclo mesmo quando a URL não muda. Resultado do mesmo link pode ser compartilhado; link diferente SHALL exigir confirmação própria depois da anterior. Descarte SHALL impedir toast e navegação tardios.

#### Scenario: Mesmo link em execução
- **WHEN** a tela observa uma confirmação pendente da mesma URL
- **THEN** pode aguardar a execução existente sem repetir GET
- **AND** usa o status enum da operação válida

#### Scenario: Link diferente chega durante confirmação
- **WHEN** a URL vigente muda enquanto outra confirmação carrega
- **THEN** o resultado antigo não navega nem anuncia confirmação do link novo
- **AND** o link final vigente é confirmado após o anterior terminar

#### Scenario: Command muda com URL igual
- **WHEN** a dependência é substituída sem alteração de verificationUrl
- **THEN** o resultado antigo é invalidado e não navega pelo ciclo da nova instância

### Requirement: Root conserva redirecionamento único e validade pós frame

AppScreen e AppWidget SHALL continuar observando SessionCommand compartilhado, removendo suas assinaturas sem descartar o command root. Callbacks pós-frame SHALL verificar validade de State e dependência; AppScreen SHALL manter redirecionamento único. A revisão da leitura inicial em SessionCommand SHALL permanecer existente.

#### Scenario: Sessão emite repetidamente durante entrada
- **WHEN** a mesma condição de sessão é publicada antes da navegação da AppScreen
- **THEN** o fluxo executa um único redirecionamento de entrada

#### Scenario: Callback pós frame obsoleto
- **WHEN** a tela é descartada ou a dependência muda antes do callback agendado
- **THEN** o callback não navega com a condição da instância anterior

### Requirement: Previews respeitam novos contratos e um proprietário de descarte

Previews SHALL usar commands reais com fakes de repository que continuam retornando Either, adaptados na fronteira do command. Cada recurso SHALL ter um único proprietário de descarte. PreviewResourceWidget SHALL NOT descartar command já pertencente ao lifecycle da screen. Não SHALL haver mocktail ou SDK nos fakes de preview.

#### Scenario: Preview de seção isolada
- **WHEN** uma seção preview recebe command criado pelo wrapper
- **THEN** o wrapper descarta o recurso e a seção somente observa os resultados

#### Scenario: Preview de screen proprietária
- **WHEN** a screen descarta seus commands factory
- **THEN** o wrapper não repete o dispose desses mesmos objetos
- **AND** recursos singleton simulados que a screen não possui são descartados pelo wrapper

### Requirement: Validação distingue unitários e fluxos reais

Commands e o transporte da exceção SHALL ter testes unitários observando execução, dados, erros, Future e descarte, com subscriptions removidas. Fluxos de widgets e screens SHALL ser validados por Maestro, sem novos testes Flutter de UI/módulos/rotas. Evidências SHALL diferenciar cenários executados, inspeção estática e cenários pendentes; harness temporário SHALL exigir autorização e ser removido após uso.

#### Scenario: Teste de falha esperada
- **WHEN** um teste executa command que recebe Left
- **THEN** verifica a exceção tipada, results.hasError, errors e metadata com roteamento apropriado
- **AND** restaura eventual configuração global e remove assinaturas no tearDown

#### Scenario: Cenário de dependência sem reprodução runtime
- **WHEN** a substituição artificial não é exposta pelo fluxo disponível
- **THEN** a entrega registra o limite de validação e as evidências estáticas
- **AND** não afirma que a suíte de commands comprovou todo lifecycle da screen


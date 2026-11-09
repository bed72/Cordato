> Delta histórico desta change. A política atual está em
> [openspec/README.md](../../../../README.md): somente Sign-in usa ownership
> Modular; listagem recarrega em todo retorno, sem callbacks de rota.

## ADDED Requirements

### Requirement: Bloc é proprietário único do fluxo da Dashboard

A Dashboard SHALL usar um Bloc de apresentação por instância de rota, com estado
imutável e contratos de repositories, sem commands ou dados duplicados no mixin.
Navegação e BuildContext SHALL permanecer fora do Bloc. Outros consumidores SHALL
manter seus commands existentes.

#### Scenario: Atualização de uma seção
- **WHEN** Insights conclui enquanto Metrics ainda carrega
- **THEN** a Dashboard continua em loading sem publicar Insights isoladamente
- **AND** somente a conclusão da carga publica conteúdo completo ou erro

#### Scenario: Rebuild da tela
- **WHEN** a composição visual é reconstruída sem nova intenção
- **THEN** não cria outro Bloc nem solicita novas consultas

### Requirement: Eventos e fases expressam o fluxo sem flags financeiras sobrepostas

O Bloc SHALL receber eventos concretos para abertura, mês anterior/próximo,
refresh, retry, alterações e retorno de User. O estado SHALL possuir somente
loading, ready e failure, sem status auxiliares, barreiras ou recuperação própria.
Cada carga vigente SHALL publicar loading sem dados e um único resultado terminal.
Falhas financeiras tipadas SHALL preservar a mesma ErrorsEntity de Left.

#### Scenario: Retry após erro
- **WHEN** a pessoa solicita retry
- **THEN** passa de failure para loading normal
- **AND** termina em ready ou failure, sem fases intermediárias de recuperação

#### Scenario: Falha tipada contém metadados ou lista vazia
- **WHEN** uma seção financeira retorna Left
- **THEN** após concluir as seções o estado de erro preserva a mesma ErrorsEntity

### Requirement: Intenções financeiras compartilham uma política de concorrência

Todos os eventos SHALL participar de um handler restartable com filtro anterior.
Abertura SHALL ser única. Mês, refresh e retry bloqueados SHALL ser rejeitados sem
interromper o handler ou criar fila. Alteração confirmada e retorno de User SHALL
substituir o handler anterior imediatamente. Cancelamento HTTP está fora do piloto.

#### Scenario: Evento bloqueado não interrompe consulta
- **WHEN** uma seta, refresh ou retry é acionado durante loading
- **THEN** a carga continua sem interrupção, consulta adicional ou intenção pendente

#### Scenario: Alteração disputa com refresh
- **WHEN** uma alteração confirmada chega durante refresh
- **THEN** começa uma carga nova no mês preservado sem esperar a antiga
- **AND** resultados antigos não alteram o estado novo

### Requirement: Resultados obsoletos não publicam estado

Resultados, falhas e finalizações de handlers invalidados SHALL NOT alterar
dados, mês, fase, erro ou disponibilidade de ações. O fechamento nativo do Bloc e
emit.isDone SHALL bloquear conclusões tardias, sem exigir flags paralelas,
identidade do Future de close ou cancelamento do transporte.

#### Scenario: Leitura antiga ainda em andamento
- **WHEN** uma leitura antiga conclui depois de uma carga substituta
- **THEN** nem seu resultado nem sua falha são aplicados

#### Scenario: Descarte durante paginação histórica
- **WHEN** a Dashboard fecha com a leitura histórica pendente
- **THEN** a resposta tardia não inicia seções, não segue next e não publica estado

### Requirement: Sequência das consultas e limite histórico são preservados

Cada carga financeira SHALL consultar User e limite em paralelo, ajustar o mês
civil e consultar as três seções em paralelo, publicando o resultado somente ao
concluir. Isso inclui abertura, mês, refresh, retry e alterações. O limite SHALL
usar pageSize 1 e sort occurred_on ascendente, sem seguir next. Falha de User
SHALL usar placeholder; falha de limite SHALL manter seleção e bloquear a seta
anterior. Nenhuma falha auxiliar SHALL produzir ErrorScreen.

#### Scenario: Limite sem histórico
- **WHEN** a leitura histórica tem sucesso sem despesas
- **THEN** não fabrica um limite e ajusta seleção passada para o mês atual

#### Scenario: Histórico grande
- **WHEN** a leitura ascendente de um item retorna um next
- **THEN** calcula o mês civil da despesa e ignora a continuação
- **AND** a carga usa exatamente cinco leituras independentemente do histórico

### Requirement: Usuário possui leitura substituível no retorno

Retorno de User/Settings com conteúdo pronto SHALL consultar apenas User e
preservar os dados financeiros confirmados, com loading único até concluir.
Durante loading/erro SHALL iniciar carga completa, invalidando a anterior.
Falha de User SHALL manter o fallback existente. Alteração financeira SHALL
reler User dentro da carga completa.

#### Scenario: Nome alterado com leitura antiga pendente
- **WHEN** a pessoa retorna de User durante loading
- **THEN** outra carga começa sem esperar a leitura antiga
- **AND** a resposta antiga não sobrescreve perfil ou finanças novos

#### Scenario: Retorno para instância obsoleta
- **WHEN** o callback de navegação conclui após fechamento ou substituição do Bloc
- **THEN** não solicita leituras para o Bloc antigo ou novo

### Requirement: Widgets de ação navegam pelo próprio contexto

Dashboard e descendentes SHALL navegar por context.pushNamed, sem callbacks de
navegação. A screen SHALL fornecer BlocProvider.value sem transferir descarte.
Retornos SHALL validar montagem e identidade. onExpensesChanged SHALL sinalizar
somente mutações confirmadas. Metrics SHALL NOT importar o Bloc da Dashboard.

#### Scenario: Retorno do cadastro sem mudanças
- **WHEN** a pessoa retorna sem salvar
- **THEN** preserva mês e conteúdo sem consultas financeiras

#### Scenario: Categoria com alterações confirmadas
- **WHEN** uma listagem de categoria retorna com mutação confirmada
- **THEN** solicita carga financeira somente após retorno válido

### Requirement: Erros inesperados seguem a política visual sem telemetry no Bloc

Exceções inesperadas SHALL usar o fallback auxiliar ou erro financeiro genérico,
conforme a consulta. O Bloc SHALL NOT receber ICrashClient ou callback de reporte.
Command.globalExceptionHandler dos consumidores não migrados SHALL permanecer inalterado.

#### Scenario: Exceção inesperada na consulta
- **WHEN** uma seção financeira lança uma exceção
- **THEN** a carga termina em failure sem publicar dados parciais nem realizar telemetry

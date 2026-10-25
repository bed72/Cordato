# shared-error-screen Specification

> Requisitos visuais permanecem subordinados à [arquitetura atual](../../README.md):
> execução por Bloc e feedback fora do build, sem restaurar commands históricos.

## Purpose
TBD - created by archiving change unify-dashboard-error-screen. Update Purpose after archive.
## Requirements
### Requirement: Tela compartilhada controla a página de erro

O core SHALL oferecer uma `ErrorScreen` de apresentação, dona de seu `Scaffold`, com cabeçalho opcional fornecido pelo consumidor, corpo com ícone, título e descrição e footer com ações configuráveis. A screen SHALL poder ser retornada diretamente pelo consumidor sem registrar ou abrir uma rota. Ela SHALL NOT acessar commands, repositories, rede, storage ou router para executar ações.

#### Scenario: Composição completa com cabeçalho
- **WHEN** o consumidor fornece appBar, título, descrição e ação principal
- **THEN** a screen apresenta um único Scaffold com esse cabeçalho, mensagem no corpo e ação no footer
- **AND** não exige um Scaffold externo nem cria rota adicional

#### Scenario: Composição sem cabeçalho
- **WHEN** o consumidor não fornece appBar
- **THEN** a screen apresenta corpo e footer respeitando as áreas seguras sem reservar espaço de cabeçalho vazio

### Requirement: Ações configuráveis e loading

`ErrorScreen` SHALL receber texto e callback anulável da ação principal, loading e texto/callback opcionais de uma ação secundária. A ação secundária SHALL ser omitida quando seu texto não for informado. Callback nulo SHALL representar ação desabilitada. Loading SHALL exibir progresso no botão principal e desabilitar ambas as ações. A screen SHALL delegar a execução aos callbacks fornecidos, sem coordenar consultas ou executar retry automático.

#### Scenario: Ação principal
- **WHEN** a pessoa toca a ação principal habilitada
- **THEN** o callback correspondente é chamado uma vez para esse toque
- **AND** a screen não dispara nenhuma operação adicional

#### Scenario: Footer com ação secundária
- **WHEN** o consumidor fornece label e callback de ação secundária
- **THEN** o footer exibe ambas as ações e cada uma aciona somente seu próprio callback

#### Scenario: Recuperação em execução
- **WHEN** o consumidor informa loading ativo
- **THEN** o botão principal mostra progresso e as ações não aceitam toques
- **AND** a mensagem e o cabeçalho permanecem visíveis

### Requirement: Identidade visual e acessibilidade da tela de erro

`ErrorScreen` SHALL usar `material_ui`, tema e botões compartilhados do Cordato, com margens laterais de 20 pixels. O corpo SHALL destacar um ícone decorativo acima do título e da descrição centralizados; o footer SHALL agrupar as ações na base quando houver espaço. SafeArea e rolagem adaptável SHALL manter conteúdo e ações acessíveis em telas menores e com texto ampliado, sem truncamento ou overflow. A screen SHALL preservar contraste nos temas claro e escuro e SHALL NOT exibir botão flutuante.

#### Scenario: Tema escuro
- **WHEN** a screen é exibida com o tema escuro do aplicativo
- **THEN** fundo, textos, ícone e botões usam os papéis semânticos do tema ativo

#### Scenario: Espaço reduzido e fonte ampliada
- **WHEN** título, descrição e ações ultrapassam a altura disponível
- **THEN** a composição permite rolagem para acessar todo o conteúdo e os botões
- **AND** nenhum texto é truncado e nenhuma ação invade a área de navegação do sistema

#### Scenario: Leitor de tela
- **WHEN** a pessoa usa leitor de tela
- **THEN** título, descrição e labels das ações são acessíveis em ordem de leitura
- **AND** o ícone decorativo não duplica o anúncio do erro

## Why

A Dashboard apresenta retries separados para nome, métricas, insights e despesas, fragmentando uma mesma situação de indisponibilidade e deixando a tela visualmente confusa. Uma tela de erro compartilhada deve oferecer uma mensagem única e uma ação de recuperação clara, controlando cabeçalho, corpo e footer.

## What Changes

- Criar `ErrorScreen` no core, responsável pelo `Scaffold`, com cabeçalho opcional, ícone, título, descrição e footer com ações configuráveis e loading.
- Substituir o Scaffold normal da Dashboard pela `ErrorScreen` assim que métricas, insights ou despesas falharem, mesmo com outras consultas em andamento ou concluídas com sucesso.
- Ocultar o cabeçalho da Dashboard durante erro financeiro e recuperação. No conteúdo normal, exibir “Cordato” quando a consulta do usuário falhar, removendo seu retry localizado.
- Ocultar seletor mensal, seções financeiras e botão flutuante no estado de erro, preservando a instância e o mês selecionado.
- Oferecer um retry único coordenado pela Dashboard, recarregando usuário, limite do histórico e as três seções, com loading no footer e sem execuções concorrentes.
- Restaurar o conteúdo somente quando as três consultas financeiras da tentativa vigente concluírem com sucesso; falha de usuário ou limite do histórico não dispara o erro global.
- Atualizar documentação e validar apresentação por previews e Maestro.

## Capabilities

### New Capabilities

- `shared-error-screen`: tela de erro de apresentação compartilhada, com controle do Scaffold, cabeçalho, corpo, footer e ações fornecidas pelo consumidor.

### Modified Capabilities

- `dashboard-monthly-navigation`: erro global imediato por falha financeira, fallback do nome e recuperação coordenada preservando o contexto mensal.
- `expense-category-metrics-cards`: substituir o retry localizado de Metrics pelo estado de erro global da Dashboard, preservando os demais estados e a acessibilidade.

## Impact

- Apresentação do core em `lib/features/core/presentation/screens/error/` e seus previews.
- `DashboardScreen`, `DashboardScreenStateMixin`, `UserNameWidget` e composição dos estados das seções financeiras.
- Previews e flows Maestro da Dashboard e da tela de erro compartilhada.
- `ARCHITECTURE.md` e `AGENTS.md`, que atualmente descrevem retries por seção.
- Integração HTTP, contratos financeiros, commands e rotas públicas permanecem com seus contratos atuais. A troca de Scaffold não cria uma nova rota nem uma nova instância da Dashboard.
- A migração de Dados pessoais para `ErrorScreen` fica fora desta mudança; a tela compartilhada permite esse uso posteriormente.

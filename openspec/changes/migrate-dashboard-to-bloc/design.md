## Context

`DashboardScreenStateMixin` coordena cinco commands e repete validações de início, parâmetros, snapshots terminais e identidade. Seções e cabeçalho também conhecem commands. Apenas trocar o mixin por Bloc sem remover essa dupla propriedade não resolve o problema.

O código atual usa contratos de repository com `Either`, data sources e HTTP compartilhado. Existem alterações locais em andamento nesse HTTP e uma proposta separada, `introduce-exception-http-insight`, ainda não implementada. Esta proposta parte dos contratos executáveis atuais, não migra globalmente erros para exceções nem depende da aprovação daquela change. Se os contratos mudarem antes da implementação, o plano deverá ser conciliado explicitamente, preservando as garantias de cancelamento.

## Goals / Non-Goals

**Goals:**
- Um proprietário do estado e do fluxo da Dashboard, testável sem widgets.
- Políticas explícitas entre todos os eventos que disputam o mesmo ciclo financeiro.
- Cancelamento real no Dio e invalidação lógica, inclusive quando um adapter não respeitar cancelamento.
- Preservar comportamento financeiro, navegação, apresentação e fallbacks, exceto mudanças aprovadas de skeleton e cancelamento imediato.

**Non-Goals:**
- Migrar Authentication, UserScreen, ExpensesScreen ou formulários para Bloc.
- Adicionar MobX, BaseBloc, gerenciador global, cache compartilhado ou endpoint novo.
- Cancelar escritas, desfazer operações no servidor ou alterar a política de sessão.
- Reestruturar repositories, normalizar filtros ou mudar o modelo de domínio.

## Decisions

### 1. Bloc de apresentação específico da Dashboard

Criar `DashboardBloc`, eventos e estado sob `dashboard/presentation/screens/dashboard/bloc/`. O Bloc recebe contratos de User, Expense, Insight e Metrics e um relógio injetável ou mecanismo já existente para tornar datas determinísticas em testes. Não conhece BuildContext, Modular, Dio, storage ou widgets.

Usar `bloc` e `flutter_bloc`, `bloc_concurrency` para agendamento e `bloc_test` como dependência de desenvolvimento. Escolher versões compatíveis na implementação; não fixar versões presumidas nesta spec. Estado imutável representa mês, resultados/status das três seções, usuário, limite histórico e fase do ciclo. Disponibilidade de ações é derivada desse estado, não espelhada em flags no mixin. Não é obrigatório adicionar Equatable ou geração de código.

Alternativa rejeitada: Bloc sobre os commands existentes, que manteria snapshots, duas máquinas de estado e propriedade ambígua. MobX não foi escolhido porque observação automática não fornece as políticas de eventos desejadas.

### 2. Uma única fila lógica de intenções financeiras

Registrar os eventos financeiros em um único domínio de coordenação, por exemplo `on<DashboardFinancialEvent>` com `restartable()`, sem handlers adicionais concorrentes para os mesmos subtipos. O registro por tipo separado não fornece exclusão mútua entre refresh, mês e alterações confirmadas.

Intenções aceitas tornam o ciclo ocupado antes do primeiro await. Validar eventos bloqueáveis antes de entregá-los ao transformer: uma seta, gesto de refresh ou retry rejeitado durante ocupação não pode cancelar a execução aceita, enfileirar outra ou liberar loading. Cada handler que emitir após await também verifica identidade vigente e `emit.isDone`.

| Intenção | Durante ocupação | Política |
| --- | --- | --- |
| Abertura | Não duplicar na mesma instância | Um ciclo inicial |
| Troca mensal | Rejeitar sem enfileirar | Executar somente se disponível e dentro dos limites |
| Refresh por gesto | Rejeitar sem enfileirar | Um ciclo aceito por vez |
| Retry global | Rejeitar sem enfileirar | Recuperação completa somente em erro e disponível |
| Retorno com alteração financeira | Sempre substituir o ciclo financeiro vigente | Cancelar e iniciar leitura nova imediatamente |
| Retorno sem alteração | Não consultar | Preservar estado |

Um novo ciclo invalida a identidade anterior antes de cancelar os seus recursos. Nenhum resultado, catch ou finally antigo modifica estado do ciclo novo. Cancelamento do handler Bloc e cancelamento HTTP são mecanismos distintos; ambos são necessários.

Alternativa rejeitada: `restartable()` independente por evento, que permite corrida entre tipos; `sequential()` para tudo, que faz a alteração confirmada esperar por uma leitura já desatualizada.

### 3. Escopos de cancelamento separados

Cada ciclo financeiro possui cancelamento para limite histórico e consultas das três seções. Troca/substituição ou fechamento cancela tudo que pertence ao ciclo anterior. A primeira falha de Metrics, Insights ou recentes encerra logicamente aquele ciclo e cancela as outras consultas financeiras. A leitura do limite já terá terminado nos ciclos que a aguardam.

User possui uma geração e um escopo separados. Retorno de User/Settings cancela leitura anterior de User e inicia outra, sem invalidar os resultados financeiros. Recuperação global recarrega User; se já existir leitura antiga, ela é substituída para garantir leitura nova. Alteração financeira sozinha não cancela nem exige recarregar User. Fechamento cancela ambos os escopos.

Falha financeira não cancela User. A ErrorScreen aparece imediatamente, mas retry permanece bloqueado enquanto uma leitura auxiliar vigente ou finalização do ciclo ainda estiver ativa. Cancelar a rede não deve exigir esperar por um Future de adapter que ignore cancelamento para invalidar um ciclo e começar seu substituto.

### 4. Cancelamento neutro atravessa as camadas

Definir uma pequena capacidade de cancelamento framework-free em `core/domain/`, com sinal observável, cancelamento idempotente, motivo opcional não sensível e liberação explícita de assinaturas. O proprietário é o Bloc; repositories e data sources somente recebem um sinal opcional. Não criar registro global de requests.

Adicionar parâmetro nomeado opcional de cancelamento apenas às leituras necessárias: User.getById, Expense.get, Insight.get e Metrics.getExpenses, seguindo os contratos em execução. Chamadas existentes sem sinal preservam o comportamento. A ponte HTTP cria um `CancelToken` por request e associa-o ao sinal; um sinal de ciclo pode cancelar várias requests, sem compartilhar tokens de requests independentes. Desassinar em todos os caminhos de conclusão.

Um sinal previamente cancelado impede envio. `DioExceptionType.cancel` é convertido em cancelamento tipado independente de Dio. Esse cancelamento atravessa helper `response<T>`, data sources e repositories antes de qualquer catch genérico: não vira status 500/0, `ErrorsEntity.unknown()`, lista vazia ou sucesso falso. O Bloc consome cancelamento intencional sem ErrorScreen, toast ou reporte de falha. Erros HTTP, parsing e negócio continuam com seus contratos atuais. Ajustar todos os consumidores, mocks e fakes afetados na mesma mudança.

Alternativas rejeitadas: expor `CancelToken` no domínio, ocultar cancelamento como falha genérica ou usar apenas um contador de revisão, que não interrompe a rede.

### 5. Preservar a sequência funcional existente

- Abertura: User, limite e as três seções começam em paralelo no mês atual.
- Troca mensal: consultar as três seções em paralelo, sem repetir User ou o limite apenas pela troca.
- Refresh e retorno com alteração: reler limite, aplicar eventual ajuste civil válido, depois consultar as três seções em paralelo.
- Retry: User em paralelo ao limite; depois do limite, três consultas financeiras paralelas. Falha auxiliar não impede as consultas financeiras.
- Limite: percorrer páginas sem presumir ordem, preservar `next` opaco, detectar links repetidos, tratar null como ausência de histórico e interromper paginação se cancelado. Falha bloqueia a seta anterior.
- Metrics usa intervalo civil e agrupamento por categoria; recentes usam seis itens e o mesmo intervalo; Insights usa ano/mês sem recortar períodos da resposta.
- Sucessos parciais aparecem independentemente em conteúdo normal. No erro/recuperação, só três sucessos do ciclo vigente restauram conteúdo, após encerramento dos auxiliares pertinentes; respostas antigas não contam.
- Falha de User conserva saudação, nome “Trocado” e avatar placeholder. Retorno de User/Settings solicita leitura nova, ignorando retornos de uma instância descartada/substituída.

Falhas inesperadas efetivamente expostas pelo fluxo Bloc devem ser reportadas ao `ICrashClient` com erro e stack, sem duplicação; falhas de negócio e cancelamentos não são telemetry. Não alterar o handler global de CommandIt para consumidores não migrados nem iniciar uma migração do tratamento de exceções dos repositories.

### 6. UI consome estado, não operações

O módulo da Dashboard cria um Bloc por instância da rota. Escolher um único proprietário do fechamento: provider que cria fecha; provider `.value` exige fechamento explícito do proprietário externo. Não registrar como singleton nem fechar duas vezes. Se substituído, fechar a instância antiga e invalidar seus retornos de navegação.

Seções e cabeçalho recebem dados/status/callbacks, renderizados com `BlocBuilder`/`BlocSelector` conforme necessário; não recebem commands. Eventos de navegação continuam callbacks injetados pela rota. O mixin, se ainda necessário, fica restrito à navegação e recursos visuais, sem espelhar dados ou fases do Bloc.

Durante carregamento normal, preservar mês/ano visíveis e substituir ambos os botões do seletor por placeholders skeleton com dimensões estáveis. Skeletons não possuem callbacks, foco ou ações semânticas de navegação; anunciar carregamento sem expor texto fictício. Durante erro/recuperação, seletor e Scaffold normal permanecem ocultos.

Remover `GetFirstExpenseMonthCommand` e seus testes somente após migrar sua lógica e verificar ausência de outros consumidores. Commands compartilhados de User, Expense, Insight e Metrics continuam disponíveis fora da Dashboard. Adaptar previews e seus proprietários de recursos, sem duplicar implementações de estado exclusivas para preview.

## Risks / Trade-offs

- [Coexistência de Bloc e CommandIt] → Piloto restrito à Dashboard, documentado como tal; nenhuma exigência de migração geral.
- [Maior superfície de contratos por cancelamento] → Parâmetro opcional somente nas leituras necessárias, sem Dio no domínio; testes de compatibilidade para consumidores atuais.
- [Cancelamento absorvido por catches existentes] → Testes ponta a ponta das camadas com adapter controlável, incluindo helper de resposta e repositories.
- [Restartable não cancela Future ou servidor] → CancelToken explícito, identidade por ciclo e proteção de emissão; nenhum cancelamento de escrita é prometido.
- [Evento bloqueado interrompe ciclo por engano] → Filtrar antes do restartable e testar tipos distintos competindo entre si.
- [Apenas mover 571 linhas para outro arquivo] → Eliminar comandos intermediários, snapshots, microtasks de pendência e estado duplicado; revisar complexidade total, não apenas tamanho do mixin.
- [Trabalho local e change HTTP concorrente] → Reavaliar diff na implementação e preservar alterações do usuário; resolver sobreposição antes de editar contratos.

## Migration Plan

1. Registrar baseline de análise/testes, dependências, consumidores e contratos HTTP atuais, inclusive trabalho local.
2. Adicionar cancelamento opcional com testes nas camadas, mantendo chamadas atuais sem sinal.
3. Implementar Bloc e testes determinísticos com Futures controlados, incluindo cancelamento ignorado pelo adapter.
4. Migrar composição da Dashboard, DI, previews e seletor, removendo coordenação CommandIt somente desse fluxo.
5. Atualizar documentação, executar análise e testes e validar interação com Maestro.

Não há migração de dados ou alteração no servidor. Se o piloto não demonstrar simplificação e garantias, interromper a expansão para outras telas. Qualquer reversão de implementação deve ser explícita e limitada aos arquivos do piloto, sem descartar trabalho externo.

## Open Questions

Não há decisão de produto bloqueante. Nomes finais do contrato neutro de cancelamento, versões compatíveis e detalhes de seleção de estado serão definidos na implementação conforme o código vigente, respeitando estes contratos.

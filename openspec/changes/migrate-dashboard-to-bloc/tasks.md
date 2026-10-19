## Escopo

Cancelamento HTTP foi adiado por solicitação explícita do usuário. As tarefas de
capacidade neutra, CancelToken, propagação e testes de transporte foram retiradas
deste piloto. Identidade e invalidação lógica continuam obrigatórias no Bloc.

## 1. Baseline e dependências

- [x] 1.1 Registrar contratos executáveis, alterações existentes e disponibilidade da change HTTP referenciada, sem sobrescrever trabalho externo.
- [x] 1.2 Mapear comandos, seções, cabeçalho e previews; registrar baseline de análise e testes.
- [x] 1.3 Adicionar bloc, flutter_bloc, bloc_concurrency e bloc_test compatíveis; executar pub get.

## 2. Estado e coordenação Bloc

- [x] 2.1 Criar DashboardBloc, eventos e estado imutável específicos da tela, dependendo somente dos contratos de repositories, sem telemetry.
- [x] 2.2 Compartilhar coordenação financeira entre intenções; filtrar eventos bloqueados antes de restartable e identificar cada ciclo.
- [x] 2.3 Implementar abertura paralela, mês civil, seis recentes, agrupamento de métricas e ano/mês de insights com resultados independentes.
- [x] 2.4 Consultar limite histórico com uma única request ascendente de um item, sem seguir next, preservando ausência e invalidação lógica.
- [x] 2.5 Implementar refresh e alteração confirmada com releitura do limite; alteração substitui imediatamente o ciclo anterior.
- [x] 2.6 Implementar erro financeiro imediato e recuperação completa, sem efeitos de resultados/catches/finalizações antigos.
- [x] 2.7 Implementar User independente e substituível e fechamento idempotente, sem ICrashClient ou callback de reporte.

## 3. Testes determinísticos

- [x] 3.1 Reutilizar doubles públicos de test/support; testar abertura, tempos distintos, vazios, total zero, limites civis, virada de ano e fevereiro bissexto.
- [x] 3.2 Testar eventos bloqueados entre tipos distintos, sem interrupção nem fila.
- [x] 3.3 Testar alteração durante abertura, refresh e recuperação e respostas/falhas obsoletas sem encerrar loading novo.
- [x] 3.4 Testar primeira falha, recuperação, falha repetida, auxiliares, User antigo e política visual para exceções inesperadas.
- [x] 3.5 Testar request única de limite, cinco leituras na abertura mesmo com histórico grande, ausência, ajuste civil, invalidação e fechamento sem páginas tardias.

## 4. Integração visual

- [x] 4.1 Criar um Bloc por Dashboard no módulo da rota com propriedade única do fechamento e callbacks/records preservados.
- [x] 4.2 Adaptar tela, cabeçalho e seções a dados do Bloc via BlocBuilder, sem commands ou estado financeiro duplicado no mixin.
- [x] 4.3 Restringir mixin a lifecycle/navegação; revalidar Bloc e montagem ao retornar das rotas.
- [x] 4.4 Substituir controles mensais por skeletons durante loading normal, sem callbacks, foco ou ações acessíveis.
- [x] 4.5 Preservar ErrorScreen sem AppBar, textos, FAB, avatar, categorias, seis recentes e estados vazios.
- [x] 4.6 Adaptar previews e remover GetFirstExpenseMonthCommand e testes exclusivos após cobertura equivalente no Bloc.

## 5. Documentação e verificação

- [x] 5.1 Atualizar ARCHITECTURE.md, AGENTS.md e README sobre piloto, recursos e convivência com commands, explicitando ausência de cancelamento HTTP.
- [x] 5.2 Atualizar testes arquiteturais: domínio sem Dio/Bloc/Flutter e apresentação sem clientes HTTP.
- [x] 5.3 Executar pub get, analyze, test e test/architecture, registrando falhas anteriores/externas.
- [ ] 5.4 Validar com Maestro abertura, skeleton, bloqueio mensal, troca, erro/retry e retornos; registrar bloqueios quando não houver dispositivo/app disponível.
- [x] 5.5 Validar OpenSpec strict e revisar diff, sem alterações core HTTP, somente sort opcional em Expense e sem commands em produção na Dashboard.
- [x] 5.6 Comparar complexidade total com o baseline, eliminando snapshots e microtasks em vez de transferir o mixin.

## 6. Refatoração de legibilidade solicitada na revisão

- [x] 6.1 Substituir intenção genérica e offsets por eventos concretos, atualizando todos os consumidores.
- [x] 6.2 Modelar fases financeiras e status auxiliares explícitos, preservando as falhas tipadas no estado.
- [x] 6.3 Separar preparação mensal, consultas e conclusão da recuperação, mantendo filtro anterior ao restartable e isolamento de ciclos.
- [x] 6.4 Cobrir transições emitidas, recuperação substituída, erros preservados e fechamento durante espera de User; executar análise e suítes.
- [x] 6.5 Atualizar documentação canônica e registrar a verificação e os bloqueios visuais desta revisão.

## 7. Simplificação da orquestração

- [x] 7.1 Concentrar a sequência financeira no handler, eliminando encaminhamentos e identificadores que duplicavam o controle do emitter.
- [x] 7.2 Tornar copyWith uma cópia sem regras de limpeza e substituir observação do próprio stream pela conclusão vigente de User.
- [x] 7.3 Testar substituição sem esperar User obsoleto, recuperação sucessiva e cópia explícita de erros; executar verificações e registrar resultados.

## 8. Carga atômica aprovada pelo usuário

Esta decisão substitui os requisitos anteriores de publicação parcial, falha
imediata, User independente e fases especiais de recuperação.

- [x] 8.1 Reduzir a loading/ready/failure, eliminar barreira, status auxiliares e publicação parcial; unificar a sequência de consultas.
- [x] 8.2 Adaptar tela e testes para publicação única, retry normal, fallbacks e invalidação de respostas obsoletas.
- [x] 8.3 Sincronizar documentação e specs com a decisão e executar análise, suítes e validação visual possível.

## 9. Remover controle redundante de fechamento

- [x] 9.1 Definir o mês padrão em DashboardState(), mantendo somente _opened no Bloc e usando isClosed/emit.isDone.
- [x] 9.2 Remover a exigência de identidade do Future de close, atualizar documentação e validar conclusões tardias.

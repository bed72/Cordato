## 1. Tela compartilhada de erro

- [x] 1.1 Criar `ErrorScreen` em `core/presentation/screens/error/error_screen.dart`, dona do Scaffold, com appBar opcional, ícone, título, descrição e footer configurável conforme o design.
- [x] 1.2 Compor corpo e ações usando `material_ui`, tema, SafeArea e botões compartilhados, incluindo callbacks anuláveis, ação secundária opcional e loading que desabilita as ações.
- [x] 1.3 Implementar layout adaptável com rolagem para telas menores e texto ampliado, ícone decorativo e conteúdo acessível sem truncamento.

## 2. Fallback do cabeçalho

- [x] 2.1 Alterar `UserNameWidget` para mostrar “Trocado” com avatar placeholder em Left ou exceção e remover o retry localizado e seu import.
- [x] 2.2 Preservar skeleton, nome e seed da API no sucesso, saudação e callbacks do avatar e cabeçalho.

## 3. Estado de erro global da Dashboard

- [x] 3.1 Observar resultados, erros e loading dos três commands financeiros no `DashboardScreenStateMixin`, ativando erro global imediatamente após qualquer falha sem esperar outras consultas.
- [x] 3.2 Manter o erro persistente após sucessos remanescentes, distinguindo falhas financeiras de resultados nulos, vazios e falhas auxiliares de User ou limite histórico.
- [x] 3.3 Retornar `ErrorScreen` no lugar do Scaffold normal, com textos definidos e cabeçalho existente, sem seletor, seções ou FAB e sem criar rota ou State novo.
- [x] 3.4 Ajustar a composição das seções para remover retries localizados da Dashboard; verificar usos antes de remover widgets e previews de falha sem consumidores.

## 4. Recuperação coordenada e lifecycle

- [x] 4.1 Criar handler único de retry para User, limite histórico e três seções, bloqueado enquanto houver consulta ou recuperação ativa, sem enfileirar toques.
- [x] 4.2 Preservar o mês, consultar User em paralelo ao limite e disparar as três seções em paralelo após aplicar eventual ajuste civil existente do limite.
- [x] 4.3 Manter `ErrorScreen` com loading durante a recuperação e restaurar o conteúdo somente após sucesso das três consultas financeiras da tentativa vigente; permitir nova tentativa após outra falha.
- [x] 4.4 Garantir que falhas de User e limite não impeçam a recuperação financeira, mantendo fallback do nome e bloqueio da seta anterior respectivamente.
- [x] 4.5 Remover listeners e descartar recursos conforme o lifecycle existente; invalidar ciclos obsoletos após troca de dependências ou descarte e preservar recarga após navegação.

## 5. Previews e documentação

- [x] 5.1 Adicionar previews de `ErrorScreen` com/sem cabeçalho, ação secundária, loading, temas claro/escuro e texto ampliado usando `@CordatoPreview`.
- [ ] 5.2 Atualizar previews da Dashboard para erro global e fallback do usuário, preservando descarte dos recursos de preview.
- [x] 5.3 Atualizar `ARCHITECTURE.md` e `AGENTS.md` para documentar `ErrorScreen`, erro financeiro único, retry coordenado e fallback do nome.

## 6. Verificação

- [x] 6.1 Executar `flutter pub get` quando aplicável, `flutter analyze` e `flutter test`, registrando causas de eventuais falhas sem criar testes Flutter de UI, módulos ou rotas.
- [ ] 6.2 Preparar cenários controlados e flows Maestro para falha isolada de cada seção, múltiplas falhas, falha antes de outras conclusões e erro observável por exceção.
- [x] 6.3 Validar com Maestro retry bloqueado durante consultas, loading estável, toques repetidos, nova falha e recuperação financeira completa sem flashes de conteúdo.
- [ ] 6.4 Validar com Maestro mês histórico preservado, ajuste por novo limite, falhas auxiliares independentes, fallback “Trocado” e navegação disponível pelo cabeçalho.
- [x] 6.5 Validar previews e interação da tela compartilhada em ambos os temas, espaço reduzido e texto ampliado, incluindo acesso às ações no footer.

## Registro da etapa 1

- ErrorScreen e oito previews implementados, com documentação do componente em `ARCHITECTURE.md` e `AGENTS.md`. A tarefa 5.3 permanece pendente para a integração da Dashboard.
- `flutter analyze` sem problemas e `flutter test` com 671 testes aprovados. Não houve alteração de dependências.
- Previews inspecionados no Chrome em ambos os temas, com loading, callbacks nulos, cabeçalhos e footers distintos. Rolagem verificada em 320×480 e 568×320 com texto a 200%, preservando acesso às duas ações e labels sem truncamento.
- Maestro Web não iniciou o flow por erro da ferramenta (`null cannot be cast to non-null type kotlin.Int`); a inspeção dos previews foi realizada diretamente no Chrome. Cenários financeiros e flows Maestro da Dashboard pertencem às próximas etapas.

## Registro da integração

- Fallback de User, erro financeiro imediato e persistente, retry único e lifecycle implementados. Previews e documentação atualizados; os componentes de retry localizado perderam seus consumidores e foram removidos.
- Maestro Android aprovou a matriz com cinco cenários (falhas isoladas de Metrics, Insights e despesas, múltiplas falhas e exceção), retry que falha novamente e recupera na segunda tentativa, mês histórico preservado, ajuste pelo novo limite e recuperação financeira com falhas auxiliares.
- Os contadores verificaram ausência de consultas extras por toques bloqueados. O mês efetivamente consultado foi verificado antes e depois da recuperação histórica e do ajuste de limite.
- A chamada MCP com vários flows excedeu o timeout; a validação foi confirmada pelo CLI Maestro com relatórios JUnit. A navegação de Menu foi conferida na exploração inicial.
- A validação de interface foi encerrada por orientação do usuário. A tarefa 6.4 permanece parcialmente pendente para conferir explicitamente o fallback “Trocado”, falhas auxiliares isoladas e os callbacks de cabeçalho durante o erro. Não há promessa de cobertura completa de lifecycle por esses flows.
- A análise final encontrou dois erros fora deste escopo em `test/features/core/infrastructure/clients/firebase/firebase_client_test.dart:38` e `:56`: os testes acessam `FirebaseClient.initialize` por instância após uma alteração concorrente que tornou o método estático. As alterações de Firebase foram preservadas. A suíte unitária não foi repetida nesta etapa; os 671 testes registrados acima pertencem à etapa 1.
- O build debug normal (`lib/main.dart`) compilou e foi reinstalado no Android com `adb install -r`, preservando o storage local. `git diff --check` não apontou problemas na revisão.

## Remoção do código de testes

Por solicitação do usuário, foram removidos o menu e o launcher de cenários,
o recurso de respostas controladas, os flows Maestro e os hooks de simulação
adicionados aos fakes. Também foram removidos os previews adicionais que
dependiam desse recurso. Os registros anteriores descrevem validações já
executadas, não código de testes mantido no projeto. As tarefas 5.2 (fallback)
e 6.2 não representam mais entregas completas; sua parte de simulação foi
retirada. Os previews visuais da ErrorScreen solicitados na etapa 1 e o preview
existente da Dashboard, atualizado para erro global, permanecem no catálogo.

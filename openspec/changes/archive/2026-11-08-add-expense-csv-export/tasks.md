## 1. Compatibilidade e contratos

- [x] 1.1 Conferir AGENTS.md, toolchain Android/iOS, adapters de core, módulos e testes envolvidos; selecionar versões compatíveis de `csv`, `share_plus` e `path_provider`, registrando qualquer bloqueio sem ampliar para upgrades não aprovados.
- [x] 1.2 Definir o contrato de exportação de Expense em `lib/features/expense/application/repositories/interface_export_repository.dart`, documento puro com identidade de origem, validação dessa identidade e exceções esperadas, sem SDK/Flutter nos contratos; cobrir preservação de ErrorsEntity.
- [x] 1.3 Definir o contrato de coordenação de Settings em `lib/features/settings/application/repositories/interface_export_repository.dart`, com fases preparar/compartilhar/descarte e desfechos explícitos para vazio, cancelamento e resultado nativo indisponível; usar essa nomenclatura nos imports dos consumidores e testes de ambas as features.
- [x] 1.4 Definir o contrato puro da capacidade nativa no core, incluindo identificador de anexo, geometria opcional de apresentação e falhas, sem BuildContext, RenderBox ou tipos de plugin.

## 2. Leitura própria e serialização CSV

- [x] 2.1 Implementar leitura sequencial de todas as páginas no adapter de exportação de Expense, com proprietário fixado, filtro por PocketBase.filter em toda página e ordenação `occurred_on,id`, sem alterar a consulta da listagem existente.
- [x] 2.2 Tratar identidade ausente/trocada, parsing estrito e ClientException com PocketBaseMapper, sem refresh, limpeza de AuthStore, retry automático ou truncamento do histórico.
- [x] 2.3 Implementar serializador puro com cabeçalho e ordem especificados, categorias pelo enum value, UTF-8/BOM, delimitador `;`, CRLF, data civil e dinheiro formatado exclusivamente por inteiros.
- [x] 2.4 Implementar sanitização de células textuais contra fórmulas e encoding de aspas, delimitadores e multilinha sem modificar as despesas persistidas.
- [x] 2.5 Cobrir leitura/serialização com SDK real e transporte mockado: múltiplas páginas, owner repetido, falha tardia, identidade, AuthStore preservado, parsing inválido, histórico vazio, valores exatos/grandes, datas, categorias e caracteres especiais/fórmulas.

## 3. Compartilhamento e temporários

- [x] 3.1 Implementar adapter nativo com share_plus/path_provider, MIME `text/csv`, nome sem dados pessoais e subdiretório temporário privado, sem permissão ampla de armazenamento ou seletor de pasta.
- [x] 3.2 Implementar descarte de parciais/abandonados e limpeza restrita de exports expirados ao iniciar nova exportação, mantendo anexos compartilhados por 24 horas e sem exclusão imediata no retorno nativo.
- [x] 3.3 Implementar repository coordenador de Settings: preparar somente após leitura completa e não vazia, validar identidade antes de compartilhar e distinguir falha, dismiss e resultado indisponível.
- [x] 3.4 Cobrir coordenação, falhas de arquivo/share, metadados do anexo, nenhuma criação para vazio, descarte após abandono e limpeza por idade sem atingir arquivos ativos ou cache alheio; usar doubles públicos em test/support.

## 4. Bloc, Settings e composição

- [x] 4.1 Implementar novo Bloc com estados sealed, fases explícitas, concorrência droppable/guardas de fase, retry manual e ErrorsEntity original; erros inesperados seguem addError sem payload financeiro.
- [x] 4.2 Cobrir sequências do Bloc, duplicatas durante preparação/compartilhamento, vazio, falhas esperadas/inesperadas, nova exportação após conclusão e fechamento pendente com Completer, sem sleeps ou testes de UI.
- [x] 4.3 Registrar contratos e adapters nos módulos adequados; fornecer o novo Bloc exclusivamente no provide da rota de Settings e preservar a factory/ownership atuais de LogoutBloc.
- [x] 4.4 Adicionar “Exportar despesas” em Conta com “Preparando exportação…”, bloqueio de novos disparos e mensagem de histórico vazio; efeitos de compartilhamento e feedback ocorrem fora do build, com instâncias explícitas.
- [x] 4.5 Coordenar o despacho do compartilhamento apenas com a rota ativa, incluindo âncora pura para iPad quando necessária e descarte se a preparação terminar após saída da rota; atualizar consumidores e previews afetados com ownership externo explícito.
- [x] 4.6 Adicionar testes de DI/rotas sem montar UI, comprovando resolução de Settings isoladamente, disponibilidade do contrato Expense entre features e ausência de bind duplicado do novo Bloc; manter verificações arquiteturais.

## 5. Verificação e documentação

- [x] 5.1 Executar `flutter pub get`, `flutter analyze` e `flutter test`, nessa ordem, incluindo suítes de arquitetura e features afetadas; registrar comandos e bloqueios reais sem enfraquecer testes.
- [ ] 5.2 Verificar manualmente em Android/iOS e iPad aplicável: histórico extenso, compartilhar/cancelar, falha/retry, ausência de dados, saída durante preparação, leitura do anexo pelo destinatário e abertura no Excel brasileiro; registrar o que não puder ser verificado, sem criar testes de UI.
- [x] 5.3 Atualizar README.md e ARCHITECTURE.md com o fluxo implementado, dependência de internet, limite de snapshot paginado, categorias estáveis, temporários e ausência de garantia de entrega; não declarar homologação remota ou build nativo sem execução.
- [x] 5.4 Revisar escopo e privacidade: sem dados de família/perfil, tokens ou payloads nos logs; sem comentários novos no código, wrappers CRUD, alterações de backend, migrações incidentais ou testes visuais.

## Registro de verificação

- `flutter pub get`: concluído; `csv 8.0.0`, `share_plus 13.3.1` e `path_provider 2.1.6` resolvidos sem alterar toolchain nativo.
- `flutter analyze`: sem problemas.
- `flutter test --reporter failures-only`: 1531 testes aprovados, incluindo infraestrutura, Bloc, DI e arquitetura.
- Os testes focados também passaram antes da revisão de nomenclatura; a suíte global acima já inclui os nomes finais e a composição explícita de Settings contra colisões do AutoInjector.
- Tarefa 5.2 permanece pendente: não foram executados build nativo, UI Android/iOS/iPad, aplicativo destinatário real, Excel ou backend remoto. Transporte e canais nativos foram simulados nos testes unitários; isso não substitui conferência manual.
- Diagnóstico posterior no simulador iOS: os logs mostraram preparação concluída e falha na fase de compartilhamento. A inspeção do aplicativo instalado não encontrou o plugin nativo `share_plus`; foi orientado encerrar a execução e recompilar, pois hot reload/restart não incorpora plugins nativos novos. O compartilhamento após recompilação não foi confirmado nesta sessão.
- Arquivamento com a tarefa 5.2 pendente, sincronização da spec, commit e push foram autorizados explicitamente pelo usuário. A pendência permanece aberta como registro de verificação, sem declarar homologação manual concluída.

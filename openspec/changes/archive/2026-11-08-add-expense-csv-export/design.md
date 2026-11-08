## Context

Expense já usa o PocketBase compartilhado, records planos, centavos inteiros e data civil. Seu `get` é paginado e depende atualmente das regras remotas para restringir leitura; não possui filtro explícito de proprietário. Isso não deve virar uma exportação familiar acidental quando as permissões de leitura evoluírem.

Settings possui `LogoutBloc` criado pela screen com factory estável e módulo com path próprio. A exportação é uma nova interação, não autorização para migrar logout ou reorganizar features. As specs históricas de Settings não descrevem integralmente o checkout atual; prevalecem AGENTS.md e ARCHITECTURE.md.

## Goals / Non-Goals

**Goals:** exportar todo o histórico próprio, gerar CSV no aparelho e abrir compartilhamento nativo com UX simples, precisão financeira e tratamento de falhas.

**Non-Goals:** perfil, familiares, métricas, filtros, importação, ZIP, backup restaurável, exportação offline/background, “Salvar como”, endpoint novo, alteração de schema, deploy ou homologação remota nesta tarefa.

## Decisions

### 1. Separar leitura financeira, coordenação e capacidade nativa

Fluxo proposto:

```text
SettingsScreen -> ExportBloc -> contrato de exportação de Settings
                                          |
                             repository de Settings
                                /                 \
                 contrato de exportação Expense    client nativo do core
                              |                    |
                 repository Expense -> SDK    share_plus / path_provider
                              |
                     serialização CSV pura
```

- Expense oferece um contrato específico de exportação em application, implementado em infrastructure com o SDK compartilhado. Ele consulta exclusivamente o proprietário inicial e gera um documento puro com bytes CSV e identidade de origem, sem expor SDK/RecordModel.
- Settings coordena preparação, ausência de dados e compartilhamento por seu próprio contrato/repository. Seu Bloc não recebe PocketBase, clients nativos, arquivos Dart IO ou plugins.
- Core encapsula somente criação/limpeza de temporários e compartilhamento de anexos. Não contém paginação, regras de proprietário ou serialização financeira.
- Os contratos usam `Future<T>`, tipos próprios imutáveis e exceções de aplicação. Não criar wrapper CRUD, data source, command, serviço global ou Either.

Os arquivos dos contratos de exportação usam o nome `interface_export_repository.dart` em ambas as features, sem o prefixo `expense` no nome do arquivo:

```text
lib/features/expense/application/repositories/interface_export_repository.dart
lib/features/settings/application/repositories/interface_export_repository.dart
```

Os diretórios das features distinguem o contrato de geração financeira do contrato de coordenação de Settings. Essa nomenclatura vale também para referências e imports nos consumidores e testes.

Por convenção solicitada, ambos os contratos se chamam `IExportRepository` e ambas as implementações `ExportRepository`; imports conjuntos usam alias. O documento de Expense se chama `DocumentModel`, em `application/models/document_model.dart`. Os demais componentes novos da interação de Settings usam `ExportBloc`, `ExportEvent`, `ExportState` e `PreparedExportModel`, sem repetir o nome da feature.

O AutoInjector utilizado pelo Modular resolve binds pelo nome textual do tipo, não pela identidade Dart da biblioteca. Por isso, somente o contrato de Expense tem bind compartilhado. O `provide` de Settings compõe explicitamente seu `ExportRepository` e o entrega como contrato ao `ExportBloc`, recebendo o contrato compartilhado de Expense e o client nativo por injeção. O repository de Settings pertence à composição da página e não possui bind homônimo concorrente. Essa escolha preserva camadas e ownership sem adicionar wrappers ou alterar o framework de DI.

Alternativa rejeitada: consultar `IExpenseRepository.get` em um laço no Bloc de Settings. Acoplaria paginação e composição financeira à apresentação e não garantiria o filtro próprio sem alterar incidentalmente a listagem existente.

### 2. Paginação própria com identidade fixada

O adapter de Expense captura `pocketBase.userId()` antes da primeira consulta, aplica `owner = {:owner}` por `PocketBase.filter` em todas as páginas e usa ordenação estável `occurred_on,id`. Não aplica filtros de período/categoria nem depende da Dashboard. Começa na primeira página e segue a paginação nativa até o fim; não impõe limite silencioso de registros.

Validar que a identidade continua correspondente antes de novas páginas e ao concluir a preparação. O contrato de Expense também deve permitir validar a identidade de origem imediatamente antes do despacho do compartilhamento; Settings faz essa checagem pelo contrato, nunca lendo AuthStore diretamente. Isso não altera as simplificações do refresh global nem fornece uma transação de sessão. Uma operação já entregue ao sistema não é revogável pelo app.

Usar parsing estrito existente e `PocketBaseMapper` para ClientException, sem transformar parsing inválido em histórico vazio. A leitura não atualiza nem limpa sessão, inclusive em 401. Ausência de identidade segue a exceção compartilhada do core.

Alternativa rejeitada: confiar somente na regra de listagem atual, porque a leitura familiar pode ampliar o conjunto autorizado futuramente.

### 3. CSV brasileiro explícito e testável

Usar `csv` para escaping e codificação de linhas, com `;`, CRLF e UTF-8 com BOM. Cabeçalho: `Identificador;Data;Descrição;Categoria;Valor (BRL)`.

- Data civil em `dd/MM/yyyy`, sem `toLocal`/conversão de fuso.
- Valor calculado por divisão/resto inteiros dos centavos, com duas casas e vírgula, sem `double`, símbolo ou agrupamento.
- Categoria pelo `ExpenseCategoryEnum.value` (`food`, `other`, etc.). É uma decisão técnica para manter o arquivo estável, sem importar labels de presentation; coluna continua em português.
- Sanitização de células textuais antes do encoder contra marcadores de fórmula e caracteres de controle definidos na spec. Apostrofar a representação não modifica dados persistidos.
- Nome sugerido: `cordato-despesas-2026-11-08.csv`, com data da geração e sem nome/e-mail/ID da conta.

O serializador é puro e pertence à infrastructure de Expense. Não reutilizar formatters de UI nem inserir regras de CSV no domínio.

### 4. Dependências pequenas e com finalidade clara

- `csv`: gerar linhas corretas, inclusive campos multilinha.
- `share_plus`: compartilhar o anexo via Android/iOS, sem prometer destino específico ou salvamento durável.
- `path_provider`: localizar temporários privados e controlar o ciclo dos arquivos.

Conferir versões contra Flutter, Java, Kotlin, AGP, Gradle e deployment target iOS reais antes de escolher constraints. Não atualizar todo o toolchain incidentalmente; registrar incompatibilidade caso exija decisão separada. Não usar `file_selector`: o fluxo aprovado é compartilhar, não “Salvar como”.

### 5. Preparação e abertura nativa como fases distintas

O repository de Settings prepara um arquivo e retorna um identificador de anexo puro, sem caminho nativo no estado. Histórico vazio é um desfecho próprio. O Bloc publica estado pronto; um listener da screen ativa solicita a fase de compartilhamento uma única vez. Essa separação evita abrir UI nativa após sair da rota durante uma leitura demorada.

Estados sealed distinguem inicial, preparação, pronto, compartilhando, vazio, conclusão e falha. Disponibilidade deriva dos estados. Usar `droppable` e guardas de fase para descartar disparos concorrentes, inclusive entre preparação e compartilhamento. Desfechos terminais permitem um novo envio manual; não bloquear para sempre após o primeiro sucesso.

O novo Bloc é criado exclusivamente por `provide`/`addBloc` na rota de Settings e recebido explicitamente pela screen, sem fechamento local. O ownership atual do LogoutBloc permanece intacto. Handlers substanciais ficam no mixin específico; efeitos ocorrem em listener, não no build. Se a API nativa precisar da âncora de apresentação no iPad, capturar a geometria na camada visual e atravessar os contratos com um valor puro; nunca transportar BuildContext/RenderBox para Bloc, application ou infrastructure.

Fechar Bloc impede novas emissões e novos efeitos da rota, mas não cancela magicamente HTTP/IO. Arquivos de operações abandonadas precisam de descarte mesmo se não houver consumidor para o retorno. O adapter não inicia sozinho um share sheet como continuação da preparação.

### 6. Arquivos temporários e resultado do compartilhamento

Criar arquivos exclusivamente em subdiretório privado dedicado à exportação. Nunca solicitar acesso amplo ao armazenamento, compartilhar antes de concluir todas as páginas ou criar arquivo para histórico vazio.

Falhas anteriores ao compartilhamento descartam parciais. Arquivos preparados mas não compartilhados devem ser liberados quando abandonados; usar limpeza de stale como fallback para fechamento do processo. Para anexos entregues ao sistema, não apagar imediatamente no retorno do share sheet: o destinatário pode continuar lendo. Manter uma janela de retenção de 24 horas e limpar exports expirados ao iniciar uma nova exportação. Não prometer remoção em horário exato se o app não voltar a executar; cache também pode ser removido pelo sistema. A limpeza nunca percorre/apaga cache fora do diretório dedicado.

Conclusão/dismissal/resultado indisponível reabilitam a ação sem toast de entrega garantida. Exceção de abertura nativa vira falha local com retry. Dados já enviados ao aplicativo escolhido ficam fora do controle de Cordato.

### 7. Verificação sem testes de UI

- SDK real com transporte mockado: paginação, filtro de owner em todas as páginas, ordenação, identidade ausente/trocada, erro tardio, parsing inválido e preservação do AuthStore.
- Serializador: bytes/BOM, CRLF, cabeçalho, datas civis, categorias, centavos extremos/exatos, acentos, delimitadores, aspas, multilinha e proteção contra fórmulas.
- Repository coordenador/client: arquivo vazio não criado, anexo completo, falhas de IO/share, resultados nativos, descarte e limpeza restrita com relógio controlável nos testes.
- Bloc: sequências, duplicidade nas duas fases, retry, ErrorsEntity original, erro inesperado via addError, fechamento com Completer e nenhuma solicitação tardia de compartilhamento.
- DI/arquitetura: Settings resolve isoladamente sem visitar Expense; módulo da feature financeira disponibiliza o contrato entre features sem dependência de rota ativa; novo Bloc pertence ao provide, sem bind duplicado.
- Conferência manual Android/iOS, inclusive iPad, Excel brasileiro e destinatário real. Sem testes de widgets, goldens ou Maestro.

## Risks / Trade-offs

- [Histórico muda enquanto páginas são lidas] → Ordenação determinística e nenhuma mutação pelo fluxo. A API paginada não fornece snapshot transacional; “todo o histórico” significa todas as páginas da consulta, não um backup atômico perante alterações concorrentes. Documentar essa limitação, sem criar backend novo.
- [Históricos grandes consomem memória] → Ler páginas sequencialmente e codificar incrementalmente, evitando materializar todos os ExpenseEntity. Ainda haverá bytes do documento final; medir o uso na implementação, sem truncar silenciosamente ou declarar suporte ilimitado.
- [Compatibilidade de planilhas varia] → Contrato de formato explícito e conferência manual com Excel; CSV não define tipagem universal de células.
- [Share sheet pode não relatar destino/entrega] → Tratar resultado indisponível e cancelamento como retornos normais, sem prometer arquivo salvo.
- [Arquivos financeiros sobrevivem temporariamente no cache] → Diretório privado, retenção/limpeza restrita e nenhuma exposição nos logs; destinatários externos são escolha do usuário.
- [Novo plugin exige toolchain diferente] → Verificar requisitos antes da implementação e não embutir upgrades alheios ao escopo.

## Migration Plan

Mudança aditiva no Flutter, sem migração de dados ou deploy backend. Implementar contratos, adapters, DI e interação de Settings juntos. Atualizar README e ARCHITECTURE quando a funcionalidade estiver implementada, sem antecipar no estado atual do produto. Reversão remove a entrada e seus bindings/adapters exclusivos, preservando despesas e recursos existentes.

## Open Questions

Sem dúvidas de produto pendentes. Compatibilidade das versões dos plugins, uso de memória e funcionamento do compartilhamento nativo precisam de verificação na implementação; esta proposta não comprova build nativo ou homologação.

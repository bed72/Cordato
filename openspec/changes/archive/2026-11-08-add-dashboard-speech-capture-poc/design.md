## Context

O botão em `lib/features/dashboard/presentation/widgets/action_button_dashboard_widget.dart` abre o cadastro por toque simples e recarrega a Dashboard após retorno com despesa confirmada. Esse comportamento permanece. O novo gesto é toque longo no mesmo botão, não um segundo botão e não uma substituição do formulário.

A referência visual está no Expo em `/Users/gabrielramos/Code/Me/Mobile/Expo/cordato/src/features/audio/presentation/record/`: `components/record.tsx`, `components/recording-indicator.tsx` e `hooks/use-recorder-presentation.ts`. Reaproveitar a intenção visual de expansão a partir do botão à direita, superfície arredondada, X, onda e seta; não copiar use cases, Appwrite, limite de 60 segundos ou captura de arquivo. As imagens fornecidas na conversa são a referência visual; o projeto Expo é consulta, não alvo de alterações.

`speech_to_text` 7.5.0 foi a versão estável consultada. O pacote utiliza reconhecedores da plataforma, recomenda frases curtas e inicialização única, e não garante duração contínua. `onDevice` não será exigido: rede pelo serviço nativo é permitida. Revalidar compatibilidade da versão escolhida com o SDK e targets do projeto antes da implementação.

## Goals / Non-Goals

**Goals:**

- Validar captura curta em pt-BR, gesto duplo no botão existente e barra animada em Android/iOS reais.
- Preservar captura ao soltar o dedo e preservar texto quando o serviço encerrar normalmente por silêncio.
- Somente seta confirma a saída de diagnóstico; X, erro e lifecycle descartam.
- Introduzir isolamento mínimo e testável de plugin, repository e Bloc de página.

**Non-Goals:**

- IA, extração de valor/data/categoria, use case de cadastro por áudio, persistência de despesas ou alteração de repositories existentes.
- `record`, arquivo de áudio, upload, transcrição offline obrigatória, HTTP próprio, Dio, Firebase, Workers, Lambda ou Hatchet.
- Reconhecimento contínuo, reinício automático após silêncio, acumulação de várias sessões ou funcionamento em background.
- Migração incidental de DashboardBloc, refatoração global de botões ou testes automatizados de UI.

## Decisions

### 1. Interação no botão existente

Toque curto executa a navegação atual. Toque longo ganha a disputa do gesto e não dispara o toque curto ao soltar. O início expande o botão na posição existente; o dedo pode ser solto e a captura continua. A barra permanece interativa para X e seta após o gesto.

Widgets extraídos serão públicos, finais, com sufixo `Widget`, tema e componentes do core. Ícones usam `IconWidget` e Material; não adicionar biblioteca de animação de ícones. Mixin do State possui animação, lifecycle e eventos visuais; não acessa plugin, repository ou clients. Respeitar SafeArea, largura disponível, textos ampliados e movimento reduzido.

### 2. Separação de responsabilidades e ownership

```text
ActionButtonDashboardWidget / widgets e mixin de captura
                    |
             SpeechBloc
                    |
          ISpeechRepository (Dashboard/application)
                    |
           SpeechRepository (Dashboard/infrastructure)
                    |
          ISpeechRecognitionClient (Core/application/clients)
                    |
           SpeechRecognitionClient (Core/infrastructure)
                    |
               speech_to_text
```

O repository expõe início, término, descarte e observação com tipos próprios, sem tipos do plugin. Eventos de observação indicam preparação, escuta, texto reconhecido, nível sonoro, término normal e falha. A API concreta deve distinguir texto parcial de conclusão do reconhecimento e não presumir que o Future de `stop()` contém o texto final.

O client encapsula uma única instância inicializada do plugin e distribui callbacks somente à captura ativa. O serviço compartilhado não significa estado visual global: o novo Bloc nasce e fecha exclusivamente no `provide` da rota da Dashboard via `addBloc`. Repository e sessão de captura têm ownership definido, sem singleton de Bloc ou acúmulo de observers após revisitas.

DashboardBloc mantém seu ownership e contratos existentes. A POC não chama `IExpenseRepository` nem compartilha seus estados com o novo Bloc. Não adicionar use case que apenas delega chamadas: a orquestração de interpretação/cadastro discutida é uma fase futura, fora desta mudança.

### 3. Máquina de estados e encerramento por silêncio

```text
Idle -> Preparing -> Listening -> Finalizing -> Ready -> Collapsing -> Idle
                         |                      ^
                         +-- silêncio/limite ----+

Preparing / Listening / Ready -- X ou lifecycle --> descarte -> recolhimento
Listening / Ready -- seta --> finalização, se necessária -> recolhimento
```

Os nomes são conceituais. Usar estados sealed para fases mutuamente exclusivas, sem flags locais espelhando o Bloc. A finalização normal sem seta só produz estado pronto; o recolhimento confirmado depende da seta.

Configurar pt-BR a partir dos locales reais do plugin, sem fallback silencioso para outro idioma. Usar modo apropriado para frase curta e limite de escuta de 30 segundos. `pauseFor` e eventos nativos informam o encerramento; não criar detector próprio baseado em amplitude. O sistema pode parar antes do tempo solicitado.

Onda deriva de `onSoundLevelChange`, com amostras limitadas e normalização por plataforma. Ela não representa um arquivo gravado nem prova de fala válida. Ao terminar por silêncio, parar a animação de entrada e manter indicação acessível de que a captura foi concluída e aguarda a seta. Não reiniciar o microfone automaticamente.

Resultados parciais são substituições da hipótese atual, não trechos para concatenar. Ao tocar a seta durante escuta, bloquear novos comandos de envio, solicitar stop e aguardar finalização do reconhecedor. Definir um timeout de finalização de 5 segundos, testável sem sleeps; ausência de conclusão gera falha local e nenhum log de texto parcial. Término normal seguido de seta não solicita outra captura nem duplica stop.

### 4. Seta significa diagnóstico, não envio remoto

Com transcrição final não vazia, a seta conduz ao recolhimento; somente após a animação concluir, um evento de apresentação confirma ao Bloc o término visual da mesma captura. O Bloc delega ao repository a emissão de uma única linha de diagnóstico em debug, sem print na tela nem dependência de logger concreta na apresentação.

Essa confirmação visual deve carregar somente a identidade da operação, não retransmitir texto. Ela é ignorada se duplicada, antiga ou após invalidação. Em movimento reduzido, a conclusão sem animação percorre a mesma regra exatamente uma vez. Fechar/navegar antes da confirmação descarta o diagnóstico.

O repository usa uma saída de diagnóstico testável, com configuração restrita ao debug e à POC; não construir um framework de telemetry. A transcrição não passa por `addError`, observer de Bloc, analytics, crash reporting ou logs HTTP. Nenhum log de parcial, cancelamento, erro ou release contém fala. Remover texto da memória do fluxo ao retornar a Idle ou descartar. Usar apenas frases fictícias na homologação, sem prometer sigilo do console de desenvolvimento.

Essa exceção deliberada às regras gerais de não registrar conteúdo financeiro deve ser documentada de forma estreita em `AGENTS.md` na implementação; não alterar o observer atual. Em release, o gesto pode ser avaliado visualmente, mas não produz log nem efeito financeiro.

### 5. Concorrência, cancelamento e erros

O início e o envio são protegidos contra repetição. A observação contínua não pode bloquear os eventos X/seta; usar handler distinto para observar o stream e definir os transformers por responsabilidade. Nunca aplicar `droppable` globalmente a todos os eventos.

Cada captura tem identidade própria no adapter para descartar callbacks atrasados e proteger a instância seguinte. Cancelamento durante permissão/preparação impede iniciar captura tardia. Fechar Bloc cancela sua observação pelo lifecycle nativo, sem flags de fechamento paralelas nem override de `close()`; a propriedade da sessão no repository/adapter garante liberação do recurso ao terminar a observação. Não confundir encerrar Future de handler com cancelar o microfone.

Perda de rota ativa, background, logout que remove a Dashboard e descarte cancelam e invalidam a captura. Não cancelar apenas porque o diálogo de permissão do SO tornou o app temporariamente inactive; retorno desse diálogo não inicia captura se a operação foi realmente descartada. A seta já em finalização bloqueia nova seta e X; saída de rota continua invalidando a operação e impedindo diagnóstico tardio.

Permissão negada/bloqueada, reconhecedor ou pt-BR indisponível, sessão interrompida e timeout geram exceções esperadas e mensagens locais, formatadas fora do widget. Texto vazio não é sucesso nem exige chamada remota: recolher sem log e informar que nenhuma fala foi reconhecida. Falhas inesperadas usam fallback seguro e `addError` apenas sem conteúdo da transcrição; não encaminhar mensagens nativas potencialmente sensíveis sem sanitização.

### 6. Testes e validação manual

Testes unitários cobrem repository com client mockado, Bloc com repository mockado, mapper/formatter e adapter usando a seam de plataforma do plugin, sem API alternativa de produção só para testes. Doubles públicos ficam em arquivos próprios em `test/support/`. Usar `Completer` e `fake_async` para finalização, callbacks atrasados e tempos.

DI testa resolução da Dashboard isoladamente, ownership de página e unicidade da instância do plugin sem montar UI. Testes arquiteturais preservam apresentação sem plugins/clients e application sem Flutter/SDKs. Previews usam fake sem microfone/rede e ownership externo explícito. Não criar testes de widgets, goldens, Maestro ou integração visual.

Conferência manual verifica a composição inspirada no Expo, toque curto versus longo, seta/X, silêncio, permissões, pt-BR, retorno de background, repetição, microfone liberado e logs debug/release. Registrar aparelho/SO e limites observados; não confundir mocks com homologação nativa.

## Risks / Trade-offs

- Reconhecimento pode usar rede do SO → informar essa possibilidade; nunca apresentar a POC como processamento integralmente local ou sem tráfego.
- Encerramento precoce varia por aparelho → preservar o texto e aguardar seta, sem prometer 30 segundos contínuos.
- Palavras/valores incorretos → avaliar com frases fictícias; não cadastrar despesas nesta POC.
- Callback final pode chegar após stop, cancelamento ou nova captura → identidade de operação, finalização limitada e testes de atraso.
- Console contém texto explícito → somente debug e confirmação da seta, nenhuma telemetry, com exceção documental limitada.
- Inicialização única do plugin retém callbacks → client único roteia eventos para sessão ativa e libera observadores ao sair.
- Gesto longo em botão com bounce pode disputar toque → homologação manual obrigatória preserva abertura única do formulário no toque curto.

## Migration Plan

Não há migração de dados, backend ou credenciais. Implementar dependência e permissões, adapter/contratos, repository/Bloc, DI e composição visual com testes por camada. Executar `flutter pub get`, `flutter analyze` e `flutter test` nessa ordem; registrar builds e verificações manuais separadamente. Atualizar documentos canônicos apenas com o comportamento efetivamente entregue.

Rollback funcional remove a composição de captura e restaura somente o botão atual, depois remove a dependência e permissões exclusivas; não afeta despesas existentes ou sessões PocketBase. Não executar deploy ou operações remotas como parte desta POC.

## Open Questions

Nenhuma decisão de produto bloqueante. Permanecem verificações técnicas: suporte real a pt-BR, comportamento de finalização e permissões na versão escolhida e normalização do nível sonoro em cada plataforma. Registrar limitações encontradas sem introduzir captura paralela com `record` ou serviços externos para contorná-las.

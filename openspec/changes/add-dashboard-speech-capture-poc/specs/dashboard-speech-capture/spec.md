## ADDED Requirements

### Requirement: Preserve short tap and add long press on the existing expense button

O botão existente da Dashboard SHALL preservar toque simples para abrir o formulário de cadastro e atualizar a Dashboard após despesa confirmada. Toque longo no mesmo botão SHALL iniciar o fluxo de reconhecimento sem navegar. Soltar após toque longo MUST NOT disparar toque simples, encerrar a escuta ou confirmar o texto.

#### Scenario: Short tap opens the existing form
- **WHEN** o usuário toca brevemente o botão recolhido
- **THEN** o formulário atual abre uma única vez, com seu contrato de retorno e recarga preservados
- **AND** nenhuma sessão de reconhecimento é iniciada

#### Scenario: Long press starts capture without navigation
- **WHEN** o usuário mantém o botão pressionado até reconhecer toque longo e depois solta
- **THEN** a barra expande e solicita preparação/escuta
- **AND** o formulário não abre e a soltura não envia nem interrompe a captura

### Requirement: Animated capture bar matches the approved interaction

A apresentação SHALL expandir o botão à direita em barra arredondada com X à esquerda, onda de nível sonoro no centro e seta à direita, seguindo as imagens aprovadas e a referência Expo. SHALL preservar tema, SafeArea, acessibilidade, largura disponível e movimento reduzido. O nível sonoro SHALL ter histórico limitado e parar de avançar após encerrar a escuta.

#### Scenario: Active recognition displays live feedback
- **WHEN** o reconhecedor informa escuta e mudanças de nível sonoro
- **THEN** a barra permanece aberta e representa os níveis sem criar arquivo de áudio
- **AND** oferece nomes acessíveis para cancelar e finalizar a captura

#### Scenario: Reduced motion preserves the interaction
- **WHEN** o sistema solicita movimento reduzido
- **THEN** expansão e recolhimento respeitam essa preferência sem impedir seta, X ou conclusão única

### Requirement: Native speech recognition supports short Brazilian Portuguese phrases

A captura SHALL usar somente `speech_to_text`, locale pt-BR disponível no sistema e duração máxima solicitada de 30 segundos. SHALL aceitar encerramento nativo antecipado, sem exigir offline, detector próprio de silêncio ou reinício automático. Indisponibilidade de reconhecimento/idioma SHALL gerar falha local sem fallback silencioso de idioma.

#### Scenario: Normal silence or time limit ends recognition
- **WHEN** o reconhecedor encerra normalmente por silêncio ou limite de duração
- **THEN** a barra continua aberta e preserva o texto final disponível aguardando seta ou X
- **AND** nenhum texto é registrado automaticamente e o microfone não é reiniciado

#### Scenario: Recognition is unavailable
- **WHEN** permissão é negada, o serviço está indisponível ou pt-BR não está disponível
- **THEN** o fluxo mostra mensagem local segura, libera recursos e permite nova tentativa manual
- **AND** não registra fala nem abre o formulário automaticamente

### Requirement: Arrow finalizes recognition before animated dismissal and diagnostic output

A seta SHALL confirmar somente a captura atual. Durante escuta, SHALL solicitar término e aguardar finalização do reconhecedor; com texto já finalizado SHALL reutilizá-lo. O Future de stop MUST NOT ser tratado como transcrição final. Após texto final não vazio, SHALL recolher a barra animadamente e somente depois registrar o diagnóstico uma vez em debug. Repetições e callbacks antigos MUST NOT duplicar a saída.

#### Scenario: Arrow is pressed during recognition
- **WHEN** o usuário toca a seta enquanto a escuta está ativa
- **THEN** o fluxo bloqueia novas confirmações, solicita stop e aguarda a transcrição final
- **AND** recolhe a barra e registra uma única transcrição final após a conclusão visual

#### Scenario: Arrow is pressed after normal recognition completion
- **WHEN** o usuário toca a seta após a captura terminar normalmente por silêncio
- **THEN** o fluxo usa o texto final preservado, recolhe animadamente e registra uma vez
- **AND** não inicia outra sessão de microfone

#### Scenario: No valid final text is available
- **WHEN** o texto final é vazio ou a finalização não conclui em 5 segundos
- **THEN** o fluxo encerra/libera a captura, recolhe e apresenta feedback local apropriado
- **AND** não registra texto parcial nem informa sucesso

#### Scenario: Visual completion is duplicated or invalidated
- **WHEN** uma confirmação de recolhimento é duplicada, pertence a outra captura ou chega após sair da rota
- **THEN** ela não produz diagnóstico adicional ou tardio

### Requirement: Cancel and lifecycle discard capture safely

X SHALL cancelar, descartar texto e recolher a barra sem log de fala. Saída da rota ativa, background ou descarte SHALL invalidar a captura e liberar o microfone/observações, inclusive com permissão ou preparação pendente. Diálogo de permissão temporariamente inactive MUST NOT ser confundido automaticamente com background. Operações de finalização SHALL impedir disputa entre seta repetida e X, preservando cancelamento por lifecycle.

#### Scenario: User cancels an active or completed capture
- **WHEN** o usuário toca X durante preparação, escuta ou espera pela seta
- **THEN** a captura é descartada e a barra recolhe sem diagnóstico de transcrição
- **AND** uma nova captura posterior não recebe texto ou níveis da anterior

#### Scenario: Capture loses route or background ownership
- **WHEN** o usuário sai da Dashboard, o app entra em background ou a rota é descartada
- **THEN** microfone e observações são encerrados e callbacks tardios são ignorados
- **AND** não há log, feedback ou início tardio da captura descartada

#### Scenario: Permission dialog returns normally
- **WHEN** o diálogo de permissão deixa o app temporariamente inactive e retorna com autorização
- **THEN** a preparação continua somente se a Dashboard e a captura ainda estiverem ativas

### Requirement: Diagnostic output is explicit and debug-only

A POC SHALL registrar conteúdo de fala apenas após seta e recolhimento confirmado, em diagnóstico de debug restrito ao fluxo. SHALL NOT registrar transcrições parciais, canceladas, falhas ou conteúdo em release, observer global, analytics, crash reporting ou logs HTTP. SHALL descartar texto transitório ao concluir/cancelar. A exceção de diagnóstico SHALL ser documentada sem autorizar logging financeiro genérico.

#### Scenario: Debug submission produces one diagnostic
- **WHEN** uma captura final não vazia é confirmada pela seta e o recolhimento termina em debug
- **THEN** o diagnóstico recebe o texto final exatamente uma vez
- **AND** o texto não é persistido ou enviado a outro sistema pelo app

#### Scenario: Release submission has no transcript output
- **WHEN** a mesma interação ocorre em release
- **THEN** nenhum log de conteúdo é produzido e nenhuma despesa é criada

### Requirement: Speech integration preserves architectural and ownership boundaries

A apresentação SHALL consumir Bloc e contratos/tipos próprios de aplicação. O Bloc SHALL consumir repository de aplicação, e a implementação SHALL encapsular o client nativo do core. Plugin, permissões, detalhes de plataforma e diagnóstico concreto SHALL permanecer em infrastructure. O plugin SHALL ter uma única instância inicializada por aplicação, sem converter o Bloc em singleton. O novo Bloc SHALL pertencer exclusivamente ao `provide` da Dashboard; o ownership de DashboardBloc SHALL permanecer inalterado.

#### Scenario: Dashboard dependencies resolve independently
- **WHEN** as dependências da rota Dashboard são resolvidas sem visitar outra rota
- **THEN** o Bloc de captura e seu repository estão disponíveis e possuem ownership definido
- **AND** revisitar a página não acumula instâncias inicializadas do plugin ou subscriptions

#### Scenario: Closing during a pending operation
- **WHEN** o Bloc fecha com preparação, observação ou finalização pendente
- **THEN** usa lifecycle nativo para encerrar a observação e o proprietário da captura libera o recurso nativo
- **AND** nenhuma resposta tardia publica estado ou diagnóstico

### Requirement: POC has no AI, audio file or financial side effects

A POC SHALL NOT adicionar `record`, IA, chaves de provedor, Dio, upload, arquivo de áudio, endpoint próprio, serviço intermediário ou criação/alteração de despesas pelo fluxo de fala. SHALL NOT alterar contratos/transportes PocketBase ou `backend/`. SHALL comunicar que o serviço nativo pode usar rede; ausência de upload implementado pelo app MUST NOT ser descrita como garantia de reconhecimento offline.

#### Scenario: Recognition completes without external application actions
- **WHEN** o usuário confirma uma frase reconhecida
- **THEN** somente a saída de diagnóstico debug permitida é executada
- **AND** nenhum repository financeiro, endpoint de IA ou upload é chamado pelo fluxo

### Requirement: Verification separates unit coverage from native acceptance

A implementação SHALL cobrir contratos, adapter, repository, Bloc, concorrência, finalização, diagnóstico, formatter e DI/arquitetura com testes sem montagem de UI. SHALL usar previews sem rede/microfone e homologação manual em Android/iOS reais para gestos, animação, silêncio, permissões e pt-BR. SHALL registrar verificações executadas e bloqueios, sem alegar homologação nativa a partir de mocks.

#### Scenario: Automated verification respects project test policy
- **WHEN** a suíte da mudança é preparada e executada
- **THEN** não há testes de widgets, goldens ou fluxos visuais automatizados
- **AND** testes controlam operações pendentes e tempo sem sleeps arbitrários

#### Scenario: Native acceptance is reported separately
- **WHEN** a POC é avaliada em aparelhos reais
- **THEN** o registro identifica aparelho/SO, reconhecimento de frases fictícias, comportamento de silêncio, microfone liberado e diferenças debug/release
- **AND** qualquer plataforma não verificada permanece explicitamente pendente

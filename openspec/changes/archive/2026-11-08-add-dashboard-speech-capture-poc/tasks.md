## 1. Dependência e contratos

- [x] 1.1 Conferir estado do checkout, regras canônicas, botão/rota/testes da Dashboard e componentes Expo de referência; preservar o toque simples e registrar bloqueios anteriores à tarefa.
- [x] 1.2 Verificar compatibilidade da versão estável de `speech_to_text` com os targets/SDK do projeto, adicionar somente essa dependência de reconhecimento e atualizar o lockfile.
- [x] 1.3 Criar contrato puro `ISpeechRecognitionClient` no core e tipos próprios mínimos para callbacks, estados nativos e falhas, sem expor tipos do plugin.
- [x] 1.4 Criar `ISpeechRepository`, tipos e exceção esperada em application da Dashboard, com operações de início, observação, finalização, descarte e diagnóstico confirmado; não adicionar use case de mera delegação.

## 2. Adapter nativo

- [x] 2.1 Encapsular uma única instância inicializada do plugin em `SpeechRecognitionClient`, com roteamento de callbacks para a captura ativa e sem estado visual global.
- [x] 2.2 Implementar permissão/preparação, seleção de pt-BR disponível, captura de até 30 segundos, eventos de níveis e resultados parciais/finais; não exigir offline ou fallback de idioma.
- [x] 2.3 Implementar stop que aguarda finalização, timeout de 5 segundos, descarte e liberação nativa; invalidar callbacks de operações antigas e cancelamentos durante preparação.
- [x] 2.4 Configurar permissões e declarações Android/iOS estritamente necessárias; textos Android seguem a convenção de recursos do projeto e não introduzem configurações de gravação em background.
- [ ] 2.5 Cobrir o adapter pela seam de plataforma/canal do plugin, incluindo pt-BR ausente, indisponibilidade, permissão, stop antes do texto final, timeout, cancelamento e callbacks tardios, sem montar UI.

## 3. Repository e diagnóstico

- [x] 3.1 Implementar `SpeechRepository` sobre o client nativo, mapeando eventos/falhas para tipos de aplicação e mantendo ownership da sessão associado à observação.
- [x] 3.2 Implementar saída de diagnóstico testável somente em debug e somente para uma captura final confirmada após recolhimento; não alterar observer global ou encaminhar texto à telemetry.
- [ ] 3.3 Cobrir repository/contratos com client mockado: preservação da transcrição final, hipóteses parciais substituídas, término normal sem log, descarte, erros, limpeza e saída debug versus release/configuração desabilitada.

## 4. Estado e coordenação da página

- [x] 4.1 Criar `SpeechBloc`, eventos e estados sealed para preparação, escuta, espera pela seta, finalização, recolhimento e falha, mantendo texto apenas transitoriamente no fluxo.
- [x] 4.2 Definir concorrência por responsabilidade: observação contínua separada de início/seta/X; impedir duplicação sem bloquear cancelamento ou lifecycle.
- [x] 4.3 Coordenar término por silêncio/limite sem recolher automaticamente, seta aguardando texto final e confirmação visual de recolhimento identificada por operação antes do diagnóstico.
- [x] 4.4 Implementar formatter puro com mensagens locais para vazio, permissão, indisponibilidade, idioma, interrupção e timeout; sanitizar falhas inesperadas antes de telemetry.
- [ ] 4.5 Cobrir Bloc e formatter com testes de sucesso, seta após silêncio, parcial/final tardio, vazio, timeout, repetição, retry manual, X, fechamento pendente e confirmação visual antiga/duplicada, usando Completer/fake_async.

## 5. DI e barra animada

- [ ] 5.1 Compor client/repository e registrar somente o novo Bloc no `provide` da rota via `addBloc`; preservar ownership e bindings de DashboardBloc e testar resolução isolada sem UI.
- [x] 5.2 Adaptar o botão existente para toque simples com navegação original e toque longo exclusivo, sem abertura do formulário ao soltar e sem mudar recarga após cadastro confirmado.
- [x] 5.3 Criar widgets públicos e mixin da barra com expansão/recolhimento inspirados no Expo, X/onda/seta, histórico limitado de níveis, tema, SafeArea, acessibilidade e movimento reduzido.
- [x] 5.4 Conectar listener de estado aos efeitos e conclusão visual ao Bloc; impedir efeitos durante build, flags espelhadas e log antes do fim do recolhimento.
- [x] 5.5 Tratar perda de rota ativa, background e descarte, diferenciando o diálogo de permissão temporariamente inactive; cancelar captura sem enviar/logar texto.
- [x] 5.6 Adicionar previews com fakes sem rede/microfone e proprietário externo explícito; preservar testes arquiteturais de imports, camadas e isolamento de contratos sem adicionar testes de UI.

## 6. Documentação e verificações

- [x] 6.1 Atualizar `ARCHITECTURE.md` e `README.md` com arquitetura da POC, limites do serviço nativo, ausência de IA/cadastro e possibilidade de rede pelo reconhecedor.
- [x] 6.2 Documentar em `AGENTS.md` exclusivamente a exceção de transcrição final no console debug após seta, sem autorizar payloads no observer ou logs financeiros genéricos.
- [ ] 6.3 Executar sequencialmente `flutter pub get`, `flutter analyze` e `flutter test`; registrar resultados, conferir `git diff --check` e revisar ausência de alterações em PocketBase/backend ou dependências fora do escopo.
- [ ] 6.4 Homologar manualmente em Android real com frases fictícias: toque curto/longo, soltura, X, seta, silêncio, limite, permissão, interrupção/background, repetição, liberação do microfone e saída debug/release; registrar aparelho/SO e bloqueios.
- [ ] 6.5 Homologar manualmente em iOS real os mesmos cenários, além de texto ampliado/movimento reduzido e retorno do diálogo de permissão; não marcar plataforma não verificada como concluída.

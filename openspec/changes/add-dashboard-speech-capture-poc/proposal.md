## Why

Validar a experiência de captura de frases curtas na Dashboard antes de integrar interpretação por IA ou cadastro por voz. A POC usa reconhecimento nativo por `speech_to_text` e permite avaliar português brasileiro, animação, permissões e lifecycle em dispositivos reais, sem criar infraestrutura HTTP.

## What Changes

- Preservar o toque simples no botão atual de despesa, incluindo abertura do formulário e recarga após cadastro confirmado.
- Adicionar toque longo no mesmo botão para expandi-lo animadamente em uma barra com X, onda sonora e seta, inspirada na implementação Expo indicada pelo usuário.
- Iniciar reconhecimento de fala após permissão e preparação; soltar o dedo não finaliza nem envia.
- Permitir frases de até 30 segundos, sujeitas a encerramento antecipado pelo reconhecedor nativo. Após silêncio ou limite normal, manter a barra aberta com a transcrição preservada até seta ou X.
- Na seta, finalizar a sessão, aguardar o texto final, recolher animadamente e registrar uma única transcrição em diagnóstico exclusivo de debug. X descarta e recolhe sem registrar conteúdo.
- Encapsular o plugin com client nativo do core, repository de aplicação e Bloc de página, sem dependências de infraestrutura na apresentação.
- Não integrar IA, BYOK, `record`, gravação em arquivo, cadastro de despesas, Dio, serviços intermediários ou mudanças no PocketBase.
- Não exigir funcionamento offline: o serviço de reconhecimento do sistema pode usar rede. Nosso código não transmite texto/áudio a endpoints próprios ou de IA.

## Capabilities

### New Capabilities

- `dashboard-speech-capture`: Gesto no botão existente, reconhecimento de frases curtas, barra animada, finalização explícita, diagnóstico de debug, lifecycle e isolamento arquitetural da POC.

### Modified Capabilities

Nenhuma. O comportamento atual de cadastro por toque simples permanece preservado; esta mudança acrescenta uma interação independente.

## Impact

- Dashboard: botão de ação, widgets/mixin de captura e composição da rota para um novo Bloc com ownership pelo `provide`, sem migrar o ownership preexistente de DashboardBloc.
- Core: contrato puro e adapter do reconhecimento nativo; capacidade de diagnóstico explícita e restrita à POC, sem alterar o observer seguro dos Blocs.
- Dependência: `speech_to_text`, com permissões Android/iOS e disponibilidade de reconhecimento em português brasileiro.
- Testes unitários: contratos, repository, adapter, Bloc, formatter, lifecycle e DI/arquitetura; previews e conferência manual, sem testes de UI.
- Documentação de implementação: atualizar `ARCHITECTURE.md`, `README.md` e a exceção de diagnóstico em `AGENTS.md` quando a funcionalidade for implementada. A spec não autoriza logs financeiros genéricos.
- Nenhuma alteração em `backend/`, schema, AuthStore, repositories PocketBase, servidores remotos ou deploy.

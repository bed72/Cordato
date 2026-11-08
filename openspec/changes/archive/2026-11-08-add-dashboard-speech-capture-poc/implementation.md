# Registro da POC

## Arquivamento

Arquivada em 2026-11-08 por solicitação e confirmação explícitas do usuário,
somente como histórico, sem sincronizar a capability para `openspec/specs`.
As sete tarefas de testes/verificação e homologação permanecem desmarcadas.
O arquivamento não representa cobertura automatizada ou aceite nativo concluídos.
Os nomes finais da implementação usam `Speech`, sem o prefixo `SpeechCapture`.

## Organização após as renomeações do usuário

Mantidos `RecognitionClient` e `IRecognitionClient`. Os contratos do core e da
Dashboard agora contêm apenas interfaces; enums, exceções e modelos possuem
arquivos próprios em application. O client separa preparação, seleção de idioma,
callbacks de texto/nível/status e encerramento em métodos nomeados. Sessão e
mapeamento nativo ficam em arquivos próprios de infrastructure, sem novos
services, wrappers ou dependências. Repository, Bloc, mixin e composição da barra
foram revisados para explicitar responsabilidades e usar os novos imports.

As renomeações de Share e as alterações de testes do usuário foram preservadas.
`flutter analyze` passou após a reorganização. Não foram criados ou executados
testes nesta revisão, conforme a restrição já estabelecida para a POC.

Implementados contrato/client nativo, repository, Bloc no provide da Dashboard,
barra animada, toque longo, permissões Android/iOS e fake de preview sem microfone.
O toque curto mantém a navegação e o retorno confirmado do cadastro.

Por ajuste explícito do usuário, o app não configura `pauseFor` nem encerra por
silêncio próprio. A confirmação continua exclusiva da seta. O reconhecedor
nativo ainda pode terminar antecipadamente; isso não envia nem recolhe a barra.

A composição visual foi ajustada diretamente pelos arquivos Expo `record.tsx`,
`recorder-action.tsx`, `recording-indicator.tsx` e `use-recorder-presentation.ts`:
botão recolhido de 48, barra de 56 com raio 20, inset/gap de 8, controles de 40
com raio 12, seta em superfície de texto invertida e onda de barras de 3–28.
Expansão/revelação de 240 ms e transição da onda de 80 ms respeitam movimento
reduzido. A superfície elevada usa as mesmas cores do Expo em claro/escuro.
`flutter analyze` passou após o ajuste. Não houve inspeção visual em aparelho.

O usuário restringiu a entrega a uma POC sem novos testes. Os testes novos desta
sessão foram retirados; os testes preexistentes não foram removidos ou enfraquecidos.
As tarefas de cobertura automatizada e homologação não devem ser dadas como concluídas.

## Verificação

- `flutter pub get`: concluído; speech_to_text 7.5.0 e transitivas.
- `flutter analyze`: sem issues na última execução antes dos ajustes finais de layout.
- Lotes de testes executados antes da restrição do usuário tiveram falhas na
  infraestrutura dos testes novos; não representam uma suíte aprovada. Não foram
  executados novos testes após a restrição.
- Nenhuma alteração no backend/PocketBase, deploy ou integração de IA.
- Android/iOS reais, builds nativos e inspeção visual: não executados.

As tarefas de testes foram dispensadas pelo usuário para esta POC; permanecem
desmarcadas para não representar cobertura inexistente. A change não está
totalmente homologada nem pronta para declarar aceite nativo.

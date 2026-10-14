# Grupo 9 — Mutações nativas de User

## Contratos e consumidores

UpdateUser e UpdateAvatar publicam `UserEntity?`; DeleteUser publica `bool?`.
Todos mantêm `initialValue: null`. O callback específico de cada command adapta
Right para o valor original e Left para `CommandFailureException` com a mesma
ErrorsEntity. Throwable inesperado permanece no canal nativo. Inputs, contracts
de repository e integração HTTP não foram alterados.

EditUser e User usam os novos tipos nos builders. Os builders de mutação continuam
compondo o estado visual sem consumir o retorno, portanto mantêm `onSuccess`.
Efeitos permanecem nos listeners de results, fora do build e sem releitura de
`value`. Erro terminal tem precedência sobre os dados.

## Nome

- Preservados entrada, trim/validação local, `nameFailure`, pointer de name,
  toast e callback injetado de retorno.
- Falha tipada alimenta o campo e os demais erros alimentam toast; lista vazia
  e exceção inesperada recebem fallback localizado.
- O listener é removido do command anterior e religado ao novo em
  `didUpdateWidget`. O singleton não é descartado pela tela. Essa parte do
  lifecycle de EditUser já fica resolvida para a revisão mais ampla do step 11,
  sem encerrar as tarefas dos demais consumidores.

## Avatar

- Timer de dois segundos, escolha temporária, geração local e `avatarUser`
  permanecem estado legítimo da tela.
- O listener exige snapshot terminal com parâmetro igual à seed pendente.
  Somente dados sem erro cuja seed devolvida seja a enviada confirmam sucesso,
  substituem `avatarUser` e limpam a escolha temporária.
- Erro tipado preserva mensagens. Lista vazia, exceção inesperada ou seed não
  devolvida usam fallback; a escolha e o usuário confirmado são preservados.
- Não há retry automático. Regenerar reinicia o prazo; troca de commands,
  descarte e confirmação de exclusão cancelam o timer como anteriormente.

## Exclusão e propriedade

- False permanece dado válido do command e recebe feedback de não confirmação.
  Falha tipada preserva mensagens com fallback para lista vazia; inesperada usa
  feedback genérico. True não introduz navegação na tela.
- Limpeza de storage continua exclusivamente no repository após exclusão remota
  confirmada; AppWidget observa perda de sessão e redireciona.
- O callback de confirmação revalida mounted e as instâncias capturadas de User,
  Avatar e Delete antes de cancelar o timer e iniciar a exclusão.
- UpdateUser e DeleteUser continuam lazy singletons do módulo; a tela remove
  listeners. UserCommand e UpdateAvatar continuam factories descartadas pela tela.
- Os previews existentes continuam compatíveis: seus repositories retornam
  Either, adaptado pelos commands reais. A screen descarta User/Avatar e o wrapper
  descarta Delete, sem descarte duplicado. Não existia preview de EditUser a migrar.

## Evidências

- `flutter analyze`: sem problemas.
- `flutter test --reporter expanded`: 724 testes aprovados.
- `openspec validate align-command-it-presentation-errors --strict`: change válida.
- `git diff --check`: sem problemas.
- A busca de consumidores não encontrou interpretação de Left/Right ou uso de
  `execute.value` nos handlers de User; a adaptação permanece nos commands e
  Either continua nos contracts dos fakes.
- Treze cenários novos nas suítes migradas, além da atualização dos existentes:
  identidade do sucesso, metadata tipada, inputs sem normalização, lista vazia
  após sucesso anterior, retry, erro inesperado, compartilhamento de Future
  ocupado, isolamento e descarte pendente. Avatar conserva seed divergente da
  solicitada para permitir a validação contextual da screen.
- As subscriptions dos testes são removidas e commands manuais descartados;
  nenhuma configuração estática global foi alterada.
- Inspecionados fallbacks vazios, prioridade de erro, effects fora de build,
  timers, callbacks de confirmação e propriedade dos previews. Os testes não
  representam cobertura runtime do State ou de debounce/coalescimento visual.
- `ARCHITECTURE.md` e `AGENTS.md` atualizados. README revisado: produto e execução
  permanecem corretamente descritos, sem necessidade de edição.
- Não houve mudança de dependências, SDKs, domínio, repositories ou data sources,
  nem criação de comentários Dart, harness ou launcher temporário.
- Maestro 9.6 não foi executado nesta etapa. A recusa anterior de outro launcher
  foi respeitada sem nova solicitação. Edição real, autosave, resposta sem seed e
  confirmação de exclusão em dispositivo permanecem sem evidência nova.

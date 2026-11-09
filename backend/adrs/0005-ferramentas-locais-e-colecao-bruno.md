# ADR-0005 — Ferramentas locais e coleção Bruno

- Status: Substituído por ADR-0006
- Data do registro: 2026-11-09
- Escopo: Makefile, coleção HTTP, ambientes e verificação local

## Contexto

Registro histórico: a dependência exclusiva de variáveis de processo não atendeu
ao uso direto da interface Bruno. O [ADR-0006](0006-secrets-nativos-bruno-e-fallback-cli.md)
substitui essa estratégia, preservando Makefile, isolamento e proteções adotados aqui.

Os testes Go não substituem a chamada manual de um endpoint. Precisamos de comandos
reproduzíveis para subir o executável local e de uma coleção versionada para os
recursos existentes, com development e production, sem expor secrets ou executar
operações perigosas implicitamente.

## Decisão

Centralizar comandos no `backend/Makefile` e manter a coleção em `backend/bruno/`.
Usar a CLI Bruno 4 instalada, sem adicionar pacotes Node ao projeto ou runtime.
Manter sandbox safe e validar a sintaxe pelo parser da CLI, com testes offline
para as proteções e E2E local opt-in para requisições reais.

O alvo padrão do Make lista ajuda; o padrão da coleção é development, em loopback.
O comando padrão Bruno consulta somente saúde. Credenciais são carregadas de
process.env com prefixos próprios de cada ambiente; arquivos shell privados são
opcionais e precisam ser selecionados explicitamente. Login/refresh capturam
token/identidade apenas em runtime, sem persistir ou registrar seus valores.

Production exige confirmação exata do domínio. Mutações, e-mails e destrutivos
exigem opt-ins separados. A suíte automática exclui e-mails, destrutivos e demais
operações manuais. Áudio permanece indisponível na configuração de production,
pois o runtime Docker oficial não contém a rota Go customizada.

Na CLI 4.0.0 instalada, o path de `body:file` é lido antes da interpolação. Para
upload parametrizado, criar uma coleção mínima temporária com path resolvido e
removê-la ao terminar, sem copiar o áudio ou valores de secrets. O E2E usa somente
um arquivo sintético temporário e garante que a CLI não passou sem exercer requests.

## Alternativas consideradas

- Somente curl ou testes Go: não oferece coleção navegável, ambientes e contratos
  reutilizáveis para testes manuais.
- Credenciais e tokens persistidos nos `.bru`: facilitaria vazamento e mistura de sessões.
- Executar toda a coleção por padrão: dispararia mudanças de conta, e-mails ou exclusões.
- Sandbox developer para ler o arquivo em scripts: ampliaria acesso ao filesystem
  desnecessariamente; a coleção temporária permite usar o envio binário nativo.
- Alterar a CLI instalada ou exigir atualização: mudaria ferramentas externas sem
  autorização e não validaria a configuração disponível no checkout atual.

## Consequências

- As ferramentas exigem Node.js, Bruno e Make apenas no desenvolvimento; ShellCheck
  é necessário para o agregado de verificações dos scripts.
- Existe preparo privado de credenciais e necessidade de conta verificada no banco
  manual; não há bypass de verificação/MFA nem provisionamento implícito.
- A suíte automática altera dados quando explicitamente autorizada, não é idempotente
  e não exclui automaticamente despesas criadas.
- E-mails/destrutivos ficam disponíveis apenas para seleção manual com opt-ins.
- O E2E não usa ambientes reais e não comprova SMTP real, mídia válida, Flutter ou deploy.
- A compatibilidade de path de upload deve ser revista em atualizações da CLI;
  não remover o workaround sem testar o envio real de arquivo.

## Referências

- [Uso manual e variáveis](../bruno/README.md)
- [Makefile](../Makefile)
- [Estratégia de testes](../tests/README.md#coleção-bruno-e-tooling)
- [ADR-0003](0003-isolamento-de-testes-por-fronteira.md)

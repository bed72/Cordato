# ADR-0007 — Requests declarativas e pré-requisitos

- Status: Substituído por ADR-0008
- Data do registro: 2026-11-09
- Complementa: ADR-0006
- Escopo: payloads, pré-envio e cobertura da coleção Bruno

## Contexto

A coleção continha bodies vazios ou com JSON incompleto, compensados por scripts
que substituíam o payload. Isso ocultava o contrato e ignorava edições na interface.
O resolvedor também lia Secrets de todas as operações, embora cada request
precisasse apenas de algumas entradas. Testar só a suíte automática não cobria
os scripts das requests manuais, especialmente cadastro, reset e exclusões.

## Decisão

- Cada request declara `requiredInputs` em Vars e pré-requisitos/permissões em Docs.
- Resolver apenas essas entradas privadas e permissões da operação, mantendo os
  bloqueios independentes de escrita, e-mail, destrutivos e production.
- O JSON válido e visível no Body é a fonte do payload. Um resolvedor compartilhado
  trata placeholders por valor, preservando caracteres de credenciais e literais
  editados; scripts de request não o substituem por um payload escondido.
- Placeholders monetários geram inteiros seguros. Valores literais de testes
  negativos são preservados para que a validação realmente exercite o campo.
- `{}` é intencional apenas na tentativa negativa de criar record na view Metrics.
  A geração de bytes dos testes de limite de áudio permanece como exceção documentada.
- Validar JSON, pré-requisitos e documentação estaticamente. Executar scripts de
  todas as requests offline, incluindo campos ausentes e permissões.
- Acrescentar cadastro com conta fictícia ao E2E isolado, sem e-mail ou mudança
  nos filtros da suíte comum. Não executar e-mails/destrutivos para testar esses scripts.

## Alternativas consideradas

- Pedir ao usuário preencher todos os Secrets: mistura pré-requisitos e não resolve
  o contrato oculto dos bodies.
- Remover os opt-ins de escrita: tornaria uma coleção inteira perigosa de executar.
- Apenas corrigir cadastro: deixaria o mesmo problema em recuperação, perfil e despesas.
- Validar requisições manuais diretamente em ambiente existente: introduziria efeitos
  desnecessários; scripts offline e o banco E2E descartável cobrem essas fronteiras.

## Consequências

- A interface mostra o payload e os pré-requisitos de cada operação.
- Edições literais não são silenciosamente substituídas por defaults de script.
- Falhas de JSON e entradas ausentes têm mensagens locais sem refletir credenciais.
- A cobertura de scripts manuais não comprova SMTP real, efeitos destrutivos ou UI
  desktop. Essas limitações continuam explícitas nas evidências.

## Referências

- [Guia Bruno](../bruno/README.md)
- [Estratégia de testes](../tests/README.md)
- [ADR-0006](0006-secrets-nativos-bruno-e-fallback-cli.md)

# Design

## Context

Veja proposal.md. O schema existente usa IDs sequenciais String e não contém
created ou owner. A composição já fornece ToStore aberto; módulos não o fecham.

## Goals / Non-Goals

**Goals:** preservar contratos de CRUD, paginação e UI onde possível, usando
queries nativas; retirar identidade dos contratos de exportação e de Settings.

**Non-Goals:** Metrics, ownership novo de Blocs, importação de dados remotos,
backup restaurável, alterações nativas e garantia de snapshot da exportação.

## Decisions

- Usar o SDK diretamente, sem adapter genérico de CRUD. Falhas esperadas são
  mapeadas em helper específico de Expense compartilhado pelos dois repositories.
- Normalizar datas pelos componentes year/month/day para ISO UTC à meia-noite,
  sem toUtc. Descrição nula do schema vira texto vazio na projeção para preservar
  contratos/UI existentes; tipos não nulos incorretos continuam erros de parsing.
- O SDK 3.6.3 aplica trim nativo em campos textuais. O repository delega a entrada
  sem normalização própria e não altera o schema ou codifica texto para contornar
  o motor; esse limite é documentado e coberto por testes com banco real.
- Paginação usa offset e limite mais um, evitando count separado e preservando
  nextPage. Ordenação aceita os campos locais conhecidos e acrescenta ID como
  desempate. Padrão: occurred_on e ID decrescentes.
- O LIKE do SDK é case-sensitive. Sugestões percorrem lotes de 100 ordenados por
  data e ID e aplicam contains literal com lowercase até 30 correspondências antes
  da deduplicação. Isso evita coluna de busca/migração incidental; a memória fica
  limitada por lote, mas a busca pode percorrer todo o histórico.
  Sem created, o ID sequencial desempata despesas da mesma data.
- Escritas verificam hasErrors e ausência de registros afetados. Atualizações
  enviam apenas campos fornecidos, sem snapshots ou read-modify-write.
- CSV consulta histórico local em ordem crescente e preserva serializer,
  tratamento de fórmulas, compartilhamento e retenção de anexos. Não transporta
  owner fictício nem mantém validateOwner como operação vazia.

## Risks / Trade-offs

- [Mutação durante paginação] → ordenação determinística, sem prometer snapshot
  ou completude transacional entre páginas.
- [Falha após escrita antes da releitura] → não publicar sucesso ou retry
  automático; efeitos confirmados do banco não são desfeitos.
- [Legado fora do escopo] → registrar análise/suíte global sem apagar testes
  de áudio/PocketBase nem migrar Metrics.

## Migration Plan

Usar schema já registrado sem recriação, limpeza ou migração de dados remotos.
Validar reabertura do mesmo diretório. Mudança de código não executa deploy.

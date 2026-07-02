# Gastos — domínio

O gasto é o **fato atômico** do domínio: algo que aconteceu, numa data, por um valor, para uma pessoa.
Este documento descreve as regras de domínio do gasto e o motivo, em profundidade, de ele nunca apontar
para um orçamento.

---

## O gasto

Um gasto pertence a exatamente uma pessoa. Tem um valor exato (sempre maior que zero — um gasto de valor
zero ou negativo não é um gasto, é outra coisa), a data em que **efetivamente aconteceu** e,
opcionalmente, uma descrição livre.

A data do gasto é a data em que o dinheiro foi de fato gasto no mundo real — não necessariamente a data
em que a pessoa lembrou de registrar aquele gasto no sistema. Alguém pode anotar hoje um gasto que
aconteceu há três dias; o que importa para todo o resto do domínio é sempre a data em que aconteceu, não
a data em que foi digitado.

---

## Por que um gasto nunca aponta para um orçamento

Esta é a decisão de modelagem mais importante de todo o domínio, e vale explicar em profundidade o
porquê.

A alternativa óbvia seria: quando alguém registra um gasto, perguntar "isso pertence a qual orçamento?"
e guardar essa ligação. Mas essa ligação criaria uma dependência de manutenção permanente — toda vez que
um orçamento fosse editado (as datas mudarem), apagado, ou um novo orçamento fosse criado cobrindo um
período que antes não tinha nenhum, alguém precisaria voltar em todos os gastos afetados e atualizar (ou
remover) essa ligação. Esquecer de fazer essa atualização deixaria gastos **órfãos** (apontando para um
orçamento que não existe mais), gastos **presos ao orçamento errado** (depois que as datas do orçamento
mudaram), ou pior: um gasto contado em dois lugares ao mesmo tempo.

A solução adotada evita essa classe inteira de problema: um gasto simplesmente registra o fato bruto
(quem, quanto, quando), e o pertencimento a um orçamento é uma **pergunta respondida na hora**, nunca um
dado guardado. "Este gasto cai dentro deste orçamento?" é resolvido comparando a data do gasto com o
intervalo do orçamento, toda vez que alguém precisa saber. Isso significa que editar as datas de um
orçamento, apagar um orçamento ou criar um orçamento novo **nunca exige tocar em nenhum gasto existente**
— o conjunto de gastos que "pertence" a um orçamento simplesmente muda de resposta na próxima vez que
alguém perguntar, sem que nada precise ser reescrito.

Um gasto que não cai em nenhum orçamento vivo de sua pessoa não é um erro nem um dado corrompido — ele
aparece agrupado na visão de "orçamento padrão", que existe justamente para isso.

---

## A verdade-base dos números derivados

Como o gasto é o único registro bruto envolvido (não há nada "abaixo" dele), ele é a fonte de onde todo
número derivado de orçamento nasce: quanto foi gasto dentro de um orçamento específico, o quanto resta,
e até o panorama de gastos do casal são, em última instância, somas e filtros sobre o mesmo conjunto de
fatos brutos registrados aqui. Nenhum desses números vive fora deste contexto — eles são sempre
recalculados a partir daqui, nunca copiados ou sincronizados para outro lugar.

---

## Os gastos do casal

Quando duas pessoas estão pareadas, a visão compartilhada de gastos é a união simples dos gastos dos
dois, cada um marcado como pertencente a um lado ou ao outro. Não existe um "gasto do casal" com
identidade própria — todo gasto continua pertencendo exatamente à pessoa que o registrou; a visão de
casal apenas os apresenta lado a lado.

---

## O que este contexto deliberadamente não faz

- **Não conhece orçamentos.** Não existe, em nenhum lugar deste contexto, uma referência a um
  orçamento específico — o relacionamento é unidirecional: outros contextos perguntam a este pelos
  gastos de um intervalo, este nunca pergunta a ninguém sobre orçamentos.
- **Não reescreve o passado.** Uma vez registrado, o fato bruto (quem, quanto, quando) não muda de
  significado por causa de decisões tomadas depois em outro contexto.

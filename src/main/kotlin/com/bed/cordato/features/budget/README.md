# Orçamentos — domínio

O orçamento é um **teto planejado**: uma pessoa reserva um valor para um intervalo de datas. Este
documento descreve as regras de domínio do orçamento e das visões computadas em cima dele.

---

## O orçamento

Um orçamento pertence a exatamente uma pessoa. Tem um valor exato, uma data de início e uma data de fim
— ambas incluídas no intervalo, sem hora envolvida — e, opcionalmente, uma anotação livre para a pessoa
se lembrar do porquê daquele orçamento existir.

Um orçamento **não guarda nenhuma lista de gastos**. Quanto já foi gasto dentro dele, e quanto ainda
resta, nunca são valores armazenados — são sempre recalculados a partir dos gastos que caem dentro do
intervalo, no momento em que alguém pergunta. Isso significa que esses números nunca ficam
desatualizados: não existe cenário em que o orçamento "esqueceu" de contar um gasto recente, porque ele
nunca guardou a contagem para começar.

---

## A invariante de não-sobreposição

Duas pessoas diferentes podem ter orçamentos com datas idênticas ou sobrepostas sem problema nenhum —
não há relação nenhuma entre os orçamentos de pessoas diferentes. Mas **a mesma pessoa nunca tem dois
orçamentos vivos que compartilhem sequer um único dia**, nem mesmo o dia de fronteira: um orçamento que
termina no dia 15 e outro que começa no dia 16 do mesmo mês coexistem sem problema; um que termina no
dia 15 e outro que começa também no dia 15 já é uma sobreposição e é recusado.

Essa regra existe para que "o orçamento ativo de uma pessoa hoje" seja sempre uma pergunta com resposta
única e inequívoca — nunca "qual dos dois orçamentos vale?". Um orçamento removido (mesmo que de forma
recuperável) deixa de contar para esta checagem — só orçamentos vivos disputam espaço entre si.

---

## O orçamento ativo

A visão mais usada do dia a dia: o orçamento vivo cujo intervalo contém a data de hoje, já acompanhado
de quanto foi gasto dentro dele e de quanto ainda resta (que pode ser negativo, se o orçamento foi
estourado — um valor negativo aqui é uma informação legítima, não um erro). Essa visão nunca existe
guardada; é montada no momento em que é pedida, a partir do orçamento vivo correspondente e da soma dos
gastos daquele intervalo.

Se a pessoa não tem nenhum orçamento vivo cobrindo o dia de hoje, simplesmente não existe um orçamento
ativo — e é aí que a visão de "orçamento padrão" abaixo entra.

---

## O orçamento padrão ("sem orçamento")

Um agrupamento fabricado, não um orçamento de verdade: reúne os gastos de uma pessoa que não caem em
nenhum orçamento real e vivo dela. Existe para que nenhum gasto fique sem lugar nenhum para aparecer nas
telas da pessoa — mesmo um gasto feito num período sem orçamento planejado continua visível, só que
agrupado à parte.

---

## O orçamento do casal

Quando duas pessoas estão pareadas, surge um panorama combinado: um intervalo que vai do início mais
cedo ao fim mais tarde entre os orçamentos dos dois, um valor somado, e um gasto somado. É uma
aproximação proposital, não uma soma exata e granular — a verdade fina continua vivendo nas visões
individuais de cada pessoa. Este panorama nunca é uma entidade própria com identidade e ciclo de vida —
é sempre recalculado a partir dos orçamentos reais dos dois indivíduos daquele par.

---

## O que este contexto deliberadamente não faz

- **Não sabe nada sobre gastos individuais.** Pede apenas um total somado, num intervalo, de uma pessoa
  — nunca enxerga um gasto específico nem a lista deles.
- **Não guarda nenhuma das visões computadas.** Orçamento ativo, orçamento padrão e orçamento do casal
  são sempre projeções momentâneas, nunca linhas persistidas.

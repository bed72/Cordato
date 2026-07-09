# Identidade — domínio

A pessoa é a **âncora** de tudo no sistema: todo orçamento, todo gasto, todo par pendura da identidade
de alguém. Este documento descreve as regras de domínio de quem essa pessoa é e como ela entra e sai do
sistema.

---

## A pessoa

Uma pessoa tem um e-mail (único em todo o sistema — não podem existir duas pessoas com o mesmo e-mail
simultaneamente), um nome e uma senha. Nasce sempre com status **ativa**; o único jeito de se tornar
**apagada** é passar pelo ciclo de exclusão de conta — não existe um caminho intermediário.

A senha nunca é guardada da forma como foi digitada. É armazenada apenas como um resultado que resiste
a tentativas automatizadas de adivinhação e que não pode ser revertido de volta ao valor original. Uma
senha é considerada aceitável apenas se cumprir uma política mínima de robustez — o suficiente para
dificultar adivinhação, sem exigir requisitos que a pessoa não consiga cumprir de forma razoável.

---

## Entrar no sistema

Cadastrar-se exige um e-mail que ainda não esteja em uso, um nome válido e uma senha que cumpra a
política mínima. Essas três checagens são independentes entre si — nenhuma depende do resultado da
outra — mas a unicidade do e-mail é verificada **antes** de qualquer processamento mais custoso sobre a
senha, já que não faz sentido pagar esse custo para um cadastro que vai ser recusado de qualquer forma.

Autenticar-se prova que uma pessoa é quem diz ser, e abre uma sessão em nome dela — ver o conceito de
sessão no domínio compartilhado. Encerrar a sessão é uma ação simples e sempre disponível, sem
pré-condição.

---

## Editar o próprio nome

Depois de cadastrada, uma pessoa pode corrigir o **próprio nome** — o único campo mutável e não-sensível
do perfil. A operação exige uma sessão viva e altera **apenas** o nome: o e-mail, a senha e o status
permanecem exatamente como estavam. O novo nome precisa ser válido pela mesma regra do cadastro (a
autoridade única do que é um nome aceitável), e uma pessoa só edita o próprio nome, nunca o de outra.

Se a sessão estiver viva mas a pessoa já não estiver mais ativa (uma corrida com a exclusão de conta), a
edição é recusada com a **mesma** resposta neutra de autenticação que uma sessão ausente ou inválida
produz — a recusa nunca revela que a sessão apontava para uma pessoa que deixou de existir.

---

## Trocar o próprio e-mail

O e-mail é diferente do nome: é o identificador de login e o canal de recuperação, então é um campo
**sensível**. Por isso, trocá-lo é uma operação de confirmação (step-up) — exige uma sessão viva **e** a
confirmação da **senha atual** naquele momento, como a exclusão de conta já exige, e nunca apenas uma das
duas provas. A troca altera **apenas** o e-mail: o nome, a senha e o status permanecem exatamente como
estavam, e uma pessoa só troca o próprio e-mail, nunca o de outra.

O novo e-mail precisa ser válido pela mesma regra do cadastro (a autoridade única do que é um e-mail
aceitável) e continuar **único** em todo o sistema — não pode ser o e-mail que já pertence a outra pessoa.
Trocar para o e-mail que a própria pessoa **já tem** não é conflito: é um sucesso sem efeito.

A recusa nunca vira uma ferramenta de descoberta de contas: um e-mail já em uso é recusado de forma
genérica, sem revelar que aquele endereço está cadastrado nem ecoar o valor tentado. E uma senha de
confirmação incorreta produz **a mesma** resposta neutra de autenticação que uma sessão ausente ou uma
sessão viva cuja pessoa deixou de estar ativa (uma corrida com a exclusão de conta) — de fora, esses
casos são indistinguíveis entre si, e a recusa nunca revela qual fator falhou.

---

## Trocar a própria senha

A senha é o segredo que autentica todas as outras operações, então é o campo **mais sensível** depois da
própria conta. Trocá-la é uma operação de confirmação (step-up) — exige uma sessão viva **e** a
confirmação da **senha atual** naquele momento, nunca apenas uma das duas provas. A troca altera
**apenas** a senha: o nome, o e-mail e o status permanecem exatamente como estavam, e uma pessoa só troca
a própria senha, nunca a de outra.

A nova senha precisa cumprir a mesma política mínima do cadastro (a autoridade única do que é uma senha
aceitável) — e como o tamanho mínimo é uma **regra pública**, uma senha fraca é recusada de forma
específica, dizendo abertamente o que faltou, sem que isso revele nada sobre ninguém. A nova senha também
precisa ser **diferente da atual**: trocar para a mesma senha não é um sucesso sem efeito, é uma recusa
específica (não faz sentido "trocar" para o que já se tem e ainda assim encerrar as outras sessões).

Trocar a senha é o gatilho clássico de comprometimento, então, ao concluir, **todas as demais sessões
vivas da pessoa são encerradas** — quem quer que estivesse logado em outro lugar precisa entrar de novo.
A **sessão que fez a troca continua válida**: quem acabou de rotacionar a senha ali não é deslogado do
próprio dispositivo. O encerramento das outras sessões só acontece depois que a nova senha foi de fato
gravada; se a gravação falhar, nenhuma sessão é tocada.

Como nas demais operações do contexto, a recusa por senha atual incorreta produz **a mesma** resposta
neutra de autenticação que uma sessão ausente ou uma sessão viva cuja pessoa deixou de estar ativa — de
fora, indistinguíveis entre si, sem revelar qual fator falhou.

---

## Não vazar a existência de uma conta

Um dos cuidados mais específicos deste contexto: nunca dar a quem está de fora uma forma de descobrir
se um e-mail está ou não cadastrado. Um erro de "e-mail já em uso" nunca ecoa qual e-mail foi tentado, e
uma falha de autenticação nunca revela se o problema foi o e-mail (inexistente) ou a senha (errada) —
ambos os casos parecem idênticos de fora. Isso não é um detalhe cosmético: é o que impede alguém de usar
o próprio formulário de cadastro ou de login como uma ferramenta de descoberta de contas alheias.

Em contraste, uma regra pública (como o tamanho mínimo de senha) pode ser dita abertamente — não revela
nada sobre nenhuma pessoa específica.

---

## Apagar a conta

A única operação genuinamente destrutiva e irreversível de todo o sistema começa aqui, ainda que seus
efeitos se estendam a tudo o que a pessoa possui. Ela só pode acontecer com uma sessão viva **e** a
confirmação da senha naquele momento — nunca uma das duas provas sozinha.

O que acontece, como uma única operação atômica (tudo ou nada — não existe estado intermediário visível
entre o início e o fim):

1. a sessão daquela pessoa é invalidada;
2. a senha informada é conferida contra o que está guardado;
3. todos os orçamentos e gastos que pertencem à pessoa são removidos de forma definitiva;
4. o e-mail original é neutralizado — deixa de poder ser usado para entrar no sistema, mas o registro
   histórico continua identificável para fins de auditoria — e fica livre para ser usado num cadastro
   novo;
5. o status da pessoa passa a **apagada**;
6. se a pessoa estivesse pareada, esse par é desfeito como consequência direta.

Reaproveitar aquele e-mail depois **cria uma pessoa nova e independente** — em nenhuma hipótese isso
"reabre" ou ressuscita a conta apagada. A conta apagada e a conta nova não têm relação nenhuma entre si
além de, em algum momento, terem usado o mesmo endereço de e-mail.

---

## O que este contexto deliberadamente não decide

- **Não é dono de dinheiro.** Nenhum orçamento ou gasto mora aqui — eles apenas referenciam a pessoa
  pelo identificador dela.
- **Não decide o que acontece com um par.** A dissolução de um par por consequência da exclusão de conta
  é um efeito, não uma regra que este contexto possui — quem possui essa regra é o pareamento.

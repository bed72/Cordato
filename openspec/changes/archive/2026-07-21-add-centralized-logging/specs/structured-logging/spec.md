## ADDED Requirements

### Requirement: LoggerPort é o único ponto de log fora do domínio

O sistema SHALL prover um port único (`LoggerPort`, em `core`) com quatro operações por nível —
`debug`, `info`, `warn`, `error` —, cada uma recebendo um nome de componente (`component: String`), uma
mensagem (`message: String`) e atributos estruturados opcionais; `error` SHALL também aceitar uma causa
(`cause: Throwable?`) opcional. `domain/` SHALL NOT logar. `application/` e `infrastructure/` (incluindo
adapters, filtros HTTP e exception handlers) SHALL logar exclusivamente através de `LoggerPort` — nenhum
desses pacotes SHALL importar uma biblioteca de log concreta (ex.: `org.slf4j`) diretamente.

#### Scenario: Use case loga através do port

- **WHEN** um use case em `application/` precisa registrar um evento
- **THEN** ele invoca `LoggerPort` recebido por construtor
- **AND** nenhum import de `org.slf4j` ou de qualquer outra lib de log aparece no arquivo do use case

#### Scenario: Domínio nunca loga

- **WHEN** qualquer arquivo sob um pacote `domain/` é inspecionado
- **THEN** ele não referencia `LoggerPort` nem qualquer biblioteca de log

#### Scenario: Chamada solta existente migra para o port

- **WHEN** o handler de falha inesperada (`UnexpectedFailureExceptionHandler`) registra uma falha
- **THEN** ele o faz através de `LoggerPort` recebido por construtor, não mais via
  `org.slf4j.LoggerFactory` direto

### Requirement: Atributos de log são estruturados e de tipo restrito

Os atributos passados a qualquer operação de `LoggerPort` SHALL ser um mapa de nome de atributo para
`LoggableValueObject` — um tipo fechado que aceita apenas texto, número, booleano ou instante — e NÃO um tipo
aberto (`Any?`) que permitiria passar uma entidade ou value object inteiro por engano.

#### Scenario: Atributo primitivo é aceito

- **WHEN** um chamador loga com `attributes = mapOf("person_id" to LoggableValueObject.Text(id))`
- **THEN** a chamada compila e o atributo é registrado

#### Scenario: Objeto de domínio inteiro não pode ser passado como atributo

- **WHEN** um chamador tenta logar passando uma entidade ou value object diretamente como valor do mapa de atributos (ex. `"person" to person`)
- **THEN** o código NÃO compila — `LoggableValueObject` não tem um construtor implícito a partir de tipos de domínio arbitrários

### Requirement: Dados sensíveis são mascarados antes de chegar ao destino do log

O adapter que implementa `LoggerPort` sobre a biblioteca de log concreta SHALL manter uma lista fixa de
nomes de atributo considerados sensíveis (incluindo, no mínimo, `password`, `token`, `email`,
`authorization`, `secret`) e SHALL mascarar ou hashear o valor associado a qualquer atributo cujo nome
bata (comparação insensível a maiúsculas/minúsculas) com essa lista, antes de emitir o registro de log —
independentemente de o valor já estar restrito por `LoggableValueObject`.

#### Scenario: Atributo com nome sensível é mascarado

- **WHEN** um chamador loga com um atributo de nome `password` (ou `token`, `email`, `authorization`, `secret`)
- **THEN** o valor efetivamente emitido no destino do log é mascarado ou hasheado, nunca o valor original em texto claro

#### Scenario: Atributo comum não é afetado

- **WHEN** um chamador loga com um atributo de nome que não bate com a lista sensível (ex.: `person_id`, `status`)
- **THEN** o valor é emitido sem alteração

### Requirement: Um binding SLF4J real existe e emite log

O build SHALL declarar uma implementação real de SLF4J (`logback-classic`) como dependência de runtime,
de modo que uma chamada a qualquer operação de `LoggerPort` produza saída observável — não caia no logger
NOP da SLF4J.

#### Scenario: Log é observável em runtime

- **WHEN** a aplicação está rodando e `LoggerPort.info(...)` é invocado
- **THEN** uma linha de log correspondente aparece no destino configurado (console), com nível, componente, mensagem e atributos

### Requirement: A arquitetura barra import direto de biblioteca de log fora do adapter

O teste de arquitetura (Konsist) SHALL barrar qualquer import de `org.slf4j` (ou de outra biblioteca de
log concreta) em arquivos sob `domain/` ou `application/`, na mesma forma das checagens já existentes
para bibliotecas de persistência e de DI.

#### Scenario: Import de SLF4J em application é barrado pela arquitetura

- **WHEN** um arquivo sob um pacote `application/` importa `org.slf4j.*`
- **THEN** o teste de arquitetura falha

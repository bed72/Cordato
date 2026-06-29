## ADDED Requirements

### Requirement: HTTP integration tests via TestClient contra o app real

Os testes de integração HTTP da aplicação SHALL usar `litestar.testing.TestClient` instanciado com `build()`
— o composition root que retorna um app Litestar fresco. Cada test ou bloco `with TestClient(build())` MUST
partir de um estado zerado: repositórios in-memory são singletons do app criados pelo factory, portanto um
novo `build()` garante isolamento total entre testes sem qualquer fixture de setUp/tearDown. Requests que
dependem de estado acumulado (ex: sign-up → sign-in) MUST ser feitos dentro do mesmo `with` block. Os testes
SHALL viver em `tests/<ctx>/integrations/` e seguir a convenção de um arquivo por fluxo HTTP testado.

#### Scenario: Cada teste parte de repositórios vazios

- **WHEN** um teste instancia `TestClient(app=build())` em um novo `with` block
- **THEN** todos os repositórios in-memory do app estão zerados — nenhum dado de outro teste é visível

#### Scenario: Requests sequenciais no mesmo bloco compartilham estado

- **WHEN** dois requests são feitos dentro do mesmo `with TestClient(build()) as client`
- **THEN** o segundo request enxerga o estado persistido pelo primeiro (ex: usuário criado no sign-up é encontrado no sign-in)

### Requirement: Verificação do envelope de erro unificado nos integration tests

Os HTTP integration tests SHALL verificar não apenas o status HTTP, mas também a conformidade com o envelope
de erro unificado `{status, code, message}`. Erros de domínio MUST ser verificados sem o campo `errors`
(deve estar ausente). Erros de validação (422) MUST incluir `errors` com `key` e `message` por campo. A
`message` MUST estar em pt-BR. Nenhum teste SHALL aceitar a shape de erro como "qualquer objeto com status".

#### Scenario: Erro de domínio não inclui campo errors

- **WHEN** um request dispara um erro de domínio (ex: email duplicado → 409)
- **THEN** a resposta contém `status`, `code` e `message` em pt-BR, e `errors` está ausente no body

#### Scenario: Erro de validação inclui detalhe por campo

- **WHEN** um request possui campo com tipo inválido (ex: `amount: true` em vez de decimal)
- **THEN** a resposta é 422 com `code: "validation"`, `message: "Dados inválidos."` e `errors` com ao menos um objeto `{key, message}` identificando o campo ofensor

#### Scenario: Mensagem de erro nunca é o texto inglês do framework

- **WHEN** um request tem JSON sintaticamente inválido
- **THEN** a resposta é 400 com `message` em pt-BR (ex: `"Requisição inválida."`) — nunca o `detail` em inglês do parser do Litestar

### Requirement: Nenhuma senha ou hash exposto nas respostas HTTP

Os integration tests SHALL verificar explicitamente que o campo `password` não aparece em nenhum nível da
resposta de sign-up ou sign-in — nem no objeto raiz nem no sub-objeto `person`.

#### Scenario: Sign-up não vaza a senha nem o hash

- **WHEN** um sign-up bem-sucedido é feito
- **THEN** a resposta 201 não contém o campo `password` nem no body raiz nem dentro de `person`

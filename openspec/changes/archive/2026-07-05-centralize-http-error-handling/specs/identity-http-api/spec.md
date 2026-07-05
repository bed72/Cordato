## MODIFIED Requirements

### Requirement: Validação de entrada no request

O sistema SHALL validar o corpo da requisição na borda HTTP, com Bean Validation, antes de invocar o
`SignUpUseCase`. O corpo SHALL estar presente e ser JSON válido, os campos `name`, `email` e `password`
SHALL estar presentes como strings, e cada campo SHALL cumprir as restrições declaradas no request. Toda
requisição que falhe qualquer uma dessas checagens SHALL ser recusada com `400 Bad Request`, no corpo de
erro compartilhado definido pela capability `http-error-handling`, **sem** invocar o `SignUpUseCase`.
Quando mais de um campo violar suas restrições na mesma requisição, a resposta SHALL reportar cada campo
violado como um item da lista `errors`, não uma mensagem concatenada.

As restrições do request que espelham uma regra de domínio SHALL referenciar a **mesma** definição do
value object correspondente (a constante ou o padrão público), de modo que a checagem de borda não possa
divergir da regra de domínio. O value object permanece a autoridade única da invariante — a validação de
borda é uma checagem antecipada e propositalmente igual ou mais estrita (por validar o valor cru, antes da
normalização que o value object aplica), nunca uma segunda regra independente.

#### Scenario: Corpo ausente ou não-JSON

- **WHEN** o endpoint recebe uma requisição sem corpo ou com JSON inválido
- **THEN** o sistema responde `400 Bad Request`
- **AND** o `SignUpUseCase` não é invocado

#### Scenario: Campo obrigatório ausente

- **WHEN** o corpo JSON não contém um dos campos `name`, `email` ou `password`
- **THEN** o sistema responde `400 Bad Request`
- **AND** o `SignUpUseCase` não é invocado

#### Scenario: Campo viola uma restrição de borda

- **WHEN** o corpo tem um nome vazio/acima do máximo, um e-mail em formato inválido, ou uma senha abaixo do mínimo
- **THEN** o sistema responde `400 Bad Request` no corpo de erro compartilhado
- **AND** o `SignUpUseCase` não é invocado

#### Scenario: Múltiplas violações reportam cada campo

- **WHEN** dois ou mais de `name`, `email`, `password` violam suas restrições na mesma requisição
- **THEN** o sistema responde `400 Bad Request` com um item em `errors` por campo violado
- **AND** as mensagens não são concatenadas em um único campo `message`
- **AND** o `SignUpUseCase` não é invocado

#### Scenario: Restrição de borda não diverge do domínio

- **WHEN** uma restrição do request espelha uma regra de domínio (tamanho máximo do nome, mínimo da senha, formato do e-mail)
- **THEN** ela referencia a mesma constante/padrão público do value object, não um literal duplicado

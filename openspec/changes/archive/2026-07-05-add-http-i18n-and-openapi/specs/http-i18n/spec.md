## ADDED Requirements

### Requirement: Mensagens de resposta resolvidas de um bundle localizável

O sistema SHALL produzir as mensagens legíveis das respostas HTTP a partir de um bundle de mensagens
(ResourceBundle), referenciadas por uma **chave** estável, e SHALL NOT embutir o texto legível como literal
inline no código que constrói a resposta. O bundle default SHALL estar em pt-BR e SHALL residir no núcleo
compartilhado como recurso de infraestrutura. A adição de um novo idioma SHALL ser possível apenas
acrescentando um arquivo de bundle por locale, sem alteração de código.

#### Scenario: Mensagem vem do bundle, não de literal

- **WHEN** a borda HTTP constrói o corpo de uma resposta de erro
- **THEN** a mensagem legível é resolvida por uma chave no bundle de mensagens
- **AND** nenhum literal de texto legível é embutido no código que monta a resposta

#### Scenario: Bundle default em pt-BR

- **WHEN** o sistema resolve uma chave de mensagem sem nenhum locale mais específico disponível
- **THEN** o texto retornado é o do bundle default, em pt-BR

#### Scenario: Novo idioma sem mudança de código

- **WHEN** um arquivo de bundle para um novo locale é adicionado aos recursos
- **THEN** as mensagens daquele locale passam a ser resolvíveis
- **AND** nenhuma alteração no código de borda é necessária

### Requirement: Locale derivado do cabeçalho Accept-Language

O sistema SHALL derivar o locale da resposta a partir do cabeçalho `Accept-Language` da requisição. Quando
o cabeçalho estiver ausente, vazio, ou pedir um locale para o qual não há bundle, o sistema SHALL recair
sobre o bundle default (pt-BR). A resolução SHALL NOT falhar a requisição por conta de um `Accept-Language`
desconhecido — ela apenas seleciona o texto a servir.

#### Scenario: Accept-Language ausente cai no default

- **WHEN** a requisição não envia o cabeçalho `Accept-Language`
- **THEN** as mensagens da resposta são resolvidas no bundle default (pt-BR)

#### Scenario: Accept-Language sem bundle correspondente cai no default

- **WHEN** a requisição pede um locale para o qual não existe bundle
- **THEN** a requisição não falha por causa disso
- **AND** as mensagens são resolvidas no bundle default (pt-BR)

### Requirement: O domínio nunca produz texto de apresentação

O sistema SHALL manter a resolução de mensagens inteiramente na camada HTTP/infra. Nenhum tipo de
`domain` — value object, entidade ou erro de domínio — SHALL conhecer o `MessageSource`, uma chave de
bundle, ou qualquer texto de apresentação. Um erro de domínio SHALL carregar apenas o dado semântico
necessário (ex.: um comprimento mínimo), e a camada HTTP SHALL traduzir esse dado em texto via a chave
correspondente.

#### Scenario: Erro de domínio carrega dado, não texto

- **WHEN** um erro de domínio precisa expor um valor para a mensagem (ex.: o comprimento mínimo de senha)
- **THEN** o erro carrega o dado semântico (o número), não a string formatada
- **AND** a camada HTTP resolve o texto a partir da chave, interpolando o dado

#### Scenario: Value object não conhece i18n

- **WHEN** um value object valida uma invariante e a rejeita
- **THEN** ele não referencia `MessageSource`, chave de bundle ou texto de apresentação

### Requirement: A localização preserva a invariante de não-vazamento

O sistema SHALL preservar, ao localizar as mensagens, todas as invariantes de não-vazamento já exigidas
pelas respostas de erro. Uma mensagem localizada de conflito de e-mail (`EmailAlreadyInUse`) SHALL
permanecer genérica em qualquer idioma, sem afirmar nem sugerir que o e-mail já está cadastrado, e SHALL
NOT ser transformada em erro por campo. Uma falha inesperada (`500`) SHALL resolver apenas uma mensagem
genérica; nenhum detalhe interno SHALL ser incorporado ao texto por conta da localização.

#### Scenario: Conflito de e-mail permanece neutro localizado

- **WHEN** a resposta de `EmailAlreadyInUse` é localizada em qualquer idioma
- **THEN** a mensagem é genérica e não confirma que o e-mail está cadastrado
- **AND** a resposta continua escalar, sem virar um erro por campo `email`

#### Scenario: Falha inesperada resolve só mensagem genérica

- **WHEN** a resposta `500` é localizada
- **THEN** apenas uma mensagem genérica é resolvida do bundle
- **AND** nenhum detalhe da exceção é incorporado ao texto

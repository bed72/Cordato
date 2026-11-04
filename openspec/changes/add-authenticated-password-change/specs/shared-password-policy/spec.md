## ADDED Requirements

### Requirement: Política única consistente com PocketBase

O app SHALL usar uma única política de senha com 6 a 16 caracteres Unicode, contados por code points, exigindo ao menos uma minúscula ASCII `[a-z]`, uma maiúscula ASCII `[A-Z]` e um número ASCII `[0-9]`. Cadastro, recuperação e troca SHALL compartilhar essa política; consumidores existentes do validator, incluindo sign-in, SHALL permanecer consistentes com ela.

#### Scenario: Limites inclusivos
- **WHEN** uma senha com as três classes exigidas tem 6, 12, 13 ou 16 caracteres
- **THEN** a política aceita a senha

#### Scenario: Comprimento inválido
- **WHEN** a senha tem menos de 6 ou mais de 16 caracteres
- **THEN** a política rejeita com mensagem local indicando o intervalo 6–16

#### Scenario: Classe obrigatória ausente
- **WHEN** uma senha no intervalo não possui minúscula ASCII, maiúscula ASCII ou número ASCII
- **THEN** a política rejeita e identifica a classe ausente em mensagem local
- **AND** letras acentuadas e dígitos de outros alfabetos não substituem as classes exigidas

#### Scenario: Caracteres suplementares
- **WHEN** uma senha com as três classes exigidas inclui caracteres Unicode suplementares
- **THEN** cada code point conta como um caractere no limite de 6–16, não como duas unidades UTF-16

### Requirement: Preservação exata da entrada

Formulários, Blocs e repositories SHALL preservar a senha sem trim, transformação de caixa ou normalização. Espaços e caracteres adicionais SHALL ser aceitos quando a senha satisfizer comprimento e classes obrigatórias. Entradas vazias SHALL produzir erro local de preenchimento.

#### Scenario: Senha com espaços
- **WHEN** uma senha válida contém espaços iniciais, intermediários ou finais
- **THEN** o validator devolve o valor original e a operação delega exatamente esse valor

#### Scenario: Senha vazia
- **WHEN** a pessoa envia uma senha vazia
- **THEN** o formulário apresenta erro de senha obrigatória sem enviar a operação

### Requirement: Comparações da troca de senha

A troca SHALL exigir senha atual preenchida sem aplicar a ela a política de criação. A nova senha SHALL satisfazer a política compartilhada e diferir exatamente da atual. A confirmação SHALL coincidir exatamente com a nova. As regras relacionais SHALL ser testáveis em validators puros.

#### Scenario: As três senhas iguais
- **WHEN** atual, nova e confirmação coincidem e satisfazem a política
- **THEN** o campo Nova senha mostra “A nova senha não pode ser igual à senha atual”
- **AND** a confirmação não recebe erro de divergência e nenhuma requisição é enviada

#### Scenario: Nova igual à atual e confirmação diferente
- **WHEN** a nova senha coincide com a atual e a confirmação diverge da nova
- **THEN** Nova senha recebe o erro de reutilização e Confirmar nova senha recebe “As senhas não coincidem”
- **AND** nenhuma requisição é enviada

#### Scenario: Nova diferente da atual e confirmação divergente
- **WHEN** a nova senha é válida e difere da atual, mas a confirmação difere da nova
- **THEN** somente a confirmação recebe “As senhas não coincidem” como erro relacional
- **AND** nenhuma requisição é enviada

#### Scenario: Confirmação ausente
- **WHEN** a confirmação está vazia
- **THEN** o formulário exige sua entrada com mensagem local e bloqueia o envio

#### Scenario: Senha atual fora da política de criação
- **WHEN** a senha atual está preenchida mas não satisfaz a política de criação, e nova/confirmação são válidas e diferentes dela
- **THEN** a validação local permite consultar o backend com a senha atual exatamente como digitada

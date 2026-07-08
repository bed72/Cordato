# api-versioning Specification

## Purpose
TBD - created by syncing change add-v1-route-prefix. Update Purpose after archive.
## Requirements
### Requirement: Toda rota de API é servida sob um prefixo de versão global

O sistema SHALL expor todas as rotas de API sob um único prefixo de versão global (`/v1`), aplicado de
forma centralizada pela configuração do servidor (`micronaut.server.context-path`), e não por segmento
literal em cada controller. Os paths declarados nos `@Controller` SHALL permanecer relativos à versão
(sem o literal `/v1`), de modo que a versão seja uma decisão de configuração num único lugar.

#### Scenario: Rota de API responde sob o prefixo de versão

- **WHEN** um cliente requisita `GET /v1/persons/me` ou `POST /v1/authentication/sign-up`
- **THEN** a rota correspondente é resolvida e tratada normalmente

#### Scenario: O mesmo path sem o prefixo não existe

- **WHEN** um cliente requisita a rota sem o prefixo (`GET /persons/me`)
- **THEN** o servidor responde `404 Not Found`, pois nenhuma rota de API é publicada na raiz

#### Scenario: Controllers permanecem relativos à versão

- **WHEN** o código-fonte dos controllers é inspecionado
- **THEN** nenhuma anotação `@Controller` contém o literal `/v1`; o prefixo vem só da configuração do servidor

### Requirement: Recursos estáticos de documentação ficam sob o prefixo de versão

O sistema SHALL servir a Swagger UI e o documento OpenAPI cru sob o prefixo de versão
(`/v1/swagger-ui/**` e `/v1/swagger/**`), porque o `micronaut.server.context-path` é global e prefixa
também os mapeamentos de `static-resources` — não há opção limpa de isentar um mapeamento do prefixo.
A documentação vive, então, junto da API sob `/v1`, de forma coerente (decisão all-or-nothing,
deliberada). As rotas de documentação na raiz (`/swagger-ui/**`, `/swagger/**`) NÃO existem mais.

#### Scenario: Swagger UI é servida sob o prefixo de versão

- **WHEN** um cliente abre `/v1/swagger-ui/` ou baixa o documento em `/v1/swagger/...`
- **THEN** o recurso é servido normalmente

#### Scenario: A rota de documentação na raiz não existe

- **WHEN** um cliente abre `/swagger-ui/` ou `/swagger/...` sem o prefixo
- **THEN** o servidor responde `404 Not Found`, pois o context-path também prefixa os recursos estáticos

### Requirement: O documento OpenAPI expõe paths já prefixados pela versão

O documento OpenAPI SHALL expor os paths dos endpoints já com o prefixo de versão (`/v1/persons/me`),
porque o processador micronaut-openapi lê `micronaut.server.context-path` em tempo de compilação e o
aplica aos paths gerados. O documento NÃO SHALL declarar um servidor com URL `/v1` — isso duplicaria o
prefixo (`/v1` + `/v1/persons/me`); o documento fica autoconsistente contra o servidor padrão (`/`).

#### Scenario: Path documentado resolve para a rota real

- **WHEN** a Swagger UI renderiza o endpoint `GET /v1/persons/me` e o usuário aciona "Try it out"
- **THEN** a requisição é enviada para `/v1/persons/me`, batendo na rota real, sem duplicar o prefixo

### Requirement: Paths de endpoints em specs de feature são relativos à versão

Os paths de endpoints documentados nas specs de feature SHALL ser interpretados como relativos ao
prefixo de versão ativo, e não como paths absolutos a partir da raiz — por exemplo, `GET /persons/me`
em `identity-http-api` designa a rota real `/v1/persons/me`. Uma spec de feature NÃO precisa repetir o
prefixo em cada rota.

#### Scenario: Spec de feature não repete o prefixo

- **WHEN** uma spec de feature documenta um endpoint como `GET /persons/me`
- **THEN** entende-se que a rota real é `/v1/persons/me`, sem que a spec de feature precise citar `/v1`

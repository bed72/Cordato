# ADR 0010: OpenAPI generation

OpenAPI is generated at compile-time (KSP, no runtime reflection) and the doc annotations live on a
`<Controller>Doc` interface, not the controller. `build.gradle.kts` adds `ksp("io.micronaut.openapi:
micronaut-openapi")` (processor) + `compileOnly(...:micronaut-openapi-annotations)` (the
`io.swagger.v3.oas.annotations`), pinned like the other KSP processors (the `ksp` config doesn't inherit
the BOM). The build emits the document and Swagger UI under `META-INF/swagger`, served via
`static-resources` mappings in `application.properties` (`/swagger/**`, `/swagger-ui/**`). Global document
metadata (`@OpenAPIDefinition` title/version) lives once in `core/infrastructure/http/openapi/` — cross-
cutting, alongside the error contract. Per route, the `@Operation`/`@ApiResponse`/`@Tag` annotations live on
an interface `features/<context>/infrastructure/http/controllers/docs/<Controller>Doc.kt` that the
controller **implements**: Micronaut inherits the interface's annotation metadata onto the implementing
method, so the controller keeps only routing/validation (`@Controller`/`@Post`/`@Validated`/`@Body`/
`@Valid`) and delegation while the documentation stays off it. Response *body* schemas are declared on that
interface's `@ApiResponse`s via `@Content(schema = @Schema(implementation = …))` (e.g. `201 → PersonResponse`,
`4xx/5xx → ErrorResponse`); field-level docs (`@Schema(description, example)`) live on the request/response
DTOs themselves, since a data class's fields have no interface to hang them on — this is also where you set
a sane `example` so the generator doesn't synthesize a garbage one from a `@Pattern` regex. Because the
handler returns `HttpResponse<*>` (varying status/body), annotate the success method with
`@Status(HttpStatus.CREATED)` so the generator documents `201` as the success response instead of emitting a
spurious `200` — it is inert at runtime (the explicit `HttpResponse` status always wins). This interface is
a **documentation artefact of infrastructure**, not an application port — it introduces no driving-side
contract and never duplicates the use case's signature. Apply the same `<Controller>Doc` split to every new
context's controller.

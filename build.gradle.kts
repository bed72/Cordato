plugins {
    application

    kotlin("jvm") version "2.3.21"
    kotlin("plugin.allopen") version "2.3.21"

    id("com.google.devtools.ksp") version "2.3.9"
    id("org.jooq.jooq-codegen-gradle") version "3.20.5"
}

// Micronaut applies AOP by subclassing the target, but Kotlin classes/methods are `final` by
// default. Opening every type that carries an `@Around`-meta annotation (e.g. `@Validated` on a
// controller) lets the framework generate its interceptor proxy without each class having to
// declare `open` by hand. Pure classes with no such annotation (use cases, adapters) stay final.
allOpen {
    annotation("io.micronaut.aop.Around")
}

group = "org.example"
version = "1.0-SNAPSHOT"

repositories {
    mavenCentral()
}

val jooqVersion = "3.20.5"
val flywayVersion = "11.1.0"
val micronautVersion = "4.10.16"
val testcontainersVersion = "1.20.4"
val micronautInjectVersion = "4.10.25" // micronaut-core version the platform BOM above resolves to; pins the KSP processor
val micronautSerdeVersion = "2.16.2" // micronaut-serde version the platform BOM resolves; pins the serde KSP processor
val micronautValidationVersion = "4.12.0" // micronaut-validation version the platform BOM resolves; pins the validation KSP processor
val micronautOpenapiVersion = "6.20.0" // micronaut-openapi version the platform BOM resolves; pins the openapi KSP processor

dependencies {
    implementation("at.favre.lib:bcrypt:0.10.2")
    implementation("com.fasterxml.uuid:java-uuid-generator:5.1.0")

    // Micronaut compile-time DI only (no HTTP server yet — that is a later change). The platform
    // BOM pins the inject artifacts; micronaut-inject-kotlin is the KSP annotation processor that
    // generates the bean definitions from the @Factory wiring in each package's `main/`. The BOM
    // only governs the `implementation` classpath — the `ksp` configuration doesn't inherit it, so
    // the processor is pinned to the version the BOM resolves (core != platform version number).
    implementation(platform("io.micronaut.platform:micronaut-platform:$micronautVersion"))
    implementation("io.micronaut:micronaut-inject")
    ksp("io.micronaut:micronaut-inject-kotlin:$micronautInjectVersion")

    // HTTP entry layer (driving/inbound): embedded Netty server plus compile-time JSON
    // (Micronaut Serde, no reflection — @Serdeable bodies are bound via a generated serializer,
    // consistent with the KSP/no-reflection stance the DI wiring already takes). The platform BOM
    // versions the `implementation` artifacts; the `ksp` serde processor doesn't inherit the BOM,
    // so it is pinned to the serde version the BOM resolves (see $micronautSerdeVersion).
    implementation("io.micronaut:micronaut-http-server-netty")
    implementation("io.micronaut.serde:micronaut-serde-jackson")
    ksp("io.micronaut.serde:micronaut-serde-processor:$micronautSerdeVersion")

    // Bean Validation at the HTTP edge (jakarta.validation). Request DTOs carry constraints that
    // reference the domain value objects' own constants/pattern — one definition, two call sites —
    // so the edge check can't drift from the domain rule. KSP only (no kapt); the processor doesn't
    // inherit the BOM, so it is pinned to the version the BOM resolves.
    implementation("io.micronaut.validation:micronaut-validation")
    ksp("io.micronaut.validation:micronaut-validation-processor:$micronautValidationVersion")

    // OpenAPI documentation generated at compile-time (KSP, no runtime reflection — same stance as
    // Serde/validation/DI). The processor derives an OpenAPI document from the @Controller routes and
    // the io.swagger.v3.oas.annotations, emitting it plus the Swagger UI under META-INF/swagger at
    // build time. The annotations are compileOnly (they carry no runtime behaviour); swagger-annotations
    // comes transitively. Like the other processors, the `ksp` config doesn't inherit the BOM, so it is
    // pinned to the version the BOM resolves (see $micronautOpenapiVersion).
    compileOnly("io.micronaut.openapi:micronaut-openapi-annotations:$micronautOpenapiVersion")
    ksp("io.micronaut.openapi:micronaut-openapi:$micronautOpenapiVersion")

    // Persistence foundation
    implementation("com.zaxxer:HikariCP:6.2.1")
    implementation("org.jooq:jooq:$jooqVersion")
    implementation("org.postgresql:postgresql:42.7.4")
    implementation("org.flywaydb:flyway-core:$flywayVersion")
    runtimeOnly("org.flywaydb:flyway-database-postgresql:$flywayVersion")

    jooqCodegen("org.jooq:jooq-meta-extensions:$jooqVersion")

    testImplementation(kotlin("test"))

    testImplementation("io.mockk:mockk:1.14.11")
    testImplementation("com.lemonappdev:konsist:0.17.3")

    // HTTP-layer tests: boot the controller behind a real Netty server + blocking client and
    // exercise routing/JSON/status. SignUpUseCase is replaced with a MockK @MockBean, so the
    // lazy DataSource is never realized — these tests need no PostgreSQL.
    testImplementation("io.micronaut:micronaut-http-client")
    testImplementation("io.micronaut.test:micronaut-test-junit5")

    testImplementation("org.testcontainers:postgresql:$testcontainersVersion")
    testImplementation("org.testcontainers:junit-jupiter:$testcontainersVersion")
}

kotlin {
    jvmToolchain(25)
}

// OpenAPI generator config, passed as KSP processor arguments rather than an `openapi.properties`
// file so the whole OpenAPI config stays in the build script.
ksp {
    // Also render the Swagger UI (into META-INF/swagger/views/swagger-ui) alongside the generated spec.
    arg("micronaut.openapi.views.spec", "swagger-ui.enabled=true")

    // Emit schema property names in snake_case so the generated document matches the wire contract that
    // micronaut.serde.property-naming-strategy=SNAKE_CASE produces at runtime — the doc must never
    // advertise `expiresAt` while the server sends `expires_at`. This is the compile-time twin of that
    // runtime setting; the openapi processor doesn't read the runtime config, so the policy is declared
    // in both places on purpose.
    arg("micronaut.openapi.property.naming.strategy", "SNAKE_CASE")
}

// A runnable entry point now exists (the embedded HTTP server), so `./gradlew run` serves the API.
// `Main.kt`'s top-level `fun main` compiles to the `MainKt` class in its package.
application {
    mainClass = "com.bed.cordato.main.MainKt"
}

// jOOQ generates type-safe access classes from the Flyway migrations. Using the DDLDatabase
// meta-provider, the generator parses src/main/resources/db/migration/*.sql directly, so the
// generated types can never drift from the schema and the build needs no running database.
jooq {
    configuration {
        generator {
            database {
                name = "org.jooq.meta.extensions.ddl.DDLDatabase"
                properties {
                    // Point the parser at the Flyway scripts and apply them in Flyway order.
                    property {
                        key = "scripts"
                        value = "src/main/resources/db/migration"
                    }
                    property {
                        key = "sort"
                        value = "flyway"
                    }
                    // Lowercase unquoted identifiers so the generated names quote to the same
                    // lowercase names PostgreSQL uses at runtime (H2 would otherwise uppercase them).
                    property {
                        value = "lower"
                        key = "defaultNameCase"
                    }
                }
            }
            generate {
                isDaos = false
                isPojos = false
                isRecords = true
                isDeprecated = false
                isJavaTimeTypes = true
            }
            target {
                packageName = "com.bed.cordato.core.infrastructure.persistence.models"
                directory = layout.buildDirectory.dir("generated-src/jooq/main").get().asFile.path
            }
        }
    }
}

// Make the generated jOOQ sources part of the main compilation and regenerate whenever the
// migrations change.
sourceSets.main {
    java.srcDir(layout.buildDirectory.dir("generated-src/jooq/main"))
}

tasks.named("compileKotlin") {
    dependsOn(tasks.named("jooqCodegen"))
}

// KSP compiles the main sources (which include the generated jOOQ classes) to discover the
// @Factory bean definitions, so it needs the jOOQ codegen to have run first — same ordering
// compileKotlin already declares above. The KSP task is registered lazily by the plugin, so
// match it by name rather than resolving it eagerly with tasks.named.
tasks.matching { it.name == "kspKotlin" }.configureEach {
    dependsOn(tasks.named("jooqCodegen"))
}

tasks.named("jooqCodegen") {
    inputs.dir(layout.projectDirectory.dir("src/main/resources/db/migration"))
}

tasks.test {
    useJUnitPlatform()

    // Modern Docker engines (29+) reject the stale default API version (1.32) that docker-java
    // falls back to. docker-java reads the pinned version from the `api.version` system property;
    // 1.41 is supported by every engine since 2020. Respect an explicit override if present.
    if (System.getenv("DOCKER_API_VERSION").isNullOrBlank()) {
        systemProperty("api.version", "1.41")
    }

    // Testcontainers discovers Docker via the default socket, which colima does not create.
    // When DOCKER_HOST isn't already set and a colima socket exists, point Testcontainers at
    // it (the socket override is the in-VM path Ryuk bind-mounts). On Docker Desktop / CI —
    // where the default /var/run/docker.sock exists — this branch is skipped and discovery
    // works out of the box.
    if (System.getenv("DOCKER_HOST").isNullOrBlank()) {
        val colimaSocket = file("${System.getProperty("user.home")}/.colima/default/docker.sock")
        if (colimaSocket.exists()) {
            environment("DOCKER_HOST", "unix://${colimaSocket.absolutePath}")
            environment("TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE", "/var/run/docker.sock")
        }
    }
}

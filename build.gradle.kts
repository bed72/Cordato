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
val micronautSerdeVersion = "2.16.2"
val micronautInjectVersion = "4.10.25"
val micronautOpenapiVersion = "6.20.0"
val micronautValidationVersion = "4.12.0"

dependencies {
    implementation("at.favre.lib:bcrypt:0.10.2")
    implementation("com.fasterxml.uuid:java-uuid-generator:5.1.0")

    implementation(platform("io.micronaut.platform:micronaut-platform:$micronautVersion"))
    implementation("io.micronaut:micronaut-inject")
    ksp("io.micronaut:micronaut-inject-kotlin:$micronautInjectVersion")

    implementation("io.micronaut:micronaut-http-server-netty")
    implementation("io.micronaut.serde:micronaut-serde-jackson")
    ksp("io.micronaut.serde:micronaut-serde-processor:$micronautSerdeVersion")

    implementation("io.micronaut.validation:micronaut-validation")
    ksp("io.micronaut.validation:micronaut-validation-processor:$micronautValidationVersion")

    compileOnly("io.micronaut.openapi:micronaut-openapi-annotations:$micronautOpenapiVersion")
    ksp("io.micronaut.openapi:micronaut-openapi:$micronautOpenapiVersion")

    // Persistence foundation
    implementation("com.zaxxer:HikariCP:6.2.1")
    implementation("org.jooq:jooq:$jooqVersion")
    implementation("org.postgresql:postgresql:42.7.4")
    implementation("org.flywaydb:flyway-core:$flywayVersion")
    runtimeOnly("org.flywaydb:flyway-database-postgresql:$flywayVersion")


    implementation("io.lettuce:lettuce-core")

    runtimeOnly("ch.qos.logback:logback-classic:1.5.18")

    jooqCodegen("org.jooq:jooq-meta-extensions:$jooqVersion")

    testImplementation(kotlin("test"))

    testImplementation("io.mockk:mockk:1.14.11")
    testImplementation("com.lemonappdev:konsist:0.17.3")
    testImplementation("ch.qos.logback:logback-classic:1.5.18")

    testImplementation("io.micronaut:micronaut-http-client")
    testImplementation("io.micronaut.test:micronaut-test-junit5")

    testImplementation("org.testcontainers:postgresql:$testcontainersVersion")
    testImplementation("org.testcontainers:junit-jupiter:$testcontainersVersion")
}

kotlin {
    jvmToolchain(25)
}

ksp {
    arg(
        "micronaut.openapi.views.spec",
        "swagger-ui.enabled=true," +
            "swagger-ui.filter=true," +
            "swagger-ui.deepLinking=true," +
            "swagger-ui.displayRequestDuration=true," +
            "swagger-ui.persistAuthorization=true," +
            "swagger-ui.tagsSorter=alpha," +
            "swagger-ui.operationsSorter=alpha",
    )

    arg("micronaut.openapi.property.naming.strategy", "SNAKE_CASE")

    // Hibernate Validator's `message = "{key}"` is an i18n placeholder resolved at request time (see
    // core's message bundle), never inline text — but micronaut-openapi's generator-extensions feature
    // copies that raw `{key}` literal verbatim into `x-not-null-message`/`x-size-message`/etc vendor
    // extensions on the schema. Since the key never resolves at compile time, leaving this on just
    // leaks unreadable placeholders into the public OpenAPI document; disabling it is a pure doc-quality
    // fix, the real localized messages still work at runtime exactly as before.
    arg("micronaut.openapi.generator.extensions.enabled", "false")
}


application {
    mainClass = "com.bed.cordato.main.MainKt"
}

jooq {
    configuration {
        generator {
            database {
                name = "org.jooq.meta.extensions.ddl.DDLDatabase"
                properties {
                    property {
                        key = "scripts"
                        value = "src/main/resources/db/migration"
                    }
                    property {
                        key = "sort"
                        value = "flyway"
                    }
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

sourceSets.main {
    java.srcDir(layout.buildDirectory.dir("generated-src/jooq/main"))
}

tasks.named("compileKotlin") {
    dependsOn(tasks.named("jooqCodegen"))
}

tasks.matching { it.name == "kspKotlin" }.configureEach {
    dependsOn(tasks.named("jooqCodegen"))
}

tasks.named("jooqCodegen") {
    inputs.dir(layout.projectDirectory.dir("src/main/resources/db/migration"))
}

tasks.test {
    useJUnitPlatform()

    if (System.getenv("DOCKER_API_VERSION").isNullOrBlank()) {
        systemProperty("api.version", "1.41")
    }

    if (System.getenv("DOCKER_HOST").isNullOrBlank()) {
        val colimaSocket = file("${System.getProperty("user.home")}/.colima/default/docker.sock")
        if (colimaSocket.exists()) {
            environment("DOCKER_HOST", "unix://${colimaSocket.absolutePath}")
            environment("TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE", "/var/run/docker.sock")
        }
    }
}

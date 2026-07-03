plugins {
    kotlin("jvm") version "2.3.21"

    id("org.jooq.jooq-codegen-gradle") version "3.20.5"
}

group = "org.example"
version = "1.0-SNAPSHOT"

repositories {
    mavenCentral()
}

val jooqVersion = "3.20.5"
val flywayVersion = "11.1.0"
val testcontainersVersion = "1.20.4"

dependencies {
    implementation("at.favre.lib:bcrypt:0.10.2")
    implementation("io.insert-koin:koin-core:4.0.0")
    implementation("com.fasterxml.uuid:java-uuid-generator:5.1.0")

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

    testImplementation("org.testcontainers:postgresql:$testcontainersVersion")
    testImplementation("org.testcontainers:junit-jupiter:$testcontainersVersion")
}

kotlin {
    jvmToolchain(25)
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
                packageName = "com.bed.cordato.features.identity.infrastructure.repositories.models"
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

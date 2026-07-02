plugins {
    kotlin("jvm") version "2.3.21"
}

group = "org.example"
version = "1.0-SNAPSHOT"

repositories {
    mavenCentral()
}

dependencies {
    implementation("at.favre.lib:bcrypt:0.10.2")
    implementation("io.insert-koin:koin-core:4.0.0")
    implementation("com.fasterxml.uuid:java-uuid-generator:5.1.0")

    testImplementation(kotlin("test"))

    testImplementation("io.mockk:mockk:1.14.11")
    testImplementation("com.lemonappdev:konsist:0.17.3")
}

kotlin {
    jvmToolchain(25)
}

tasks.test {
    useJUnitPlatform()
}
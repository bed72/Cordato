package com.bed.cordato.features.identity.main

import jakarta.inject.Singleton

import io.micronaut.context.annotation.Factory

import org.jooq.DSLContext

import com.bed.cordato.core.application.ports.IdGeneratorPort

import com.bed.cordato.features.identity.application.use_cases.SignUpUseCase
import com.bed.cordato.features.identity.application.ports.PasswordHasherPort
import com.bed.cordato.features.identity.application.repositories.PersonRepository

import com.bed.cordato.features.identity.infrastructure.adapters.PasswordHasherAdapter
import com.bed.cordato.features.identity.infrastructure.repositories.PersistencePersonRepository

/**
 * Identity's DI factory — binds identity's own ports to their adapters. The determinism ports
 * (clock, id generation) and the [DSLContext] come from [com.bed.cordato.core.main.CoreModule];
 * this factory only wires what identity owns and takes those kernel-provided collaborators as
 * method parameters (no second `DSLContext` binding). Lives in identity's own `main` subpackage —
 * the one place within the context where wiring may reach across layers; domain and application
 * never import Micronaut.
 */
@Factory
class IdentityModule {

    @Singleton
    fun passwordHasher(): PasswordHasherPort = PasswordHasherAdapter()

    // Durable PostgreSQL adapter; the DSLContext comes from CoreModule. Pure use-case tests use
    // a hand-written fake (support.FakePersonRepository), not a production binding.
    @Singleton
    fun personRepository(dslContext: DSLContext): PersonRepository = PersistencePersonRepository(dslContext)

    @Singleton
    fun signUpUseCase(
        generator: IdGeneratorPort,
        hasher: PasswordHasherPort,
        repository: PersonRepository,
    ): SignUpUseCase = SignUpUseCase(generator, hasher, repository)
}

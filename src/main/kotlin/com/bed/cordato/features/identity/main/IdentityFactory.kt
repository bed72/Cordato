package com.bed.cordato.features.identity.main

import org.jooq.DSLContext

import jakarta.inject.Singleton

import io.micronaut.context.annotation.Factory


import com.bed.cordato.core.application.ports.ClockPort
import com.bed.cordato.core.application.ports.TokenizerPort
import com.bed.cordato.core.application.ports.IdGeneratorPort
import com.bed.cordato.core.application.repositories.SessionRepository

import com.bed.cordato.features.identity.application.use_cases.SignUpUseCase
import com.bed.cordato.features.identity.application.use_cases.SignInUseCase
import com.bed.cordato.features.identity.application.ports.PasswordHasherPort
import com.bed.cordato.features.identity.application.repositories.PersonRepository

import com.bed.cordato.features.identity.infrastructure.adapters.PasswordHasherAdapter
import com.bed.cordato.features.identity.infrastructure.repositories.PersistencePersonRepository

/**
 * Identity's DI factory — binds identity's own ports to their adapters. The determinism ports
 * (clock, id generation) and the [DSLContext] come from [com.bed.cordato.core.main.CoreFactory];
 * this factory only wires what identity owns and takes those kernel-provided collaborators as
 * method parameters (no second `DSLContext` binding). Lives in identity's own `main` subpackage —
 * the one place within the context where wiring may reach across layers; domain and application
 * never import Micronaut.
 */
@Factory
class IdentityFactory {

    @Singleton
    fun passwordHasher(): PasswordHasherPort = PasswordHasherAdapter()

    // Durable PostgreSQL adapter; the DSLContext comes from CoreFactory. Pure use-case tests use
    // a hand-written fake (support.FakePersonRepository), not a production binding.
    @Singleton
    fun personRepository(dslContext: DSLContext): PersonRepository = PersistencePersonRepository(dslContext)

    @Singleton
    fun signUpUseCase(
        generator: IdGeneratorPort,
        hasher: PasswordHasherPort,
        repository: PersonRepository,
    ): SignUpUseCase = SignUpUseCase(hasher, generator, repository)

    // Clock, tokenizer, id generator and session repository come from CoreFactory; the password
    // hasher and person repository are identity's own bindings above.
    @Singleton
    fun signInUseCase(
        clock: ClockPort,
        tokenizer: TokenizerPort,
        generator: IdGeneratorPort,
        hasher: PasswordHasherPort,
        personRepository: PersonRepository,
        sessionRepository: SessionRepository,
    ): SignInUseCase = SignInUseCase(
        clock = clock,
        hasher = hasher,
        generator = generator,
        tokenizer = tokenizer,
        personRepository = personRepository,
        sessionRepository = sessionRepository
    )
}

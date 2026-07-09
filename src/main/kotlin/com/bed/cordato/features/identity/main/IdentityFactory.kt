package com.bed.cordato.features.identity.main

import org.jooq.DSLContext

import jakarta.inject.Singleton

import io.micronaut.context.annotation.Factory


import com.bed.cordato.core.application.driven.ports.ClockPort
import com.bed.cordato.core.application.driven.ports.TokenizerPort
import com.bed.cordato.core.application.driven.ports.IdGeneratorPort
import com.bed.cordato.core.application.driven.repositories.SessionRepository

import com.bed.cordato.features.identity.application.driving.use_cases.MeUseCase
import com.bed.cordato.features.identity.application.driven.ports.PasswordHasherPort
import com.bed.cordato.features.identity.application.driving.use_cases.SignUpUseCase
import com.bed.cordato.features.identity.application.driving.use_cases.SignInUseCase
import com.bed.cordato.features.identity.application.driving.use_cases.UpdateNameUseCase
import com.bed.cordato.features.identity.application.driving.use_cases.UpdateEmailUseCase
import com.bed.cordato.features.identity.application.driven.repositories.PersonRepository
import com.bed.cordato.features.identity.application.driving.use_cases.UpdatePasswordUseCase

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
    fun meUseCase(repository: PersonRepository): MeUseCase = MeUseCase(repository)

    @Singleton
    fun updateNameUseCase(repository: PersonRepository): UpdateNameUseCase = UpdateNameUseCase(repository)

    @Singleton
    fun updateEmailUseCase(
        hasher: PasswordHasherPort,
        repository: PersonRepository,
    ): UpdateEmailUseCase = UpdateEmailUseCase(hasher, repository)

    // The password hasher and person repository are identity's own bindings; the session repository comes
    // from CoreFactory, letting the use case revoke the person's other sessions after the password rotates.
    @Singleton
    fun updatePasswordUseCase(
        hasher: PasswordHasherPort,
        repository: PersonRepository,
        sessionRepository: SessionRepository,
    ): UpdatePasswordUseCase = UpdatePasswordUseCase(hasher, repository, sessionRepository)

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

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
import com.bed.cordato.features.identity.application.driving.use_cases.SignOutUseCase
import com.bed.cordato.features.identity.application.driving.use_cases.UpdateNameUseCase
import com.bed.cordato.features.identity.application.driving.use_cases.UpdateEmailUseCase
import com.bed.cordato.features.identity.application.driven.repositories.PersonRepository
import com.bed.cordato.features.identity.application.driven.ports.PersonOwnedFinancialsPort
import com.bed.cordato.features.identity.application.driving.use_cases.DeleteAccountUseCase
import com.bed.cordato.features.identity.application.driving.use_cases.UpdatePasswordUseCase

import com.bed.cordato.features.identity.infrastructure.adapters.PasswordHasherAdapter
import com.bed.cordato.features.identity.infrastructure.adapters.PersonOwnedFinancialsAdapter
import com.bed.cordato.features.identity.infrastructure.repositories.PersistencePersonRepository

import com.bed.cordato.features.budget.application.driving.use_cases.DeleteAllOwnedBudgetsUseCase
import com.bed.cordato.features.expense.application.driving.use_cases.DeleteAllOwnedExpensesUseCase

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

    @Singleton
    fun meUseCase(repository: PersonRepository): MeUseCase = MeUseCase(repository)

    @Singleton
    fun updateNameUseCase(repository: PersonRepository): UpdateNameUseCase = UpdateNameUseCase(repository)

    @Singleton
    fun personRepository(dslContext: DSLContext): PersonRepository = PersistencePersonRepository(dslContext)

    @Singleton
    fun signOutUseCase(sessionRepository: SessionRepository): SignOutUseCase = SignOutUseCase(sessionRepository)

    @Singleton
    fun updateEmailUseCase(
        hasher: PasswordHasherPort,
        repository: PersonRepository,
    ): UpdateEmailUseCase = UpdateEmailUseCase(hasher, repository)

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

    @Singleton
    fun personOwnedFinancialsPort(
        deleteAllOwnedBudgetsUseCase: DeleteAllOwnedBudgetsUseCase,
        deleteAllOwnedExpensesUseCase: DeleteAllOwnedExpensesUseCase,
    ): PersonOwnedFinancialsPort =
        PersonOwnedFinancialsAdapter(deleteAllOwnedBudgetsUseCase, deleteAllOwnedExpensesUseCase)

    @Singleton
    fun deleteAccountUseCase(
        hasher: PasswordHasherPort,
        repository: PersonRepository,
        sessionRepository: SessionRepository,
        personOwnedFinancialsPort: PersonOwnedFinancialsPort,
    ): DeleteAccountUseCase = DeleteAccountUseCase(hasher, repository, sessionRepository, personOwnedFinancialsPort)
}

package com.bed.cordato.features.identity.main

import org.koin.dsl.module

import com.bed.cordato.features.identity.application.use_cases.SignUpUseCase
import com.bed.cordato.features.identity.application.ports.PasswordHasherPort
import com.bed.cordato.features.identity.application.repositories.PersonRepository

import com.bed.cordato.features.identity.infrastructure.adapters.PasswordHasherAdapter
import com.bed.cordato.features.identity.infrastructure.repositories.PersistencePersonRepository

/**
 * Identity's DI module — binds identity's own ports to their adapters. The determinism ports
 * (clock, id generation) and persistence come from [com.bed.cordato.core.main.coreModule]; this
 * module only wires what identity owns. Lives in identity's own `main` subpackage — the one place
 * within the context where wiring may reach across layers; domain and application never import Koin.
 */
val identityModule = module {
    single<PasswordHasherPort> { PasswordHasherAdapter() }
    // Durable PostgreSQL adapter; the DSLContext comes from coreModule. Pure use-case tests use
    // a hand-written fake (support.FakePersonRepository), not a production binding.
    single<PersonRepository> { PersistencePersonRepository(get()) }
    single { SignUpUseCase(get(), get(), get()) }
}

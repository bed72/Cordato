package com.bed.cordato.features.identity.infrastructure.di

import org.koin.dsl.module

import com.bed.cordato.core.application.ports.ClockPort
import com.bed.cordato.core.application.ports.IdGeneratorPort
import com.bed.cordato.core.infrastructure.adapters.ClockAdapter
import com.bed.cordato.core.infrastructure.adapters.IdGeneratorAdapter

import com.bed.cordato.features.identity.application.use_cases.SignUpUseCase
import com.bed.cordato.features.identity.application.ports.PasswordHasherPort
import com.bed.cordato.features.identity.application.repositories.PersonRepository

import com.bed.cordato.features.identity.infrastructure.adapters.PasswordHasherAdapter
import com.bed.cordato.features.identity.infrastructure.repositories.InMemoryPersonRepository

/**
 * Composition root for identity — the only place ports are bound to adapters. DI stays
 * out of domain and application entirely, per the layer rules.
 */
val identityModule = module {
    single<ClockPort> { ClockAdapter() }
    single<IdGeneratorPort> { IdGeneratorAdapter() }
    single<PasswordHasherPort> { PasswordHasherAdapter() }
    single<PersonRepository> { InMemoryPersonRepository() }
    single { SignUpUseCase(get(), get(), get()) }
}

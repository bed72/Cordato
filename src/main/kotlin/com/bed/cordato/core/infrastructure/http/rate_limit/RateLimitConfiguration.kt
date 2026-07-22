package com.bed.cordato.core.infrastructure.http.rate_limit

import java.time.Duration

import io.micronaut.context.annotation.ConfigurationInject
import io.micronaut.context.annotation.ConfigurationProperties

/**
 * External binding for `cordato.rate-limit.*` — one config type, two nested tiers, mirroring how
 * [com.bed.cordato.core.infrastructure.persistence.configurations.DatabaseConfiguration]/
 * [com.bed.cordato.core.infrastructure.persistence.configurations.ValkeyConfiguration] bind external
 * config, except here the values are ordinary (non-secret) tunables so they come straight from
 * `application.properties` rather than the process environment. A Kotlin nested class with no `inner`
 * keyword is a static nested class, exactly the shape Micronaut expects for a nested
 * `@ConfigurationProperties` — each of [General]/[Sensitive] is its own injectable bean
 * (`cordato.rate-limit.general.*`/`cordato.rate-limit.sensitive.*`), consumed directly by
 * `RateLimitFilter` rather than through this outer, property-less type.
 */
@ConfigurationProperties("cordato.rate-limit")
class RateLimitConfiguration {

    /** `general` tier: the default budget every unannotated route falls back to. */
    @ConfigurationProperties("general")
    class General @ConfigurationInject constructor(val limit: Long, val window: Duration)

    /** `sensitive` tier: the stricter budget a route opts into via `@RateLimited`. */
    @ConfigurationProperties("sensitive")
    class Sensitive @ConfigurationInject constructor(val limit: Long, val window: Duration)
}

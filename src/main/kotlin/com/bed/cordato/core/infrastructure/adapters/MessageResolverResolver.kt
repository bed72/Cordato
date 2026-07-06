package com.bed.cordato.core.infrastructure.adapters

import io.micronaut.context.LocalizedMessageSource

import com.bed.cordato.core.application.ports.MessageResolverPort

/**
 * The one adapter that wraps Micronaut's request-scoped [io.micronaut.context.LocalizedMessageSource] behind core's own
 * [com.bed.cordato.core.application.ports.MessageResolverPort], so the HTTP edge depends on our contract, not the framework type. The injected source
 * is request-aware (micronaut-http-server proxies it per `Accept-Language`), so this stays a plain
 * singleton — it just delegates, resolving each key against the current request's locale and falling back
 * to the key when the bundle lacks it. Annotation-free; wired in [com.bed.cordato.core.main.CoreFactory].
 */
class MessageResolverResolver(private val messages: LocalizedMessageSource) : MessageResolverPort {
    override fun invoke(key: String, variables: Map<String, Any>): String =
        messages.getMessageOrDefault(key, key, variables)
}
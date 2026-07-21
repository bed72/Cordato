package com.bed.cordato.core.application.driven.ports

import com.bed.cordato.core.domain.value_objects.LoggableValueObject

/**
 * The single seam `application/` and `infrastructure/` log through — no package outside this
 * port's own adapter names a concrete logging library. `component` is passed per call (not fixed
 * on the bean, since the port is wired as one singleton) so the operator can still filter/elevate
 * by origin at the `logback.xml` level. `attributes` is restricted to [LoggableValueObject] rather
 * than `Any?` so a caller can't log an entire entity by accident; the adapter layers a sensitive-key
 * denylist on top, independent of this restriction.
 */
interface LoggerPort {
    fun debug(component: String, message: String, attributes: Map<String, LoggableValueObject> = emptyMap())

    fun info(component: String, message: String, attributes: Map<String, LoggableValueObject> = emptyMap())

    fun warn(component: String, message: String, attributes: Map<String, LoggableValueObject> = emptyMap())

    fun error(
        component: String,
        message: String,
        attributes: Map<String, LoggableValueObject> = emptyMap(),
        cause: Throwable? = null,
    )
}

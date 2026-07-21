package com.bed.cordato.core.factories

import com.bed.cordato.core.application.driven.ports.LoggerPort
import com.bed.cordato.core.domain.value_objects.LoggableValueObject

/**
 * Recording [LoggerPort] fake for `@MicronautTest`s that have no reason to exercise real SLF4J/Logback:
 * every call is captured in [events] instead of reaching a real logger, so a test can assert a log
 * happened without asserting on log output.
 */
class FakeLoggerPort : LoggerPort {
    data class Event(
        val level: String,
        val component: String,
        val message: String,
        val attributes: Map<String, LoggableValueObject>,
        val cause: Throwable? = null,
    )

    val events = mutableListOf<Event>()

    override fun debug(component: String, message: String, attributes: Map<String, LoggableValueObject>) {
        events += Event("DEBUG", component, message, attributes)
    }

    override fun info(component: String, message: String, attributes: Map<String, LoggableValueObject>) {
        events += Event("INFO", component, message, attributes)
    }

    override fun warn(component: String, message: String, attributes: Map<String, LoggableValueObject>) {
        events += Event("WARN", component, message, attributes)
    }

    override fun error(
        component: String,
        message: String,
        attributes: Map<String, LoggableValueObject>,
        cause: Throwable?,
    ) {
        events += Event("ERROR", component, message, attributes, cause)
    }
}

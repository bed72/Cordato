package com.bed.cordato.core.infrastructure.adapters

import org.slf4j.Logger
import org.slf4j.spi.LoggingEventBuilder

import com.bed.cordato.core.application.driven.ports.LoggerPort
import com.bed.cordato.core.domain.value_objects.LoggableValueObject

/**
 * Real [LoggerPort] over SLF4J 2.x's fluent API (`atInfo().addKeyValue(...)`), so `component` and
 * `attributes` stay structured key-value pairs on the `LoggingEvent` rather than baked into the
 * formatted message — the shape an OTEL `LogRecord`'s attributes expect, and what `logback.xml`'s
 * `%kvp` converter renders. [logger] is a single SLF4J logger backing every call, received via
 * constructor (built by [com.bed.cordato.core.main.CoreFactory], the one place a concrete adapter's
 * concrete dependency is constructed, same as every other adapter there); per-call `component` is
 * what lets `logback.xml` still filter/elevate by origin.
 *
 * Sensitive attribute names (case-insensitive, [SENSITIVE_KEYS]) are masked before emission — a
 * defense-in-depth net independent of [LoggableValueObject]'s type restriction: the type stops "wrong
 * object passed", this stops "right field, sensitive value, key name gave it away".
 */
class Slf4jLoggerAdapter(private val logger: Logger) : LoggerPort {

    override fun debug(component: String, message: String, attributes: Map<String, LoggableValueObject>) =
        emit(logger.atDebug(), component, message, attributes)

    override fun info(component: String, message: String, attributes: Map<String, LoggableValueObject>) =
        emit(logger.atInfo(), component, message, attributes)

    override fun warn(component: String, message: String, attributes: Map<String, LoggableValueObject>) =
        emit(logger.atWarn(), component, message, attributes)

    override fun error(
        component: String,
        message: String,
        attributes: Map<String, LoggableValueObject>,
        cause: Throwable?,
    ) {
        val event = logger.atError()
        if (cause != null) event.setCause(cause)

        emit(event, component, message, attributes)
    }

    private fun emit(
        event: LoggingEventBuilder,
        component: String,
        message: String,
        attributes: Map<String, LoggableValueObject>,
    ) {
        event.addKeyValue("component", component)
        attributes.forEach { (key, value) -> event.addKeyValue(key, redact(key, value)) }
        event.setMessage(message)
        event.log()
    }

    private fun redact(key: String, value: LoggableValueObject): Any =
        if (SENSITIVE_KEYS.any { it.equals(key, ignoreCase = true) }) MASK else rawValue(value)

    private fun rawValue(value: LoggableValueObject): Any = when (value) {
        is LoggableValueObject.Text -> value.value
        is LoggableValueObject.Number -> value.value
        is LoggableValueObject.Flag -> value.value
        is LoggableValueObject.Moment -> value.value
    }

    private companion object {
        const val MASK = "***"
        val SENSITIVE_KEYS = setOf("password", "token", "email", "authorization", "secret")
    }
}

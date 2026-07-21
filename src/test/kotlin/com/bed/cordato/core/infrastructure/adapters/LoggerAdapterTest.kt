package com.bed.cordato.core.infrastructure.adapters

import org.slf4j.LoggerFactory

import kotlin.test.Test
import kotlin.test.AfterTest
import kotlin.test.BeforeTest

import kotlin.test.assertEquals
import ch.qos.logback.classic.Level
import ch.qos.logback.classic.Logger
import ch.qos.logback.core.read.ListAppender
import ch.qos.logback.classic.spi.ILoggingEvent

import com.bed.cordato.core.domain.value_objects.LoggableValueObject

internal class LoggerAdapterTest {

    private val appender = ListAppender<ILoggingEvent>()
    private val logger = LoggerFactory.getLogger("com.bed.cordato") as Logger
    private val adapter = Slf4jLoggerAdapter(logger)

    @BeforeTest
    fun setUp() {
        logger.level = Level.DEBUG
        appender.start()
        logger.addAppender(appender)
    }

    @AfterTest
    fun tearDown() {
        logger.detachAppender(appender)
    }

    private fun keyValues(event: ILoggingEvent): Map<String, Any?> =
        event.keyValuePairs.associate { it.key to it.value }

    @Test
    fun `debug emits at DEBUG level`() {
        adapter.debug("Component", "a debug message")

        assertEquals(Level.DEBUG, appender.list.single().level)
    }

    @Test
    fun `info emits at INFO level with component, message and attributes`() {
        adapter.info("Component", "did a thing", mapOf("person_id" to LoggableValueObject.Text("p-1")))

        val event = appender.list.single()
        assertEquals(Level.INFO, event.level)
        assertEquals("did a thing", event.message)
        assertEquals("Component", keyValues(event)["component"])
        assertEquals("p-1", keyValues(event)["person_id"])
    }

    @Test
    fun `warn emits at WARN level`() {
        adapter.warn("Component", "a warning")

        assertEquals(Level.WARN, appender.list.single().level)
    }

    @Test
    fun `error emits at ERROR level, with component and message in the right slots, and propagates the cause`() {
        val cause = IllegalStateException("boom")

        adapter.error("Component", "it failed", cause = cause)

        val event = appender.list.single()
        assertEquals(Level.ERROR, event.level)
        assertEquals("it failed", event.message)
        assertEquals("Component", keyValues(event)["component"])
        assertEquals("boom", event.throwableProxy.message)
    }

    @Test
    fun `a sensitive attribute name is masked, case-insensitively`() {
        adapter.info(
            "Component",
            "logging in",
            mapOf(
                "password" to LoggableValueObject.Text("hunter2"),
                "Authorization" to LoggableValueObject.Text("Bearer xyz"),
            ),
        )

        val values = keyValues(appender.list.single())
        assertEquals("***", values["password"])
        assertEquals("***", values["Authorization"])
    }

    @Test
    fun `an attribute whose name is not sensitive is emitted intact`() {
        adapter.info("Component", "status check", mapOf("status" to LoggableValueObject.Number(200)))

        assertEquals(200, keyValues(appender.list.single())["status"])
    }
}

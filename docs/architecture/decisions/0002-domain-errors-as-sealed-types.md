# ADR 0002: Domain errors as sealed types, not exceptions

Domain errors are `sealed class`/`sealed interface` hierarchies returned from use cases, not thrown
exceptions — keeps error paths exhaustively checked by the compiler in `when` and testable without
`assertThrows`.

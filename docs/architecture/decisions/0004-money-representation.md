# ADR 0004: Money representation

Money is BRL-only — no multi-currency abstraction, that complexity isn't needed here. Represent it
internally as an integer number of cents (or a fixed-scale `BigDecimal`), never `Double`: the domain's
repeated "exact value" invariant (an expense/budget amount is always exact) is a floating-point
correctness requirement, not a style preference. Display formatting (`R$ 1.234,56`) is a presentation
concern, kept out of the value object's construction/arithmetic.

from enum import Enum


class Perspective(Enum):
    """An expense seen from the reader's point of view — a couple is a point of view, not an owner.

    `MINE` when the reader owns the expense, `THEIRS` when the partner does. Derived at read-time from
    the expense's owner and the reader's id; never stored.
    """

    MINE = "mine"
    THEIRS = "theirs"

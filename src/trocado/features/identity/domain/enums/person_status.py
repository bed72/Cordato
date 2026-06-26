from enum import Enum


class PersonStatus(Enum):
    """The lifecycle state of a person. `deleted` is reached only by account deletion."""

    ACTIVE = "active"
    DELETED = "deleted"

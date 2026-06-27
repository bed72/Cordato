"""Shared HTTP media types for the web edge.

BlackSheep hardcodes these as byte literals internally and exports no constant, so the web adapters of
every module share this single source instead of repeating ``b"application/json"`` per controller. This
is an infrastructure concern of the HTTP edge — not a domain set — so it lives here and never in
``domain/enums/``. The day a second media type appears, this graduates into a ``bytes``-valued ``Enum``
in this same module, earning that shape only once there is a closed set of more than one to model.
"""

JSON = b"application/json"

from trocado.features.identity.application.interfaces.pair_dissolver_interface import PairDissolverInterface


class FakePairDissolver(PairDissolverInterface):
    """Records which people had their pair dissolved. Idempotent by contract — it never raises, paired or not."""

    def __init__(self) -> None:
        self.dissolved: list[str] = []

    async def dissolve_for_person(self, person_id: str) -> None:
        self.dissolved.append(person_id)

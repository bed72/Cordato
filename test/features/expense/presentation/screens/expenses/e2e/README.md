# Expenses E2E

Flows preparados, **não executados em dispositivo**. Reutilizam a
[fixture e o preparo de Expense](../../expense/e2e/README.md), porta 8771.
Dashboard e rotas de Expense estão registrados; use uma build compilável e
confirme a composição no dispositivo, sem presumir E2E validado pelo registro.

- `Success.yaml`: entrada pela Dashboard, listagem e exclusão confirmada.
- `Failure.yaml`: falha remota preserva o item; nova confirmação permite retry.
- `Loading.yaml`: exclusão retida mantém o item e só conclui após liberação.

```bash
maestro test test/features/expense/presentation/screens/expenses/e2e/Success.yaml
maestro test test/features/expense/presentation/screens/expenses/e2e/Failure.yaml
maestro test test/features/expense/presentation/screens/expenses/e2e/Loading.yaml
```

Use somente a fixture local e execute sequencialmente após iniciar o servidor,
encaminhar a porta e compilar com a base indicada no README de Expense. O preparo
apaga dados/keychain. Seletores, gestos e feedback ainda precisam de validação real;
YAML existente não comprova E2E. Paginação, filtros, retorno de edição e lifecycle
continuam cobertos por testes Flutter.

`ExpensesScreen` navega diretamente pelo BuildContext do mixin para voltar e
editar; não recebe `onBackPressed`, `onExpensePressed` ou `onExpensesChanged`.
Os argumentos contêm somente período/categoria. Edição aplica apenas a entidade
confirmada; cancelamento preserva a lista. Ao voltar da listagem, Dashboard e
Metrics recarregam mesmo sem alterações. Testes Flutter cobrem retorno pelo app
bar e sistema; o gesto nativo ainda precisa de validação real em dispositivo.

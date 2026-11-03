migrate((app) => {
    const metrics = app.findCollectionByNameOrId("expense_monthly_metrics")
    metrics.name = "metrics"
    app.save(metrics)
}, () => {
    throw new Error("Rollback automático bloqueado; preservar o contrato de leitura de metrics.")
})

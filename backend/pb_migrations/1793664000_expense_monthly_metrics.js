migrate((app) => {
    const principal = '@request.auth.id != "" && @request.auth.collectionName = "users" && @request.auth.verified = true'
    const ownMetrics = principal + " && owner = @request.auth.id"
    const metrics = new Collection({
        type: "view",
        name: "expense_monthly_metrics",
        listRule: ownMetrics,
        viewRule: ownMetrics,
        createRule: null,
        updateRule: null,
        deleteRule: null,
        viewQuery: `
            SELECT
                MIN(e.id) AS id,
                e.owner AS owner,
                CAST(substr(e.occurred_on, 1, 7) || '-01' AS TEXT) AS start_date,
                CAST(date(substr(e.occurred_on, 1, 7) || '-01', '+1 month', '-1 day') AS TEXT) AS end_date,
                CAST(SUM(CAST(e.amount AS INTEGER)) AS TEXT) AS total_amount,
                (
                    SELECT json_group_array(json_object(
                        'category', grouped.category,
                        'total_amount', grouped.total_amount,
                        'percentage', grouped.percentage
                    ))
                    FROM (
                        SELECT
                            x.category AS category,
                            CAST(SUM(CAST(x.amount AS INTEGER)) AS TEXT) AS total_amount,
                            ROUND(
                                100.0 * SUM(CAST(x.amount AS INTEGER)) /
                                SUM(SUM(CAST(x.amount AS INTEGER))) OVER (),
                                2
                            ) AS percentage
                        FROM expenses AS x
                        WHERE x.owner = e.owner
                            AND substr(x.occurred_on, 1, 7) = substr(e.occurred_on, 1, 7)
                        GROUP BY x.category
                        ORDER BY SUM(CAST(x.amount AS INTEGER)) DESC, x.category ASC
                    ) AS grouped
                ) AS categories
            FROM expenses AS e
            WHERE e.occurred_on != ''
            GROUP BY e.owner, substr(e.occurred_on, 1, 7)
        `,
    })
    app.save(metrics)
}, () => {
    throw new Error("Rollback automático bloqueado; preservar o contrato de leitura das métricas.")
})

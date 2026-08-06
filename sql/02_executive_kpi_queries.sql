-- ============================================================
-- SQL Executive KPI Queries
-- Warehouse: DuckDB (analytics_dw.duckdb)
-- ============================================================

-- 1. Executive High-Level KPI Summary
SELECT 
    COUNT(*) AS total_tickets,
    COUNT(DISTINCT customer_id) AS total_customers,
    ROUND(SUM(order_value), 2) AS total_order_revenue,
    ROUND(AVG(order_value), 2) AS avg_order_value,
    ROUND(SUM(order_value) / COUNT(DISTINCT customer_id), 2) AS avg_customer_lifetime_spend,
    ROUND(AVG(imputed_csat), 2) AS overall_avg_csat,
    ROUND(COUNT(CASE WHEN sla_status = 'Within SLA' THEN 1 END) * 100.0 / COUNT(*), 2) AS sla_compliance_pct,
    COUNT(CASE WHEN routing_priority = 'URGENT - High Value VIP' THEN 1 END) AS high_value_vip_urgent_tickets
FROM gold_customer_experience;

-- 2. SLA Compliance & CSAT Breakdown by Issue Type
SELECT 
    issue_type,
    COUNT(*) AS ticket_volume,
    ROUND(COUNT(CASE WHEN sla_status = 'SLA Breached' THEN 1 END) * 100.0 / COUNT(*), 2) AS breach_rate_pct,
    ROUND(AVG(imputed_csat), 2) AS avg_csat,
    ROUND(AVG(order_value), 2) AS avg_order_value
FROM gold_customer_experience
GROUP BY issue_type
ORDER BY ticket_volume DESC;

-- 3. Product Category Experience Matrix
SELECT
    product_category,
    COUNT(*) AS ticket_count,
    ROUND(AVG(order_value), 2) AS avg_product_order_value,
    ROUND(AVG(imputed_csat), 2) AS avg_csat,
    ROUND(COUNT(CASE WHEN routing_priority = 'URGENT - High Value VIP' THEN 1 END) * 100.0 / COUNT(*), 2) AS vip_urgent_pct
FROM gold_customer_experience
GROUP BY product_category
ORDER BY ticket_count DESC;

-- 4. Monthly Customer Cohort Retention (Window-Function Analysis)
-- Runs against raw_orders (Bronze layer) rather than the ticket-joined Gold table,
-- since retention is an order-behavior question and gold_customer_experience only
-- contains orders that generated a support ticket.
-- Method: assign each customer to an acquisition cohort (their first order month)
-- via MIN(...) OVER (PARTITION BY customer_id), then measure what share of that
-- cohort placed another order N months later.
WITH customer_orders AS (
    SELECT
        customer_id,
        date_trunc('month', order_date) AS order_month
    FROM raw_orders
),
customer_cohorts AS (
    SELECT
        customer_id,
        order_month,
        MIN(order_month) OVER (PARTITION BY customer_id) AS cohort_month
    FROM customer_orders
),
cohort_activity AS (
    SELECT
        cohort_month,
        DATEDIFF('month', cohort_month, order_month) AS months_since_first_order,
        COUNT(DISTINCT customer_id) AS active_customers
    FROM customer_cohorts
    GROUP BY cohort_month, months_since_first_order
),
cohort_sizes AS (
    SELECT cohort_month, active_customers AS cohort_size
    FROM cohort_activity
    WHERE months_since_first_order = 0
)
SELECT
    c.cohort_month,
    s.cohort_size,
    c.months_since_first_order,
    c.active_customers,
    ROUND(c.active_customers * 100.0 / s.cohort_size, 2) AS retention_pct
FROM cohort_activity c
JOIN cohort_sizes s USING (cohort_month)
ORDER BY c.cohort_month, c.months_since_first_order;
-- Observed result: retention holds flat around ~54-57% for every cohort/month pair
-- (not a typical decaying retention curve). That is an honest artifact of the data
-- generator, not the query: order_date is sampled independently and uniformly across
-- the 2-year window for every order, so no real repeat-purchase behavior is encoded.
-- The query is technique-correct and would surface a genuine decay curve on real
-- transaction data where purchases cluster in time per customer.

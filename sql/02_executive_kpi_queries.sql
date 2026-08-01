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
    ROUND(AVG(lifetime_spend), 2) AS avg_customer_lifetime_spend,
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

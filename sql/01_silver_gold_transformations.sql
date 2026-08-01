-- ============================================================
-- SQL Transformation: Bronze (Raw) -> Silver -> Gold Layer
-- Warehouse: DuckDB (analytics_dw.duckdb)
-- Target Table: gold_customer_experience
-- ============================================================

CREATE OR REPLACE TABLE gold_customer_experience AS

-- 1. SILVER ORDERS: Clean refund anomalies & calculate customer window metrics
WITH cleaned_orders AS (
    SELECT 
        order_id,
        customer_id,
        product_id,
        CASE WHEN amount < 0 THEN 0 ELSE amount END AS clean_amount,
        order_date,
        ROW_NUMBER() OVER(PARTITION BY customer_id ORDER BY order_date) AS customer_order_seq,
        SUM(CASE WHEN amount < 0 THEN 0 ELSE amount END) OVER(PARTITION BY customer_id) AS lifetime_spend
    FROM raw_orders
),

-- 2. SILVER TICKETS: Impute null CSAT scores & derive SLA compliance status
cleaned_tickets AS (
    SELECT 
        ticket_id,
        order_id,
        issue_type,
        COALESCE(csat_score, 3) AS imputed_csat,
        is_resolved,
        CASE WHEN is_resolved = FALSE THEN 'SLA Breached' ELSE 'Within SLA' END AS sla_status
    FROM raw_tickets
)

-- 3. GOLD LAYER: Join domains & compute routing priority classification
SELECT 
    t.ticket_id,
    t.issue_type,
    t.imputed_csat,
    t.sla_status,
    o.customer_id,
    o.clean_amount AS order_value,
    o.lifetime_spend,
    o.customer_order_seq,
    p.title AS product_name,
    p.category AS product_category,
    
    -- Business Routing Priority Logic
    CASE 
        WHEN o.lifetime_spend > 2500 AND t.sla_status = 'SLA Breached' 
        THEN 'URGENT - High Value VIP'
        ELSE 'Standard' 
    END AS routing_priority

FROM cleaned_tickets t
JOIN cleaned_orders o ON t.order_id = o.order_id
JOIN raw_products p ON o.product_id = p.product_id;

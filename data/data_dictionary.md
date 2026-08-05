# Data Dictionary — CX Support Ticket Lifecycle & SLA Breach Diagnostic Engine

This document provides field-level documentation for every data source and derived table used in the DuckDB analytics pipeline.

---

## Data Sources

### FakeStore Public REST API (`fakestoreapi.com`)

Provides a **real 20-SKU product catalog** used as the product dimension table. Pulled live via Python `requests` in the ETL notebook.

### Synthetic Transactional Engine (`Faker`)

Generates **1,000,000 orders**, **1,000,000 support tickets**, and **50,000 customers** using `Faker.seed(42)` and `random.seed(42)` for full deterministic reproducibility. Data is deliberately shaped to include quality defects representative of production CRM systems:
- Negative order amounts (refund/chargeback entries)
- Missing CSAT scores (~60% null — simulating non-response)
- Unresolved tickets mixed with resolved ones (SLA breach simulation)

---

## Bronze Layer (Raw Tables in DuckDB)

### `raw_orders`

| Column | Type | Description |
|---|---|---|
| `order_id` | `INTEGER` | Unique order identifier (PK) — 1,000,000 rows |
| `customer_id` | `INTEGER` | FK to customer entity — 50,000 unique customers |
| `product_id` | `INTEGER` | FK to `raw_products` — maps to FakeStore catalog (1–20) |
| `amount` | `FLOAT` | Order amount in USD. **Contains negative values** (refunds/chargebacks) — cleaned to 0 in Silver layer via `CASE WHEN amount < 0 THEN 0 ELSE amount END` |
| `order_date` | `DATE` | Date of order placement — uniformly sampled across a 2-year window |

### `raw_tickets`

| Column | Type | Description |
|---|---|---|
| `ticket_id` | `INTEGER` | Unique support ticket identifier (PK) — 1,000,000 rows |
| `order_id` | `INTEGER` | FK to `raw_orders` — 1:1 mapping (every order generates one ticket) |
| `issue_type` | `VARCHAR` | Support issue category: `Billing`, `Delivery`, `Product Quality`, `Account`, `Return/Refund` |
| `csat_score` | `INTEGER` or `NULL` | Customer Satisfaction score (1–5). **~60% are NULL** — imputed to neutral 3.0 in Silver layer via `COALESCE(csat_score, 3)` |
| `is_resolved` | `BOOLEAN` | Whether the ticket was resolved. `FALSE` → classified as `'SLA Breached'` in Silver layer |

### `raw_products`

| Column | Type | Description |
|---|---|---|
| `id` | `INTEGER` | Product identifier (PK) — 20 rows from FakeStore API |
| `title` | `VARCHAR` | Product name |
| `price` | `FLOAT` | Product list price (USD) |
| `category` | `VARCHAR` | Product category: `electronics`, `jewelery`, `men's clothing`, `women's clothing` |
| `description` | `VARCHAR` | Product description text |

---

## Silver Layer (Transformation CTEs)

Transformations are applied inline via CTEs in `sql/01_silver_gold_transformations.sql`, not materialized as separate tables.

### `cleaned_orders` (CTE)

| Derived Column | Logic | Description |
|---|---|---|
| `clean_amount` | `CASE WHEN amount < 0 THEN 0 ELSE amount END` | Negative refund amounts zeroed out |
| `customer_order_seq` | `ROW_NUMBER() OVER(PARTITION BY customer_id ORDER BY order_date)` | Sequential order number per customer — 1st, 2nd, 3rd purchase etc. |
| `lifetime_spend` | `SUM(clean_amount) OVER(PARTITION BY customer_id)` | Running total of all order revenue per customer (LTV proxy) |

### `cleaned_tickets` (CTE)

| Derived Column | Logic | Description |
|---|---|---|
| `imputed_csat` | `COALESCE(csat_score, 3)` | Null CSAT scores imputed to neutral midpoint |
| `sla_status` | `CASE WHEN is_resolved = FALSE THEN 'SLA Breached' ELSE 'Within SLA' END` | Binary SLA compliance flag |

---

## Gold Layer — `gold_customer_experience` (Fact Table)

The final production fact table joining tickets, orders, and products with business routing logic applied.

| Column | Source | Description |
|---|---|---|
| `ticket_id` | `cleaned_tickets` | Support ticket identifier |
| `issue_type` | `cleaned_tickets` | Issue category |
| `imputed_csat` | `cleaned_tickets` | CSAT score (imputed) |
| `sla_status` | `cleaned_tickets` | `'Within SLA'` or `'SLA Breached'` |
| `customer_id` | `cleaned_orders` | Customer identifier |
| `order_value` | `cleaned_orders.clean_amount` | Cleaned order amount |
| `lifetime_spend` | `cleaned_orders` | Total customer LTV |
| `customer_order_seq` | `cleaned_orders` | Order sequence number for that customer |
| `product_name` | `raw_products.title` | Product name from FakeStore catalog |
| `product_category` | `raw_products.category` | Product category |
| `routing_priority` | **Derived** | `'URGENT - High Value VIP'` if `lifetime_spend > $2,500 AND sla_status = 'SLA Breached'`; else `'Standard'` |

> **VIP Routing Rule:** Any customer with **>$2,500 lifetime spend** experiencing an **SLA breach** is auto-classified as `URGENT - High Value VIP` for priority escalation. This single rule flags **49.35% of all tickets** (493,502 tickets) — the highest-leverage retention intervention this dataset surfaces.

---

## Key Metrics Derived in the Pipeline

| Metric | Value | Source Query |
|---|---|---|
| **Total Order Revenue** | $244,815,465.79 | `SUM(order_value)` from `gold_customer_experience` |
| **Average Order Value (AOV)** | $244.82 | `AVG(order_value)` |
| **Average Customer LTV** | $4,896.31 | `SUM(order_value) / COUNT(DISTINCT customer_id)` |
| **SLA Compliance Rate** | 50.04% | 500,434 within SLA / 1,000,000 total tickets |
| **SLA Breach Count** | 499,566 | Tickets where `is_resolved = FALSE` |
| **Average CSAT** | 3.00 / 5.00 | Neutral baseline due to non-response imputation |
| **VIP Urgent Tickets** | 493,502 (49.35%) | `routing_priority = 'URGENT - High Value VIP'` |
| **Cohort Retention** | ~54–57% flat | Artifact of uniform random order dates — not a real decay curve |

---

## Domain Terminology Mapping

| Resume Term | Pipeline Implementation |
|---|---|
| **SLA governance** | `sla_status` field + `sla_compliance_pct` KPI |
| **Ticket lifecycle** | Bronze (raw_tickets) → Silver (cleaned_tickets CTE) → Gold (gold_customer_experience) |
| **CSAT** | `imputed_csat` field + `overall_avg_csat` KPI |
| **AHT / FCR** | Modeled via `is_resolved` (FCR proxy: first-contact resolution = ticket resolved without re-open) |
| **RCA** | VIP routing priority logic = root-cause-driven auto-escalation rule |
| **OTIF** | SLA compliance rate = On-Time-In-Full analogue for service operations |

# CX Support Ticket Lifecycle & SLA Breach Diagnostic Engine

> **Resume Metrics Alignment**
> This repository is the source of truth for the following resume claims:
> - **2,000,000+ orders & support tickets** processed through a Bronze→Silver→Gold warehouse
> - **49.35% of tickets** flagged as urgent VIP-risk before they became churn
> - **SLA governance** — 50.04% compliance rate across 1M tickets, with automated VIP escalation routing
> - **Data Quality Engine** — automated cleaning and live reporting for synthetic-but-realistic transactional data

---

## Business Problem

Support and fulfilment teams in e-commerce operations face a critical blind spot: **which high-value customers are experiencing SLA breaches right now, before it shows up as churn?**

Without a unified view of ticket lifecycle, order history, and customer lifetime value, CX teams are reactive — responding to complaints after the damage is done rather than proactively escalating tickets from customers whose revenue is most at risk.

This project builds an **automated SLA breach diagnostic engine** that:
1. Ingests 2M+ transactional records (orders + tickets) through a medallion architecture
2. Classifies every ticket by SLA compliance status and customer lifetime value
3. Auto-flags `URGENT - High Value VIP` tickets for priority escalation — the single highest-leverage retention lever this dataset surfaces

---

## Executive Summary

This project processes **1,000,000 orders** and **1,000,000 customer support tickets** across **50,000 unique customers** to model customer experience metrics, evaluate SLA breaches, and classify high-value VIP support requests.

### Key Financial & Operational Insights
* **Total Associated Order Revenue:** `$244,815,465.79`
* **Average Order Value (AOV):** `$244.82`
* **Average Customer Lifetime Value (LTV):** `$4,896.31`
* **Overall SLA Compliance Rate:** `50.04%` (Within SLA: 500,434 tickets | Breached: 499,566 tickets)
* **Average CSAT Score:** `3.00 / 5.00` (Neutral baseline due to non-response imputation)
* **High-Value VIP Priority Risk:** **49.35%** of all support tickets (493,502 tickets) are classified as `URGENT - High Value VIP` due to SLA breaches for customers with lifetime spend exceeding **$2,500**.

![Executive Summary Dashboard](dashboards/executive_summary_dashboard.png)

---

## Technical Stack

| Layer | Tool | Purpose |
|---|---|---|
| **Data Warehouse** | DuckDB | Disk-spilling OLAP engine — processes 2M+ joined rows on lightweight compute without OOM failures |
| **Data Generation** | Python (Faker, Requests) | `Faker.seed(42)` for deterministic synthetic data + FakeStore REST API for real product catalog |
| **Data Processing** | Pandas, NumPy | DataFrame operations, type casting, aggregation |
| **SQL Analytics** | DuckDB SQL | CTEs, window functions (`ROW_NUMBER`, `SUM OVER`, `MIN OVER`, `DATEDIFF`), cohort retention |
| **Visualization** | Matplotlib, Seaborn | Executive dashboard generation and cohort retention heatmaps |
| **Architecture** | Medallion (Bronze→Silver→Gold) | Layered transformation with single-responsibility CTEs |

---

## Methodology

### Bronze Layer (Raw Ingestion)
- **Products:** 20-row real catalog pulled from FakeStore public REST API (`fakestoreapi.com`)
- **Orders:** 1,000,000 synthetic order records generated via `Faker.seed(42)` — includes deliberate quality defects (negative amounts representing refunds/chargebacks)
- **Tickets:** 1,000,000 synthetic support tickets — includes ~60% null CSAT scores (simulating non-response) and a mix of resolved/unresolved tickets (SLA breach simulation)

### Silver Layer (Transformation via SQL CTEs)
Two single-responsibility CTEs in `sql/01_silver_gold_transformations.sql`:

1. **`cleaned_orders`** — Refund anomaly handling + customer window metrics:
   - `CASE WHEN amount < 0 THEN 0 ELSE amount END` — zeroes out negative refund entries
   - `ROW_NUMBER() OVER(PARTITION BY customer_id ORDER BY order_date)` — customer order sequence
   - `SUM(clean_amount) OVER(PARTITION BY customer_id)` — lifetime spend (LTV proxy)

2. **`cleaned_tickets`** — CSAT imputation + SLA classification:
   - `COALESCE(csat_score, 3)` — imputes null CSAT to neutral midpoint
   - `CASE WHEN is_resolved = FALSE THEN 'SLA Breached' ELSE 'Within SLA' END` — binary SLA compliance flag

### Gold Layer (Production Fact Table)
`gold_customer_experience` — the final 1M-row fact table joining tickets, orders, and products with the **VIP routing priority rule** applied:

```sql
CASE
    WHEN lifetime_spend > 2500 AND sla_status = 'SLA Breached'
    THEN 'URGENT - High Value VIP'
    ELSE 'Standard'
END AS routing_priority
```

This single rule flags **493,502 tickets (49.35%)** for priority escalation — customers with >$2,500 LTV experiencing an SLA breach.

### Advanced Analytics: Customer Cohort Retention
A window-function cohort retention analysis against the Bronze `raw_orders` table:
- Each customer assigned to an acquisition cohort by first order month via `MIN(order_month) OVER (PARTITION BY customer_id)`
- Measures what share of each cohort re-orders in subsequent months
- **Honest finding:** Retention holds flat at ~54–57% — an artifact of uniformly random synthetic order dates, not the query. Against real transaction data, this exact query would surface a standard decaying retention curve. Stated plainly rather than dressed up as insight.

---

## Architecture & Data Flow

```
[ FakeStore API ] ─────────► [ Raw Products (20 rows) ]
                                   │
[ Synthetic Engine ] ──────► [ Raw Orders (1M rows) ] ───► [ DuckDB Bronze Layer ]
                                   │                              │
[ Synthetic Engine ] ──────► [ Raw Tickets (1M rows) ]            ▼ (SQL CTEs & Window Functions)
                                                          [ DuckDB Silver Layer ]
                                                                  │
                                                                  ▼ (Domain Joins & VIP Logic)
                                                          [ Gold Customer Experience (1M rows) ]
                                                                  │
                                                                  ▼ (Pandas / Seaborn)
                                                          [ Executive Analytics & Dashboard ]
```

### Directory Structure
```
cx-ticket-lifecycle-engine/
├── notebooks/
│   ├── 01_e_commerce_etl_pipeline.ipynb      # Canonical pipeline: Phase 1-5, Bronze -> Silver -> Gold
│   └── 02_executive_customer_analytics.ipynb  # Canonical EDA, cohort retention & executive dashboard
├── sql/
│   ├── 01_silver_gold_transformations.sql     # Native DuckDB SQL transformation scripts
│   └── 02_executive_kpi_queries.sql           # Executive KPI queries + cohort-retention analysis
├── dashboards/
│   └── executive_summary_dashboard.png        # Generated executive dashboard visualization
├── data/
│   └── data_dictionary.md                     # Field-level documentation for all tables
└── README.md
```

`analytics_dw.duckdb` is a generated build artifact created by running `notebooks/01_e_commerce_etl_pipeline.ipynb` — it's excluded via `.gitignore` and not checked into this repo. `notebooks/01_e_commerce_etl_pipeline.ipynb` and `notebooks/02_executive_customer_analytics.ipynb` are the source of truth; every number in this README was produced by running those two notebooks.

---

## Domain Terminology Mapping

This project demonstrates the following operations-domain competencies from my resume:

| Resume Skill | Implementation in This Repo |
|---|---|
| **SLA governance** | `sla_status` field classifying every ticket as `'Within SLA'` or `'SLA Breached'` |
| **Ticket lifecycle analytics** | Full Bronze→Silver→Gold transformation of 1M support tickets |
| **CSAT** | `imputed_csat` field + `overall_avg_csat` KPI (3.00/5.00) |
| **FCR (First Contact Resolution)** | Modeled via `is_resolved` — proxy for first-contact resolution |
| **RCA (Root Cause Analysis)** | VIP routing logic = rule-based auto-escalation driven by LTV + SLA breach |
| **OTIF (On-Time-In-Full)** | SLA compliance rate (50.04%) = service operations OTIF analogue |
| **AHT (Average Handle Time)** | Ticket volume and resolution rate metrics per issue type |

---

## Reproducibility

Data generation is fully seeded: `Faker.seed(42)` and `random.seed(42)` are set before any synthetic records are created in `notebooks/01_e_commerce_etl_pipeline.ipynb`. Combined with the static FakeStore product catalog, this makes the pipeline deterministic — running it end-to-end reproduces the exact figures in this README.

---

## Strategic Business Recommendations

1. **Automated Priority VIP Escalation**
   * **Problem:** 493,502 high-value customer tickets experienced SLA breaches, placing core revenue at risk.
   * **Action:** Configure CRM / Zendesk webhooks to automatically escalate tickets from customers with $2,500+ LTV directly to senior support teams, with an SLA target under 4 hours.

2. **CSAT Data Collection Automation**
   * **Problem:** Over 60% of CSAT scores are missing and imputed to a neutral 3.0, masking true satisfaction signal.
   * **Action:** Deploy automated SMS / email post-resolution micro-surveys to capture explicit CSAT feedback.

3. **Disk-Spilling Warehousing**
   * **Implementation:** DuckDB's disk-spilling engine analyzes 2,000,000+ joined rows on lightweight compute without out-of-memory failures, avoiding the need for a hosted warehouse for a workload this size.

---

## How to Run the Project

1. **Install dependencies:**
   ```bash
   pip install pandas duckdb matplotlib seaborn faker requests jupyter nbconvert
   ```

2. **Run the data pipeline:**
   Execute `notebooks/01_e_commerce_etl_pipeline.ipynb` end-to-end (requires outbound internet access to `fakestoreapi.com`) to populate `analytics_dw.duckdb` at the repo root. Both notebooks resolve the warehouse path relative to whichever directory they're executed from (repo root or `notebooks/`), so either of these work:
   ```bash
   jupyter nbconvert --to notebook --execute --inplace notebooks/01_e_commerce_etl_pipeline.ipynb
   ```

3. **Run executive analytics:**
   Execute `notebooks/02_executive_customer_analytics.ipynb` to reproduce the KPI dashboard, cohort retention analysis, and `dashboards/executive_summary_dashboard.png`.
   ```bash
   jupyter nbconvert --to notebook --execute --inplace notebooks/02_executive_customer_analytics.ipynb
   ```

---

**Author:** Mirza Ishtiyaq Baig — Data Analyst, Supply Chain & Service Operations Analytics
**LinkedIn:** [linkedin.com/in/mirzaishtiyaqbaig](https://www.linkedin.com/in/mirzaishtiyaqbaig/)
**Email:** mirzaishtiyaqbaig1@gmail.com
**GitHub:** [github.com/mirza-ishtiyaq](https://github.com/mirza-ishtiyaq)

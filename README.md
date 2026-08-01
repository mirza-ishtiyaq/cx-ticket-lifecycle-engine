# 🛍️ E-Commerce Data Warehouse & Analytics Pipeline

A production-grade ELT (Extract, Load, Transform) data pipeline and executive analytics suite powered by **DuckDB**, **Pandas**, and **SQLAlchemy/SQL**.

---

## 📌 Executive Summary

This project processes **1,000,000 orders** and **1,000,000 customer support tickets** across **50,000 unique customers** to model customer experience metrics, evaluate SLA breaches, and classify high-value VIP support requests.

### Key Financial & Operational Insights
* **Total Associated Order Revenue:** `$244,815,466.00`
* **Average Order Value (AOV):** `$244.82`
* **Average Customer Lifetime Value (LTV):** `$5,139.73`
* **Overall SLA Compliance Rate:** `50.04%` (Within SLA: 500,434 tickets | Breached: 499,566 tickets)
* **Average CSAT Score:** `3.00 / 5.00` (Neutral baseline due to non-response imputation)
* **High-Value VIP Priority Risk:** **49.35%** of all support tickets (493,502 tickets) are classified as `URGENT - High Value VIP` due to SLA breaches for customers with lifetime spend exceeding **$2,500**.

---

## 🏗️ Architecture & Medallion Data Structure

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
e_commerce_ETL_Pipline/
├── analytics_dw.duckdb                      # DuckDB Analytical Data Warehouse Engine
├── Analysis.ipynb                           # Production Analysis Notebook (Root compatibility)
├── ETL_pipline.ipynb                        # Production Pipeline Notebook (Root compatibility)
├── notebooks/
│   ├── 01_e_commerce_etl_pipeline.ipynb     # Phase 1-5 ELT Pipeline (Bronze -> Silver -> Gold)
│   └── 02_executive_customer_analytics.ipynb # Production EDA & Executive Dashboard
├── sql/
│   ├── 01_silver_gold_transformations.sql   # Native DuckDB SQL Transformation Scripts
│   └── 02_executive_kpi_queries.sql         # Production Analytical KPI Queries
├── dashboards/
│   └── executive_summary_dashboard.png      # Generated Executive Dashboard Visualization
├── data/                                    # Raw CSV / Excel data directory
└── README.md                                # Project Documentation & Executive Insights
```

---

## 💡 Strategic Business Recommendations

1. **Automated Priority VIP Escalation**:
   * **Problem**: 493,502 high-value customer tickets experienced SLA breaches, placing core revenue at risk.
   * **Action**: Configure CRM / ZenDesk webhooks to automatically escalate tickets from customers with `$2,500+` LTV directly to senior support teams with an SLA target under 4 hours.

2. **CSAT Data Collection Automation**:
   * **Problem**: Over 60% of CSAT scores are missing and imputed to 3.0.
   * **Action**: Deploy automated SMS / Email post-resolution micro-surveys to capture explicit CSAT feedback.

3. **Disk-Spilling Warehousing**:
   * **Implementation**: Leveraging DuckDB disk-spilling engine allows analyzing 2,000,000+ joined rows on lightweight compute without Out-Of-Memory (OOM) failures.

---

## 🚀 How to Run the Project

1. **Install Dependencies**:
   ```bash
   pip install pandas duckdb matplotlib seaborn faker requests
   ```

2. **Run the Data Pipeline**:
   Open and execute `notebooks/01_e_commerce_etl_pipeline.ipynb` to populate `analytics_dw.duckdb`.

3. **Run Executive Analytics**:
   Open `notebooks/02_executive_customer_analytics.ipynb` or `Analysis.ipynb` to view EDA metrics and generate visualizations.

# 🏦 BankForge: Core Banking Data Warehouse & Analytics Engineering Pipeline

[![Python](https://img.shields.io/badge/Python-3.10%2B-blue.svg)](https://www.python.org/)
[![Architecture](https://img.shields.io/badge/Architecture-Medallion%20(Bronze%2FSilver%2FGold)-00A86B.svg)](#architecture-overview)
[![Data-Model](https://img.shields.io/badge/Schema-Star%20Schema%20%7C%20Kimball-orange.svg)](#dimensional-modeling--schema-design)
[![Volume](https://img.shields.io/badge/Scale-5.86M%20Records-blueviolet.svg)](#data-domains--scale)
[![Data-Quality](https://img.shields.io/badge/Data%20Quality-10%2F10%20Automated%20Tests%20Passing-brightgreen.svg)](#data-quality--integrity-framework)
[![UI](https://img.shields.io/badge/BI%20App-Streamlit-FF4B4B.svg)](#interactive-financial-analytics-dashboard)

A production-grade, local-first **Banking Data Engineering & Analytics Warehouse** implementing a **Medallion Architecture (Bronze &rarr; Silver &rarr; Gold)** over **5.86+ million banking records**. 

Built to simulate real-world retail banking ELT workloads, this pipeline ingests raw banking core extracts, models them into an enterprise Kimball star schema, enforces automated data quality gates, and serves curated Gold analytical marts to an interactive Streamlit BI workspace.

---

## 📌 Architecture Overview

The system processes end-to-end data pipelines using the **Medallion Architecture** pattern:

```
┌────────────────────────────────────────────────────────────────────────┐
│  BRONZE LAYER (Raw Landing & Staging)                                  │
│  • 10 Banking domains (Accounts, Loans, Cards, Txns, CSAT, etc.)       │
│  • Append-only staging (`stg_*`) with metadata lineage                 │
│  • Lineage columns added: `_source_file`, `_ingested_at`                │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ SQL ELT Pipeline (Type Casting, Cleansing)
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│  SILVER LAYER (Conformed Dimensional Model)                            │
│  • Conformed Star Schema (`dim_*` and `fact_*` tables)                 │
│  • Data standardization (credit tiering, name parsing, status codes)   │
│  • Referential integrity & foreign key constraints                     │
│  • Indexed for fast analytical join performance                        │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │ Pre-aggregated Business Views & Marts
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│  GOLD LAYER (Curated Business Intelligence & Analytics)                │
│  • Customer 360 & Net Worth Mart                                       │
│  • Card Fraud Intelligence & Merchant Category Risk Radar              │
│  • Loan Portfolio & Delinquency Mart                                   │
│  • Channel Liquidity & Velocity Analytics                              │
│  • Branch Performance & Regional Efficiency                            │
│  • Customer Support CSAT & SLA Resolution Metrics                      │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│  CONSUMPTION & SERVING                                                 │
│  • Automated 10-Point Data Quality Test Suite                          │
│  • Streamlit Financial Intelligence & KPI Dashboard                    │
│  • Exportable Gold CSV Business Reports                                │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 📊 Data Domains & Scale

The pipeline is benchmarked and verified over **5,868,950 total records**:

| Domain | Entity | Layer | Record Count | Description |
| :--- | :--- | :--- | :---: | :--- |
| **Branches** | `dim_branches` | Silver | 150 | Branch network with IFSC codes, cities, states |
| **Employees** | `dim_employees` | Silver | 1,800 | Branch officers, hierarchy, and payroll |
| **Customers** | `dim_customers` | Silver | 60,000 | Demographics, income, parsed names, credit scores & tiers |
| **Accounts** | `dim_accounts` | Silver | 95,000 | Savings, Current, and Salary accounts with balances |
| **Cards** | `dim_cards` | Silver | 65,000 | Debit and Credit cards with limits and lifecycle dates |
| **Loans** | `dim_loans` | Silver | 22,000 | Personal, Auto, and Home loans with rates and tenures |
| **Transactions** | `fact_transactions` | Silver | 2,000,000 | Multi-channel ledger entries (UPI, POS, ATM, Net Banking) |
| **Card Transactions** | `fact_card_transactions` | Silver | 3,000,000 | Merchant transactions with labeled fraud flag (`is_fraud`) |
| **Loan Payments** | `fact_loan_payments` | Silver | 600,000 | Loan EMIs tracking principal, interest, and late flags |
| **Support Tickets** | `fact_support_tickets` | Silver | 25,000 | Service requests, resolution turnaround, and CSAT scores |
| **Total** | | | **5,868,950** | **End-to-end execution benchmark in ~37 seconds** |

---

## 🏗️ Dimensional Modeling & Schema Design

The Silver layer follows Kimball dimensional modeling best practices:

- **Conformed Dimensions**:
  - `dim_customers`: Enriched with computed credit tiers (`EXCELLENT` $\ge$ 750, `GOOD` $\ge$ 700, `FAIR` $\ge$ 650, `POOR` < 650) and sanitized string fields.
  - `dim_accounts`: Mapped to customer and branch dimensions with foreign keys.
  - `dim_cards`, `dim_loans`, `dim_branches`, `dim_employees`.
- **Fact Tables**:
  - `fact_transactions`: Core banking financial movements linked to accounts and customer dimensions.
  - `fact_card_transactions`: High-velocity merchant charge records with binary fraud flags (`is_fraud`).
  - `fact_loan_payments`: Repayment history tracking interest/principal amortization split and delinquency indicators.
  - `fact_support_tickets`: Customer care logs with computed turnaround duration (`JULIANDAY` date delta).

---

## 📈 Gold Analytical Marts

Business logic is codified into curated SQL views in `sql/03_gold_queries.sql`:

1. **Customer 360 Mart (`view_gold_customer_360`)**:
   - Single customer view aggregating total deposits, active loans, card count, credit tier, and support inquiries.
   - Built with pre-aggregated CTEs to eliminate Cartesian join bloat.
2. **Fraud Intelligence Mart (`view_gold_fraud_intelligence`)**:
   - Aggregates fraud occurrence, fraud rate percentage, total fraud loss, and average fraudulent transaction size per merchant category.
3. **Loan Portfolio & Risk Mart (`view_gold_loan_risk_mart`)**:
   - Analyzes loan exposure by category, tracking disbursed capital, collected principal, earned interest, and late payment delinquency rates.
4. **Channel Liquidity Mart (`view_gold_channel_analytics`)**:
   - Breakdown of cash inflow/outflow across UPI, Net Banking, Mobile App, ATM, and Branch counter transactions.
5. **Branch Performance Mart (`view_gold_branch_performance`)**:
   - Evaluates branch deposit capitalization, loan origination volume, and staffing ratios across states and cities.
6. **Support Operations & CSAT Mart (`view_gold_support_operations`)**:
   - Tracks resolution SLAs (average turnaround days), backlog status, and customer satisfaction (CSAT) across issue categories.

---

## 🧪 Data Quality & Integrity Framework

Before publishing data to downstream consumption layers, the automated test harness (`src/quality/data_quality_tests.py`) runs 10 production-style verification gates:

- **Completeness & Volume Verification**: Ensures all target tables are populated.
- **Primary Key Uniqueness**: Zero duplicate keys in `dim_customers` and `dim_accounts`.
- **Referential Integrity**: 100% of accounts map to valid customers; 100% of transactions map to existing accounts (orphan check).
- **Domain Constraints**: Validates `is_fraud` flags are strictly binary (`0` or `1`) and CSAT scores fall within valid bounds (`1` to `5`).
- **Financial Logic Assertions**: Asserts zero negative transaction values.
- **Gold Mart Freshness**: Confirms analytical marts compile and yield active results.

---

## 🚀 Quickstart & Setup

### 1. Environment Setup

Clone the repository and install requirements:

```bash
git clone https://github.com/Spidey173/BankForge.git
cd BankForge

# Create and activate virtual environment
python3 -m venv .venv
source .venv/bin/activate

# Install dependencies
pip install -r requirements.txt
```

### 2. Run the Full Pipeline

Run the orchestrator to execute DDL setup, Bronze ingestion, Silver conforming, Gold marts generation, CSV report exports, and data quality assertions:

```bash
python3 main.py
```

*Expected output: Processes ~5.86 million records and completes all steps in ~37 seconds.*

### 3. Launch the Streamlit Dashboard

Run the interactive banking intelligence UI:

```bash
streamlit run app.py
```

Open [http://localhost:8501](http://localhost:8501) to explore:
- **Executive Overview**: High-level KPIs, total deposits, active loans, and fraud rates.
- **Customer 360**: Searchable customer profile and relationship drilldown.
- **Fraud Intelligence**: Vulnerability charts and high-risk merchant categories.
- **Credit Risk & Loans**: Delinquency monitoring and loan recovery stats.
- **Operations & Channels**: Channel volumes and branch distribution.

---

## 📁 Repository Structure

```
├── app.py                          # Streamlit Financial Intelligence & KPI Dashboard
├── main.py                         # Master Pipeline Orchestrator (Bronze -> Silver -> Gold)
├── requirements.txt                # Python dependencies
├── sql/
│   ├── 01_ddl_schema.sql           # Silver warehouse relational & dimensional DDL
│   ├── 02_silver_transforms.sql    # Conforming, type casting & cleansing SQL
│   └── 03_gold_queries.sql         # Gold analytical views & business marts
├── src/
│   ├── analytics/
│   │   └── generate_gold_reports.py # Gold marts CSV exporter
│   ├── ingestion/
│   │   └── ingest_bronze.py        # Chunked Bronze batch ingestion engine
│   ├── quality/
│   │   └── data_quality_tests.py   # Automated 10-point Data Quality test suite
│   └── transforms/
│       └── transform_silver.py     # Silver transformation and conforming runner
└── data/
    ├── bronze/                     # Landing layer for source CSV files
    ├── gold/                       # Pre-aggregated analytical CSV exports
    └── silver/
        └── banking_warehouse.db    # Conformed SQLite Data Warehouse (generated)
```

---

## 💡 Key Engineering Takeaways for Discussion

When discussing this project in technical interviews, focus on:
- **Medallion Architecture & ELT Design**: Why raw landing data is preserved immutably with metadata lineage (`_source_file`, `_ingested_at`) before applying business logic.
- **Dimensional Modeling**: How Kimball star schema principles were applied to model entities and facts for fast aggregations.
- **Query Optimization**: Using CTEs with pre-aggregations in the Gold layer to avoid Cartesian explosive joins across multi-million row tables.
- **Automated Data Quality Gates**: How automated unit/integration checks guard against schema drift, duplicate keys, and invalid financial entries prior to reporting.
- **Local Warehouse Performance**: How batched operations, PRAGMA optimizations (`synchronous=OFF`, in-memory cache tuning), and targeted B-tree indexes enable processing 5.86 million rows in under 40 seconds on standard consumer hardware.

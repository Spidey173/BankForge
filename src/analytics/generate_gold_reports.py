"""
BankForge - Gold Layer Analytical Reports Exporter
Exports high-value business intelligence marts from Gold views into data/gold/*.csv.
"""

import os
import sqlite3
import pandas as pd

BASE_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DB_PATH = os.path.join(BASE_DIR, "data", "silver", "banking_warehouse.db")
GOLD_DIR = os.path.join(BASE_DIR, "data", "gold")

REPORTS = [
    ("view_gold_fraud_intelligence", "fraud_intelligence_report.csv"),
    ("view_gold_loan_risk_mart", "loan_portfolio_risk_report.csv"),
    ("view_gold_channel_analytics", "channel_liquidity_report.csv"),
    ("view_gold_branch_performance", "branch_performance_report.csv"),
    ("view_gold_support_operations", "customer_support_csat_report.csv"),
]

def run_gold_exports():
    print("=" * 70)
    print("  STEP 4: EXPORTING GOLD BUSINESS MARTS & AUDIT REPORTS")
    print("=" * 70)

    if not os.path.exists(DB_PATH):
        print("  [!] Warehouse DB not found.")
        return

    os.makedirs(GOLD_DIR, exist_ok=True)
    conn = sqlite3.connect(DB_PATH)

    for view_name, csv_filename in REPORTS:
        out_path = os.path.join(GOLD_DIR, csv_filename)
        query = f"SELECT * FROM {view_name};"
        df = pd.read_sql_query(query, conn)
        df.to_csv(out_path, index=False)
        print(f"  [+] Exported {view_name:<32} -> {csv_filename} ({len(df):,} rows)")

    # Also export top 1000 Customer 360 summary
    cust_out = os.path.join(GOLD_DIR, "customer_360_sample_report.csv")
    df_cust = pd.read_sql_query("SELECT * FROM view_gold_customer_360 LIMIT 1000;", conn)
    df_cust.to_csv(cust_out, index=False)
    print(f"  [+] Exported view_gold_customer_360 (Top 1k)       -> customer_360_sample_report.csv")

    conn.close()
    print("  [+] Gold analytical marts exported successfully.")

if __name__ == "__main__":
    run_gold_exports()

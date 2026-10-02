"""
BankForge - Silver Transformation Engine
Loads and executes sql/02_silver_transforms.sql to conform raw Bronze staging
data into cleaned Silver dimensional and fact tables.
"""

import os
import time
import sqlite3

BASE_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DB_PATH = os.path.join(BASE_DIR, "data", "silver", "banking_warehouse.db")
SQL_TRANSFORMS_PATH = os.path.join(BASE_DIR, "sql", "02_silver_transforms.sql")

TABLES_TO_AUDIT = [
    "dim_branches",
    "dim_employees",
    "dim_customers",
    "dim_accounts",
    "dim_cards",
    "dim_loans",
    "fact_transactions",
    "fact_card_transactions",
    "fact_loan_payments",
    "fact_support_tickets",
]

def get_db_connection():
    conn = sqlite3.connect(DB_PATH)
    conn.execute("PRAGMA synchronous = OFF;")
    conn.execute("PRAGMA journal_mode = MEMORY;")
    conn.execute("PRAGMA cache_size = 100000;")
    return conn

def run_silver_transformations():
    print("=" * 70)
    print("  STEP 2: EXECUTING SILVER TRANSFORMATION & CONFORMING (02_silver_transforms.sql)")
    print("=" * 70)

    start_time = time.time()
    with open(SQL_TRANSFORMS_PATH, "r", encoding="utf-8") as f:
        sql_script = f.read()

    conn = get_db_connection()
    cursor = conn.cursor()

    # Split and execute individual statements to log per-table progress
    statements = [stmt.strip() for stmt in sql_script.split(";") if stmt.strip()]

    for stmt in statements:
        # Check exact target table name from statement
        target_table = "table"
        for tbl in sorted(TABLES_TO_AUDIT, key=len, reverse=True):
            if f"INTO {tbl}".upper() in stmt.upper():
                target_table = tbl
                break

        t0 = time.time()
        print(f"  --> Conforming Silver table {target_table:<24}...", end="", flush=True)
        cursor.execute(stmt)
        conn.commit()

        cursor.execute(f"SELECT COUNT(*) FROM {target_table};")
        count = cursor.fetchone()[0]
        elapsed = time.time() - t0
        print(f" Populated {count:>9,d} rows ({elapsed:.2f}s)")

    conn.close()
    total_elapsed = time.time() - start_time
    print(f"\n  [+] Silver Transformations Complete in {total_elapsed:.2f}s")

if __name__ == "__main__":
    run_silver_transformations()

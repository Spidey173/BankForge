"""
BankForge - Bronze Ingestion Engine
Loads raw source extracts from records/ into Bronze staging tables with audit lineage.

Key Principles:
1. Append-only, zero business transformation (preserves raw truth).
2. Attaches ELT audit metadata (_source_file, _ingested_at) for lineage and observability.
3. High-throughput chunked batching for rapid ingestion of millions of records.
"""

import os
import csv
import time
import sqlite3
from datetime import datetime

BASE_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
BRONZE_DIR = os.path.join(BASE_DIR, "data", "bronze")
DB_PATH = os.path.join(BASE_DIR, "data", "silver", "banking_warehouse.db")

MAPPING = [
    ("branches.csv", "stg_branches"),
    ("employees.csv", "stg_employees"),
    ("customers.csv", "stg_customers"),
    ("accounts.csv", "stg_accounts"),
    ("cards.csv", "stg_cards"),
    ("loans.csv", "stg_loans"),
    ("support_tickets.csv", "stg_support_tickets"),
    ("loan_payments.csv", "stg_loan_payments"),
    ("transactions.csv", "stg_transactions"),
    ("card_transactions.csv", "stg_card_transactions"),
]

def get_db_connection():
    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    conn.execute("PRAGMA synchronous = OFF;")
    conn.execute("PRAGMA journal_mode = MEMORY;")
    conn.execute("PRAGMA cache_size = 100000;")
    return conn

FALLBACK_SCHEMAS = {
    "stg_transactions": ["transaction_id", "account_id", "txn_date", "txn_type", "amount", "channel", "merchant_category"],
    "stg_card_transactions": ["card_txn_id", "card_id", "txn_date", "merchant_category", "amount", "is_fraud"],
}

def ingest_csv_file(conn, csv_filename, table_name, batch_size=100000):
    filepath = os.path.join(BRONZE_DIR, csv_filename)
    if not os.path.exists(filepath):
        # Check for sample file fallback (e.g., in CI environments where >100MB files are gitignored)
        sample_filename = csv_filename.replace(".csv", "_sample.csv")
        sample_path = os.path.join(BRONZE_DIR, sample_filename)
        if os.path.exists(sample_path):
            print(f" (using sample: {sample_filename})", end="")
            filepath = sample_path
        else:
            print(f"  [!] File not found: {filepath} (creating empty staging table)")
            cursor = conn.cursor()
            cursor.execute(f"DROP TABLE IF EXISTS {table_name}")
            cols = FALLBACK_SCHEMAS.get(table_name, ["id"])
            col_defs = [f'"{c}" TEXT' for c in cols] + ['"_source_file" TEXT', '"_ingested_at" TEXT']
            cursor.execute(f"CREATE TABLE {table_name} ({', '.join(col_defs)});")
            conn.commit()
            return 0

    cursor = conn.cursor()
    ingested_at = datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S")

    with open(filepath, mode="r", encoding="utf-8") as f:
        reader = csv.reader(f)
        header = next(reader, None)
        if not header:
            return 0

        # Drop old staging table to ensure fresh clean landing
        cursor.execute(f"DROP TABLE IF EXISTS {table_name}")

        # Build column DDL
        col_defs = [f'"{col}" TEXT' for col in header]
        col_defs.append('"_source_file" TEXT')
        col_defs.append('"_ingested_at" TEXT')
        create_sql = f"CREATE TABLE {table_name} ({', '.join(col_defs)});"
        cursor.execute(create_sql)

        # Prepared insert statement
        placeholders = ", ".join(["?"] * (len(header) + 2))
        insert_sql = f"INSERT INTO {table_name} VALUES ({placeholders})"

        batch = []
        total_rows = 0
        for row in reader:
            # Append audit lineage
            row.append(csv_filename)
            row.append(ingested_at)
            batch.append(row)

            if len(batch) >= batch_size:
                cursor.executemany(insert_sql, batch)
                total_rows += len(batch)
                batch = []

        if batch:
            cursor.executemany(insert_sql, batch)
            total_rows += len(batch)

    conn.commit()
    return total_rows

def run_bronze_ingestion():
    print("=" * 70)
    print("  STEP 1: INGESTING RAW FILES INTO BRONZE STAGING")
    print("=" * 70)

    start_time = time.time()
    conn = get_db_connection()
    total_ingested = 0

    for csv_file, table_name in MAPPING:
        t0 = time.time()
        print(f"  --> Ingesting {csv_file:<25} -> {table_name:<22}...", end="", flush=True)
        count = ingest_csv_file(conn, csv_file, table_name)
        total_ingested += count
        elapsed = time.time() - t0
        print(f" Loaded {count:>9,d} rows ({elapsed:.2f}s)")

    conn.close()
    total_elapsed = time.time() - start_time
    print(f"\n  [+] Bronze Ingestion Complete: {total_ingested:,d} total records in {total_elapsed:.2f}s")
    return total_ingested

if __name__ == "__main__":
    run_bronze_ingestion()

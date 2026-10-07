"""
BankForge - Enterprise Banking Data Engineering Master Orchestrator
Executes the full Medallion data lifecycle from raw records ingestion to Gold analytical marts.

Usage:
    python3 main.py
"""

import os
import sys
import time
import sqlite3

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DB_PATH = os.path.join(BASE_DIR, "data", "silver", "banking_warehouse.db")

def print_header(title):
    print("\n" + "=" * 70)
    print(f"  {title.upper()}")
    print("=" * 70)

def step_0_init_database(clean_start=True):
    print_header("Step 0: Initializing Silver Warehouse DDL")
    if clean_start and os.path.exists(DB_PATH):
        os.remove(DB_PATH)
        print(f"  [+] Reset existing database: {DB_PATH}")

    ddl_path = os.path.join(BASE_DIR, "sql", "01_ddl_schema.sql")
    with open(ddl_path, "r", encoding="utf-8") as f:
        ddl_sql = f.read()

    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    conn.executescript(ddl_sql)
    conn.commit()
    conn.close()
    print("  [+] Clean Silver schema and performance indexes initialized.")

def step_1_ingest_bronze():
    from src.ingestion.ingest_bronze import run_bronze_ingestion
    return run_bronze_ingestion()

def step_2_transform_silver():
    from src.transforms.transform_silver import run_silver_transformations
    run_silver_transformations()

def step_3_apply_gold_views():
    print_header("Step 3: Creating Gold Layer Analytical Views")
    gold_sql_path = os.path.join(BASE_DIR, "sql", "03_gold_queries.sql")
    with open(gold_sql_path, "r", encoding="utf-8") as f:
        gold_sql = f.read()

    conn = sqlite3.connect(DB_PATH)
    conn.executescript(gold_sql)
    conn.commit()
    conn.close()
    print("  [+] Gold analytical marts and reporting views registered successfully.")

def step_4_export_gold_reports():
    from src.analytics.generate_gold_reports import run_gold_exports
    run_gold_exports()

def step_5_run_quality_checks():
    from src.quality.data_quality_tests import run_all_tests
    return run_all_tests()

def main():
    total_start = time.time()
    print("\n" + "#" * 70)
    print("   BANKFORGE - ENTERPRISE BANKING DATA ENGINEERING PIPELINE")
    print("#" * 70)

    # 1. Reset / Initialize DDL
    step_0_init_database()

    # 2. Ingest raw records into Bronze staging
    step_1_ingest_bronze()

    # 3. Transform & conform Bronze data into Silver relational & dimensional tables
    step_2_transform_silver()

    # 4. Build Gold Layer Analytical Views
    step_3_apply_gold_views()

    # 5. Export Reports to data/gold/
    step_4_export_gold_reports()

    # 6. Execute automated Data Quality Assertions
    passed = step_5_run_quality_checks()

    total_time = time.time() - total_start
    print("\n" + "#" * 70)
    if passed:
        print(f"   PIPELINE SUCCEEDED: ALL STEPS EXECUTED IN {total_time:.2f}s")
    else:
        print(f"   PIPELINE COMPLETED WITH WARNINGS IN {total_time:.2f}s")
    print("#" * 70)

if __name__ == "__main__":
    main()

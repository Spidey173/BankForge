"""
BankForge - Automated Data Quality Framework
Runs automated validation assertions against the Silver and Gold data warehouse layers.
"""

import os
import sqlite3

BASE_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DB_PATH = os.path.join(BASE_DIR, "data", "silver", "banking_warehouse.db")

def run_all_tests():
    print("=" * 70)
    print("  STEP 5: EXECUTING AUTOMATED DATA QUALITY TESTS")
    print("=" * 70)

    if not os.path.exists(DB_PATH):
        print("  [X] FAILED: Data warehouse file does not exist.")
        return False

    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()

    tests = [
        ("Volume: Silver tables populated (> 0 rows)", """
            SELECT 
                (SELECT COUNT(*) FROM dim_customers) AS customers_cnt,
                (SELECT COUNT(*) FROM dim_accounts) AS accounts_cnt,
                (SELECT COUNT(*) FROM fact_transactions) AS txns_cnt,
                (SELECT COUNT(*) FROM fact_card_transactions) AS card_txns_cnt
        """, lambda res: res[0][0] > 0 and res[0][1] > 0 and res[0][2] > 0 and res[0][3] > 0),

        ("Uniqueness: Primary Key uniqueness on dim_customers", """
            SELECT customer_id, COUNT(*) 
            FROM dim_customers 
            GROUP BY customer_id 
            HAVING COUNT(*) > 1;
        """, lambda res: len(res) == 0),

        ("Uniqueness: Primary Key uniqueness on dim_accounts", """
            SELECT account_id, COUNT(*) 
            FROM dim_accounts 
            GROUP BY account_id 
            HAVING COUNT(*) > 1;
        """, lambda res: len(res) == 0),

        ("Referential Integrity: All accounts belong to valid customers", """
            SELECT COUNT(*) 
            FROM dim_accounts a
            LEFT JOIN dim_customers c ON a.customer_id = c.customer_id
            WHERE c.customer_id IS NULL;
        """, lambda res: res[0][0] == 0),

        ("Referential Integrity: All transactions belong to valid accounts", """
            SELECT COUNT(*) 
            FROM fact_transactions t
            LEFT JOIN dim_accounts a ON t.account_id = a.account_id
            WHERE a.account_id IS NULL;
        """, lambda res: res[0][0] == 0),

        ("Domain Integrity: Card fraud flags must be strictly binary (0 or 1)", """
            SELECT COUNT(*) 
            FROM fact_card_transactions 
            WHERE is_fraud NOT IN (0, 1);
        """, lambda res: res[0][0] == 0),

        ("Domain Integrity: Customer support satisfaction score must be 1 to 5", """
            SELECT COUNT(*) 
            FROM fact_support_tickets 
            WHERE satisfaction_score IS NOT NULL AND (satisfaction_score < 1 OR satisfaction_score > 5);
        """, lambda res: res[0][0] == 0),

        ("Financial Sanity: Non-negative transaction amounts", """
            SELECT COUNT(*) 
            FROM fact_transactions 
            WHERE amount < 0;
        """, lambda res: res[0][0] == 0),

        ("Gold Layer: view_gold_customer_360 returns active records", """
            SELECT COUNT(*) FROM view_gold_customer_360;
        """, lambda res: res[0][0] > 0),

        ("Gold Layer: view_gold_fraud_intelligence computes category risk", """
            SELECT COUNT(*) FROM view_gold_fraud_intelligence;
        """, lambda res: res[0][0] > 0),
    ]

    all_passed = True
    passed_count = 0

    for test_name, query, validator in tests:
        try:
            cursor.execute(query)
            result = cursor.fetchall()
            passed = validator(result)
            if passed:
                print(f"  [PASS] {test_name}")
                passed_count += 1
            else:
                print(f"  [FAIL] {test_name} - Assertion condition failed.")
                all_passed = False
        except Exception as e:
            print(f"  [ERROR] {test_name} - Exception: {e}")
            all_passed = False

    conn.close()
    print("-" * 70)
    print(f"  Quality Results: {passed_count}/{len(tests)} assertions passed.")
    if all_passed:
        print("  [SUCCESS] All production data quality assertions PASSED.")
    else:
        print("  [WARNING] Some data quality assertions failed.")
    return all_passed

if __name__ == "__main__":
    run_all_tests()

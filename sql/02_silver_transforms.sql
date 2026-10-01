-- ==============================================================================
-- BANKFORGE: SILVER TRANSFORMATION & CONFORMING QUERIES (SILVER LAYER)
-- Transforms raw Bronze staging tables into cleaned dimensional and fact tables.
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. CONFORM DIM_BRANCHES
-- ------------------------------------------------------------------------------
INSERT OR REPLACE INTO dim_branches (
    branch_id, branch_name, city, state, opened_date, ifsc_code
)
SELECT 
    CAST(branch_id AS INTEGER),
    TRIM(branch_name),
    TRIM(city),
    TRIM(state),
    opened_date,
    UPPER(TRIM(ifsc_code))
FROM stg_branches
WHERE branch_id IS NOT NULL;

-- ------------------------------------------------------------------------------
-- 2. CONFORM DIM_EMPLOYEES
-- ------------------------------------------------------------------------------
INSERT OR REPLACE INTO dim_employees (
    employee_id, name, branch_id, role, hire_date, salary
)
SELECT 
    CAST(employee_id AS INTEGER),
    TRIM(name),
    CAST(branch_id AS INTEGER),
    TRIM(role),
    hire_date,
    CAST(salary AS REAL)
FROM stg_employees
WHERE employee_id IS NOT NULL;

-- ------------------------------------------------------------------------------
-- 3. CONFORM DIM_CUSTOMERS (With Name Parsing & Credit Tiering)
-- ------------------------------------------------------------------------------
INSERT OR REPLACE INTO dim_customers (
    customer_id, full_name, first_name, last_name, gender,
    date_of_birth, city, state, phone, email, occupation,
    annual_income, join_date, credit_score, credit_tier
)
SELECT 
    CAST(customer_id AS INTEGER),
    TRIM(name),
    CASE 
        WHEN INSTR(TRIM(name), ' ') > 0 THEN SUBSTR(TRIM(name), 1, INSTR(TRIM(name), ' ') - 1)
        ELSE TRIM(name)
    END AS first_name,
    CASE 
        WHEN INSTR(TRIM(name), ' ') > 0 THEN SUBSTR(TRIM(name), INSTR(TRIM(name), ' ') + 1)
        ELSE ''
    END AS last_name,
    TRIM(gender),
    date_of_birth,
    TRIM(city),
    TRIM(state),
    CAST(phone AS TEXT),
    LOWER(TRIM(email)),
    TRIM(occupation),
    CAST(annual_income AS REAL),
    join_date,
    CAST(credit_score AS INTEGER),
    CASE 
        WHEN CAST(credit_score AS INTEGER) >= 750 THEN 'EXCELLENT'
        WHEN CAST(credit_score AS INTEGER) >= 700 THEN 'GOOD'
        WHEN CAST(credit_score AS INTEGER) >= 650 THEN 'FAIR'
        ELSE 'POOR'
    END AS credit_tier
FROM stg_customers
WHERE customer_id IS NOT NULL;

-- ------------------------------------------------------------------------------
-- 4. CONFORM DIM_ACCOUNTS
-- ------------------------------------------------------------------------------
INSERT OR REPLACE INTO dim_accounts (
    account_id, customer_id, branch_id, account_type, balance, open_date, status
)
SELECT 
    CAST(account_id AS INTEGER),
    CAST(customer_id AS INTEGER),
    CAST(branch_id AS INTEGER),
    TRIM(account_type),
    CAST(balance AS REAL),
    open_date,
    TRIM(status)
FROM stg_accounts
WHERE account_id IS NOT NULL;

-- ------------------------------------------------------------------------------
-- 5. CONFORM DIM_CARDS
-- ------------------------------------------------------------------------------
INSERT OR REPLACE INTO dim_cards (
    card_id, customer_id, account_id, card_type, issue_date, expiry_date, credit_limit, status
)
SELECT 
    CAST(card_id AS INTEGER),
    CAST(customer_id AS INTEGER),
    CAST(account_id AS INTEGER),
    TRIM(card_type),
    issue_date,
    expiry_date,
    CAST(credit_limit AS REAL),
    TRIM(status)
FROM stg_cards
WHERE card_id IS NOT NULL;

-- ------------------------------------------------------------------------------
-- 6. CONFORM DIM_LOANS
-- ------------------------------------------------------------------------------
INSERT OR REPLACE INTO dim_loans (
    loan_id, customer_id, branch_id, loan_type, loan_amount, interest_rate, term_months, start_date, status
)
SELECT 
    CAST(loan_id AS INTEGER),
    CAST(customer_id AS INTEGER),
    CAST(branch_id AS INTEGER),
    TRIM(loan_type),
    CAST(loan_amount AS REAL),
    CAST(interest_rate AS REAL),
    CAST(term_months AS INTEGER),
    start_date,
    TRIM(status)
FROM stg_loans
WHERE loan_id IS NOT NULL;

-- ------------------------------------------------------------------------------
-- 7. CONFORM FACT_TRANSACTIONS (Enriched with customer_id from dim_accounts)
-- ------------------------------------------------------------------------------
INSERT OR REPLACE INTO fact_transactions (
    transaction_id, account_id, customer_id, txn_date, txn_type, amount, channel, merchant_category
)
SELECT 
    CAST(t.transaction_id AS INTEGER),
    CAST(t.account_id AS INTEGER),
    a.customer_id,
    t.txn_date,
    TRIM(t.txn_type),
    CAST(t.amount AS REAL),
    TRIM(t.channel),
    TRIM(t.merchant_category)
FROM stg_transactions t
LEFT JOIN dim_accounts a ON CAST(t.account_id AS INTEGER) = a.account_id
WHERE t.transaction_id IS NOT NULL;

-- ------------------------------------------------------------------------------
-- 8. CONFORM FACT_CARD_TRANSACTIONS (Fraud Classification)
-- ------------------------------------------------------------------------------
INSERT OR REPLACE INTO fact_card_transactions (
    card_txn_id, card_id, txn_date, merchant_category, amount, is_fraud
)
SELECT 
    CAST(card_txn_id AS INTEGER),
    CAST(card_id AS INTEGER),
    txn_date,
    TRIM(merchant_category),
    CAST(amount AS REAL),
    CAST(is_fraud AS INTEGER)
FROM stg_card_transactions
WHERE card_txn_id IS NOT NULL;

-- ------------------------------------------------------------------------------
-- 9. CONFORM FACT_LOAN_PAYMENTS (Principal / Interest / Delinquency)
-- ------------------------------------------------------------------------------
INSERT OR REPLACE INTO fact_loan_payments (
    payment_id, loan_id, payment_date, amount_paid, principal_component, interest_component, late_payment_flag
)
SELECT 
    CAST(payment_id AS INTEGER),
    CAST(loan_id AS INTEGER),
    payment_date,
    CAST(amount_paid AS REAL),
    CAST(principal_component AS REAL),
    CAST(interest_component AS REAL),
    CAST(late_payment_flag AS INTEGER)
FROM stg_loan_payments
WHERE payment_id IS NOT NULL;

-- ------------------------------------------------------------------------------
-- 10. CONFORM FACT_SUPPORT_TICKETS (Turnaround Calculation & CSAT)
-- ------------------------------------------------------------------------------
INSERT OR REPLACE INTO fact_support_tickets (
    ticket_id, customer_id, issue_type, date_opened, date_resolved, resolution_days, status, satisfaction_score
)
SELECT 
    CAST(ticket_id AS INTEGER),
    CAST(customer_id AS INTEGER),
    TRIM(issue_type),
    date_opened,
    date_resolved,
    ROUND(MAX(0.0, JULIANDAY(date_resolved) - JULIANDAY(date_opened)), 1),
    TRIM(status),
    CAST(satisfaction_score AS INTEGER)
FROM stg_support_tickets
WHERE ticket_id IS NOT NULL;

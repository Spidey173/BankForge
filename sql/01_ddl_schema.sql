-- ==============================================================================
-- BANKFORGE: DATA WAREHOUSE DDL (SILVER LAYER)
-- Architecture: Medallion Silver Layer (Cleaned Relational & Dimensional Model)
-- Data Domain: Core Banking, Cards, Loans, Support, and Financial Transactions
-- ==============================================================================

-- 1. BRANCH DIMENSION
CREATE TABLE IF NOT EXISTS dim_branches (
    branch_id           INTEGER PRIMARY KEY,
    branch_name         VARCHAR(100) NOT NULL,
    city                VARCHAR(64) NOT NULL,
    state               VARCHAR(64) NOT NULL,
    opened_date         DATE,
    ifsc_code           VARCHAR(16) NOT NULL,
    created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. EMPLOYEE DIMENSION
CREATE TABLE IF NOT EXISTS dim_employees (
    employee_id         INTEGER PRIMARY KEY,
    name                VARCHAR(100) NOT NULL,
    branch_id           INTEGER,
    role                VARCHAR(64) NOT NULL,
    hire_date           DATE,
    salary              DECIMAL(12, 2) NOT NULL,
    created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (branch_id) REFERENCES dim_branches(branch_id)
);

-- 3. CUSTOMER DIMENSION
CREATE TABLE IF NOT EXISTS dim_customers (
    customer_id         INTEGER PRIMARY KEY,
    full_name           VARCHAR(100) NOT NULL,
    first_name          VARCHAR(50),
    last_name           VARCHAR(50),
    gender              VARCHAR(10),
    date_of_birth       DATE,
    city                VARCHAR(64) NOT NULL,
    state               VARCHAR(64) NOT NULL,
    phone               VARCHAR(20),
    email               VARCHAR(128),
    occupation          VARCHAR(64),
    annual_income       DECIMAL(14, 2),
    join_date           DATE,
    credit_score        INTEGER,
    credit_tier         VARCHAR(20),       -- 'EXCELLENT', 'GOOD', 'FAIR', 'POOR'
    created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 4. ACCOUNT DIMENSION
CREATE TABLE IF NOT EXISTS dim_accounts (
    account_id          INTEGER PRIMARY KEY,
    customer_id         INTEGER NOT NULL,
    branch_id           INTEGER,
    account_type        VARCHAR(32) NOT NULL, -- 'Savings', 'Current', 'Salary', etc.
    balance             DECIMAL(14, 2) NOT NULL DEFAULT 0.0,
    open_date           DATE NOT NULL,
    status              VARCHAR(20) DEFAULT 'Active',
    created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (customer_id) REFERENCES dim_customers(customer_id),
    FOREIGN KEY (branch_id) REFERENCES dim_branches(branch_id)
);

-- 5. CARD DIMENSION
CREATE TABLE IF NOT EXISTS dim_cards (
    card_id             INTEGER PRIMARY KEY,
    customer_id         INTEGER NOT NULL,
    account_id          INTEGER NOT NULL,
    card_type           VARCHAR(32) NOT NULL, -- 'Debit', 'Credit - Gold', etc.
    issue_date          DATE,
    expiry_date         DATE,
    credit_limit        DECIMAL(12, 2) DEFAULT 0.0,
    status              VARCHAR(20) DEFAULT 'Active',
    created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (customer_id) REFERENCES dim_customers(customer_id),
    FOREIGN KEY (account_id) REFERENCES dim_accounts(account_id)
);

-- 6. LOAN DIMENSION
CREATE TABLE IF NOT EXISTS dim_loans (
    loan_id             INTEGER PRIMARY KEY,
    customer_id         INTEGER NOT NULL,
    branch_id           INTEGER,
    loan_type           VARCHAR(32) NOT NULL, -- 'Personal Loan', 'Auto Loan', 'Home Loan', etc.
    loan_amount         DECIMAL(14, 2) NOT NULL,
    interest_rate       DECIMAL(5, 2) NOT NULL,
    term_months         INTEGER NOT NULL,
    start_date          DATE NOT NULL,
    status              VARCHAR(20) DEFAULT 'Active',
    created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (customer_id) REFERENCES dim_customers(customer_id),
    FOREIGN KEY (branch_id) REFERENCES dim_branches(branch_id)
);

-- 7. CORE TRANSACTION FACT TABLE
CREATE TABLE IF NOT EXISTS fact_transactions (
    transaction_id      INTEGER PRIMARY KEY,
    account_id          INTEGER NOT NULL,
    customer_id         INTEGER,
    txn_date            DATE NOT NULL,
    txn_type            VARCHAR(32) NOT NULL, -- 'Deposit', 'Withdrawal', 'Transfer Out', etc.
    amount              DECIMAL(14, 2) NOT NULL,
    channel             VARCHAR(32) NOT NULL, -- 'UPI', 'Online Banking', 'POS', 'Mobile App'
    merchant_category   VARCHAR(64),
    created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (account_id) REFERENCES dim_accounts(account_id)
);

-- 8. CARD TRANSACTION FACT TABLE (Fraud Intelligence)
CREATE TABLE IF NOT EXISTS fact_card_transactions (
    card_txn_id         INTEGER PRIMARY KEY,
    card_id             INTEGER NOT NULL,
    txn_date            DATE NOT NULL,
    merchant_category   VARCHAR(64),
    amount              DECIMAL(14, 2) NOT NULL,
    is_fraud            INTEGER DEFAULT 0,    -- 0 = Normal, 1 = Fraud
    created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (card_id) REFERENCES dim_cards(card_id)
);

-- 9. LOAN PAYMENTS FACT TABLE
CREATE TABLE IF NOT EXISTS fact_loan_payments (
    payment_id          INTEGER PRIMARY KEY,
    loan_id             INTEGER NOT NULL,
    payment_date        DATE NOT NULL,
    amount_paid         DECIMAL(14, 2) NOT NULL,
    principal_component DECIMAL(14, 2) NOT NULL,
    interest_component  DECIMAL(14, 2) NOT NULL,
    late_payment_flag   INTEGER DEFAULT 0,    -- 0 = On Time, 1 = Late
    created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (loan_id) REFERENCES dim_loans(loan_id)
);

-- 10. SUPPORT TICKETS FACT TABLE
CREATE TABLE IF NOT EXISTS fact_support_tickets (
    ticket_id           INTEGER PRIMARY KEY,
    customer_id         INTEGER NOT NULL,
    issue_type          VARCHAR(64) NOT NULL,
    date_opened         DATE NOT NULL,
    date_resolved       DATE,
    resolution_days     REAL,
    status              VARCHAR(20) DEFAULT 'Resolved',
    satisfaction_score  INTEGER,              -- 1 to 5 scale
    created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (customer_id) REFERENCES dim_customers(customer_id)
);

-- Performance Indexes for Analytical Joins
CREATE INDEX IF NOT EXISTS idx_acc_cust ON dim_accounts(customer_id);
CREATE INDEX IF NOT EXISTS idx_txn_acc ON fact_transactions(account_id);
CREATE INDEX IF NOT EXISTS idx_txn_cust ON fact_transactions(customer_id);
CREATE INDEX IF NOT EXISTS idx_txn_dt ON fact_transactions(txn_date);
CREATE INDEX IF NOT EXISTS idx_card_cust ON dim_cards(customer_id);
CREATE INDEX IF NOT EXISTS idx_card_txn_card ON fact_card_transactions(card_id);
CREATE INDEX IF NOT EXISTS idx_card_txn_fraud ON fact_card_transactions(is_fraud);
CREATE INDEX IF NOT EXISTS idx_loans_cust ON dim_loans(customer_id);
CREATE INDEX IF NOT EXISTS idx_payments_loan ON fact_loan_payments(loan_id);
CREATE INDEX IF NOT EXISTS idx_tickets_cust ON fact_support_tickets(customer_id);

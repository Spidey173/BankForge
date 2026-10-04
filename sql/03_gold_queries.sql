-- ==============================================================================
-- BANKFORGE: GOLD LAYER ANALYTICS & BUSINESS MARTS
-- Analytical and Reporting Views for BI Dashboards and Executive Intelligence
-- Optimized with CTE pre-aggregation to eliminate Cartesian joins
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. CUSTOMER 360 & NET WORTH MART
-- Single comprehensive view of customer profile, balances, credit, and engagement
-- ------------------------------------------------------------------------------
CREATE VIEW IF NOT EXISTS view_gold_customer_360 AS
WITH cust_acc AS (
    SELECT customer_id, COUNT(*) AS total_accounts, SUM(balance) AS total_deposit_balance
    FROM dim_accounts
    WHERE status = 'Active'
    GROUP BY customer_id
),
cust_card AS (
    SELECT customer_id, COUNT(*) AS total_cards
    FROM dim_cards
    WHERE status = 'Active'
    GROUP BY customer_id
),
cust_loan AS (
    SELECT customer_id, COUNT(*) AS total_loans, SUM(loan_amount) AS total_borrowed_amount
    FROM dim_loans
    WHERE status = 'Active'
    GROUP BY customer_id
),
cust_ticket AS (
    SELECT customer_id, COUNT(*) AS total_support_tickets
    FROM fact_support_tickets
    GROUP BY customer_id
)
SELECT 
    c.customer_id,
    c.full_name,
    c.gender,
    c.city,
    c.state,
    c.occupation,
    c.annual_income,
    c.credit_score,
    c.credit_tier,
    COALESCE(a.total_accounts, 0) AS total_accounts,
    ROUND(COALESCE(a.total_deposit_balance, 0.0), 2) AS total_deposit_balance,
    COALESCE(crd.total_cards, 0) AS total_cards,
    COALESCE(l.total_loans, 0) AS total_loans,
    ROUND(COALESCE(l.total_borrowed_amount, 0.0), 2) AS total_borrowed_amount,
    COALESCE(t.total_support_tickets, 0) AS total_support_tickets
FROM dim_customers c
LEFT JOIN cust_acc a ON c.customer_id = a.customer_id
LEFT JOIN cust_card crd ON c.customer_id = crd.customer_id
LEFT JOIN cust_loan l ON c.customer_id = l.customer_id
LEFT JOIN cust_ticket t ON c.customer_id = t.customer_id;


-- ------------------------------------------------------------------------------
-- 2. FRAUD INTELLIGENCE & CARD RISK MART
-- Analysis of fraud vulnerability across merchant categories
-- ------------------------------------------------------------------------------
CREATE VIEW IF NOT EXISTS view_gold_fraud_intelligence AS
SELECT 
    merchant_category,
    COUNT(*) AS total_card_transactions,
    SUM(CASE WHEN is_fraud = 1 THEN 1 ELSE 0 END) AS fraud_transactions,
    ROUND(100.0 * SUM(CASE WHEN is_fraud = 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS fraud_rate_pct,
    ROUND(SUM(amount), 2) AS total_volume_amount,
    ROUND(COALESCE(SUM(CASE WHEN is_fraud = 1 THEN amount ELSE 0 END), 0.0), 2) AS total_fraud_amount,
    ROUND(COALESCE(AVG(CASE WHEN is_fraud = 1 THEN amount ELSE NULL END), 0.0), 2) AS avg_fraud_amount
FROM fact_card_transactions
GROUP BY merchant_category
ORDER BY fraud_transactions DESC;


-- ------------------------------------------------------------------------------
-- 3. LOAN PORTFOLIO & CREDIT RISK MART
-- Loan performance, interest revenue, and delinquency monitoring
-- ------------------------------------------------------------------------------
CREATE VIEW IF NOT EXISTS view_gold_loan_risk_mart AS
WITH loan_payments_summary AS (
    SELECT 
        loan_id,
        COUNT(*) AS payments_count,
        SUM(amount_paid) AS total_collected,
        SUM(principal_component) AS total_principal_recovered,
        SUM(interest_component) AS total_interest_earned,
        SUM(CASE WHEN late_payment_flag = 1 THEN 1 ELSE 0 END) AS late_payments_count
    FROM fact_loan_payments
    GROUP BY loan_id
)
SELECT 
    l.loan_type,
    COUNT(DISTINCT l.loan_id) AS total_loans_issued,
    ROUND(SUM(l.loan_amount), 2) AS total_disbursed_amount,
    ROUND(AVG(l.interest_rate), 2) AS avg_interest_rate_pct,
    COALESCE(SUM(p.payments_count), 0) AS total_payments_recorded,
    ROUND(COALESCE(SUM(p.total_collected), 0.0), 2) AS total_collected_amount,
    ROUND(COALESCE(SUM(p.total_principal_recovered), 0.0), 2) AS principal_recovered,
    ROUND(COALESCE(SUM(p.total_interest_earned), 0.0), 2) AS interest_earned,
    COALESCE(SUM(p.late_payments_count), 0) AS total_late_payments,
    ROUND(100.0 * COALESCE(SUM(p.late_payments_count), 0) / NULLIF(COALESCE(SUM(p.payments_count), 0), 0), 2) AS late_payment_rate_pct
FROM dim_loans l
LEFT JOIN loan_payments_summary p 
    ON l.loan_id = p.loan_id
GROUP BY l.loan_type
ORDER BY total_disbursed_amount DESC;


-- ------------------------------------------------------------------------------
-- 4. CHANNEL & TRANSACTION VOLUME ANALYTICS
-- Transaction volume and liquidity flow across channels
-- ------------------------------------------------------------------------------
CREATE VIEW IF NOT EXISTS view_gold_channel_analytics AS
SELECT 
    channel,
    COUNT(*) AS total_transactions,
    ROUND(SUM(amount), 2) AS total_flow_amount,
    ROUND(AVG(amount), 2) AS avg_transaction_amount,
    SUM(CASE WHEN txn_type = 'Deposit' THEN 1 ELSE 0 END) AS deposit_count,
    SUM(CASE WHEN txn_type = 'Withdrawal' THEN 1 ELSE 0 END) AS withdrawal_count,
    SUM(CASE WHEN txn_type LIKE '%Transfer%' THEN 1 ELSE 0 END) AS transfer_count
FROM fact_transactions
GROUP BY channel
ORDER BY total_flow_amount DESC;


-- ------------------------------------------------------------------------------
-- 5. BRANCH PERFORMANCE & REGIONAL EFFICIENCY
-- Regional banking branch comparison and deposit accumulation
-- ------------------------------------------------------------------------------
CREATE VIEW IF NOT EXISTS view_gold_branch_performance AS
WITH branch_emp AS (
    SELECT branch_id, COUNT(*) AS employee_count
    FROM dim_employees
    GROUP BY branch_id
),
branch_acc AS (
    SELECT branch_id, COUNT(*) AS total_accounts, SUM(balance) AS total_branch_deposits
    FROM dim_accounts
    GROUP BY branch_id
),
branch_loan AS (
    SELECT branch_id, COUNT(*) AS total_loans_originated, SUM(loan_amount) AS total_loan_volume
    FROM dim_loans
    GROUP BY branch_id
)
SELECT 
    b.branch_id,
    b.branch_name,
    b.city,
    b.state,
    COALESCE(e.employee_count, 0) AS employee_count,
    COALESCE(a.total_accounts, 0) AS total_accounts,
    ROUND(COALESCE(a.total_branch_deposits, 0.0), 2) AS total_branch_deposits,
    COALESCE(l.total_loans_originated, 0) AS total_loans_originated,
    ROUND(COALESCE(l.total_loan_volume, 0.0), 2) AS total_loan_volume
FROM dim_branches b
LEFT JOIN branch_emp e ON b.branch_id = e.branch_id
LEFT JOIN branch_acc a ON b.branch_id = a.branch_id
LEFT JOIN branch_loan l ON b.branch_id = l.branch_id
ORDER BY total_branch_deposits DESC;


-- ------------------------------------------------------------------------------
-- 6. CUSTOMER SUPPORT & CSAT EXCELLENCE
-- Operational SLA resolution velocity and customer satisfaction rating
-- ------------------------------------------------------------------------------
CREATE VIEW IF NOT EXISTS view_gold_support_operations AS
SELECT 
    issue_type,
    COUNT(*) AS total_tickets,
    SUM(CASE WHEN status = 'Resolved' THEN 1 ELSE 0 END) AS resolved_count,
    SUM(CASE WHEN status <> 'Resolved' THEN 1 ELSE 0 END) AS open_backlog,
    ROUND(AVG(resolution_days), 1) AS avg_resolution_days,
    ROUND(AVG(satisfaction_score), 2) AS avg_csat_score
FROM fact_support_tickets
GROUP BY issue_type
ORDER BY total_tickets DESC;

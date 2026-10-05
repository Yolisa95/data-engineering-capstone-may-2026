-----------------------------------------------------------
--   1. LOAD STAGING CLIENT DIMENSION
-----------------------------------------------------------
INSERT INTO stg_customer360.dbo.stg_dim_client (
    client_number,
    first_name,
    last_name,
    email,
    mobile_number,
    date_of_birth,
    gender,
    province,
    city,
    signup_date
)
SELECT
    client_number,
    MAX(first_name),
    MAX(last_name),
    MAX(email),
    MAX(mobile_number),
    MAX(date_of_birth),
    MAX(gender),
    MAX(province),
    MAX(city),
    MAX(signup_date)
FROM stg_customer360.dbo.stg_activity_extract
GROUP BY client_number;
GO


-----------------------------------------------------------
--   2. LOAD STAGING PRODUCT DIMENSION
-----------------------------------------------------------
INSERT INTO stg_customer360.dbo.stg_dim_product (
    account_number,
    client_number,
    product_type,
    account_status,
    credit_limit,
    loan_amount,
    account_balance
)
SELECT
    account_number,
    client_number,
    product_type,
    account_status,
    credit_limit,
    loan_amount,
    account_balance
FROM stg_customer360.dbo.stg_activity_extract
WHERE event_type = 'Product Enrollment';
GO


-----------------------------------------------------------
--   3. LOAD STAGING TRANSACTION FACT
-----------------------------------------------------------
INSERT INTO stg_customer360.dbo.stg_fact_transaction (
    client_number,
    account_number,
    event_date,
    product_type,
    channel,
    transaction_type,
    amount
)
SELECT
    client_number,
    account_number,
    event_date,
    product_type,
    channel,
    transaction_type,
    amount
FROM stg_customer360.dbo.stg_activity_extract
WHERE event_type = 'Transaction';
GO


-----------------------------------------------------------
--   4. LOAD STAGING CRM INTERACTION FACT
-----------------------------------------------------------
INSERT INTO stg_customer360.dbo.stg_fact_crm_interaction (
    client_number,
    event_date,
    channel,
    interaction_type,
    resolved_flag
)
SELECT
    client_number,
    event_date,
    channel,
    interaction_type,
    resolved_flag
FROM stg_customer360.dbo.stg_activity_extract
WHERE event_type = 'CRM Interaction';
GO



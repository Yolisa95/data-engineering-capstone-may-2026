-----------------------------------------------------------
--   3. CREATE RAW ACTIVITY EXTRACT LANDING TABLE
-----------------------------------------------------------
IF NOT EXISTS (
    SELECT 1
    FROM stg_customer360.sys.tables t
    INNER JOIN stg_customer360.sys.schemas s
        ON t.schema_id = s.schema_id
    WHERE t.name = 'stg_activity_extract'
      AND s.name = 'dbo'
)
BEGIN
    CREATE TABLE stg_customer360.dbo.stg_activity_extract (
        client_number       VARCHAR(20),
        first_name          VARCHAR(100),
        last_name           VARCHAR(100),
        email               VARCHAR(200),
        mobile_number       VARCHAR(50),
        date_of_birth       VARCHAR(20),
        gender              VARCHAR(10),
        province            VARCHAR(100),
        city                VARCHAR(100),
        signup_date         VARCHAR(20),
        event_type          VARCHAR(30),
        event_date          VARCHAR(20),
        account_number      VARCHAR(20),
        product_type        VARCHAR(50),
        account_status      VARCHAR(20),
        credit_limit        VARCHAR(20),
        loan_amount         VARCHAR(20),
        account_balance     VARCHAR(20),
        channel             VARCHAR(50),
        interaction_type    VARCHAR(50),
        resolved_flag       VARCHAR(5),
        transaction_type    VARCHAR(50),
        amount              VARCHAR(20)
    );
END;
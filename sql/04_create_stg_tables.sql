-----------------------------------------------------------
--   1. CREATE STAGING CLIENT DIMENSION TABLE
-----------------------------------------------------------
IF OBJECT_ID(
    'stg_customer360.dbo.stg_dim_client',
    'U'
) IS NULL
BEGIN
    CREATE TABLE stg_customer360.dbo.stg_dim_client (
        client_number       VARCHAR(20) NOT NULL,
        first_name          VARCHAR(100),
        last_name           VARCHAR(100),
        email               VARCHAR(200),
        mobile_number       VARCHAR(50),
        date_of_birth       VARCHAR(20),
        gender              VARCHAR(10),
        province            VARCHAR(100),
        city                VARCHAR(100),
        signup_date         VARCHAR(20),

        CONSTRAINT PK_stg_dim_client
            PRIMARY KEY (client_number)
    );
END;
GO

-----------------------------------------------------------
--   2. CREATE STAGING PRODUCT DIMENSION TABLE
-----------------------------------------------------------
IF OBJECT_ID(
    'stg_customer360.dbo.stg_dim_product',
    'U'
) IS NULL
BEGIN
    CREATE TABLE stg_customer360.dbo.stg_dim_product (
        account_number      VARCHAR(20) NOT NULL,
        client_number       VARCHAR(20),
        product_type        VARCHAR(50),
        account_status      VARCHAR(20),
        credit_limit        VARCHAR(20),
        loan_amount         VARCHAR(20),
        account_balance     VARCHAR(20),

        CONSTRAINT PK_stg_dim_product
            PRIMARY KEY (account_number)
    );
END;
GO

-----------------------------------------------------------
--   3. CREATE STAGING TRANSACTION FACT TABLE
-----------------------------------------------------------
IF OBJECT_ID(
    'stg_customer360.dbo.stg_fact_transaction',
    'U'
) IS NULL
BEGIN
    CREATE TABLE stg_customer360.dbo.stg_fact_transaction (
        client_number       VARCHAR(20),
        account_number      VARCHAR(20),
        event_date          VARCHAR(20),
        product_type        VARCHAR(50),
        channel             VARCHAR(50),
        transaction_type    VARCHAR(50),
        amount              VARCHAR(20)
    );
END;
GO

-----------------------------------------------------------
--   4. CREATE STAGING CRM INTERACTION FACT TABLE
-----------------------------------------------------------
IF OBJECT_ID(
    'stg_customer360.dbo.stg_fact_crm_interaction',
    'U'
) IS NULL
BEGIN
    CREATE TABLE stg_customer360.dbo.stg_fact_crm_interaction (
        client_number       VARCHAR(20),
        event_date          VARCHAR(20),
        channel             VARCHAR(50),
        interaction_type    VARCHAR(50),
        resolved_flag       VARCHAR(5)
    );
END;
GO
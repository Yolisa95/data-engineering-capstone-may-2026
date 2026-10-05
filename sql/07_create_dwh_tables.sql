-----------------------------------------------------------
--   1. CREATE DWH DATE DIMENSION
-----------------------------------------------------------
IF OBJECT_ID(
    'dwh_customer360.dbo.dwh_dim_date',
    'U'
) IS NULL
BEGIN
    CREATE TABLE dwh_customer360.dbo.dwh_dim_date (
        date_key            INT NOT NULL,
        full_date           DATE NOT NULL,
        day_number          INT NOT NULL,
        month_number        INT NOT NULL,
        month_name          VARCHAR(20) NOT NULL,
        quarter_number      INT NOT NULL,
        year_number         INT NOT NULL,
        day_of_week         INT NOT NULL,
        day_name            VARCHAR(20) NOT NULL,

        CONSTRAINT PK_dwh_dim_date
            PRIMARY KEY (date_key)
    );
END;
GO


-----------------------------------------------------------
--   2. CREATE DWH CLIENT DIMENSION
-----------------------------------------------------------
IF OBJECT_ID(
    'dwh_customer360.dbo.dwh_dim_client',
    'U'
) IS NULL
BEGIN
    CREATE TABLE dwh_customer360.dbo.dwh_dim_client (
        client_key          INT IDENTITY(1,1) NOT NULL,
        client_number       VARCHAR(20) NOT NULL,
        first_name          VARCHAR(100),
        last_name           VARCHAR(100),
        email               VARCHAR(200),
        mobile_number       VARCHAR(50),
        date_of_birth       DATE,
        gender              VARCHAR(10),
        province            VARCHAR(100),
        city                VARCHAR(100),
        signup_date_key     INT,

        CONSTRAINT PK_dwh_dim_client
            PRIMARY KEY (client_key),

        CONSTRAINT UQ_dwh_dim_client_client_number
            UNIQUE (client_number),

        CONSTRAINT FK_dwh_dim_client_signup_date
            FOREIGN KEY (signup_date_key)
            REFERENCES dwh_customer360.dbo.dwh_dim_date(date_key)
    );
END;
GO


-----------------------------------------------------------
--   3. CREATE DWH PRODUCT DIMENSION
-----------------------------------------------------------
IF OBJECT_ID(
    'dwh_customer360.dbo.dwh_dim_product',
    'U'
) IS NULL
BEGIN
    CREATE TABLE dwh_customer360.dbo.dwh_dim_product (
        product_key         INT IDENTITY(1,1) NOT NULL,
        account_number      VARCHAR(20) NOT NULL,
        product_type        VARCHAR(50),
        account_status      VARCHAR(20),
        credit_limit        DECIMAL(18,2),
        loan_amount         DECIMAL(18,2),
        account_balance     DECIMAL(18,2),

        CONSTRAINT PK_dwh_dim_product
            PRIMARY KEY (product_key),

        CONSTRAINT UQ_dwh_dim_product_account_number
            UNIQUE (account_number)
    );
END;
GO


-----------------------------------------------------------
--   4. CREATE DWH TRANSACTION FACT TABLE
-----------------------------------------------------------
IF OBJECT_ID(
    'dwh_customer360.dbo.dwh_fact_transaction',
    'U'
) IS NULL
BEGIN
    CREATE TABLE dwh_customer360.dbo.dwh_fact_transaction (
        transaction_key     INT IDENTITY(1,1) NOT NULL,
        client_key          INT NOT NULL,
        product_key         INT NOT NULL,
        date_key            INT NOT NULL,
        transaction_type    VARCHAR(50),
        channel             VARCHAR(50),
        amount              DECIMAL(18,2),

        CONSTRAINT PK_dwh_fact_transaction
            PRIMARY KEY (transaction_key),

        CONSTRAINT FK_dwh_fact_transaction_client
            FOREIGN KEY (client_key)
            REFERENCES dwh_customer360.dbo.dwh_dim_client(client_key),

        CONSTRAINT FK_dwh_fact_transaction_product
            FOREIGN KEY (product_key)
            REFERENCES dwh_customer360.dbo.dwh_dim_product(product_key),

        CONSTRAINT FK_dwh_fact_transaction_date
            FOREIGN KEY (date_key)
            REFERENCES dwh_customer360.dbo.dwh_dim_date(date_key)
    );
END;
GO


-----------------------------------------------------------
--   5. CREATE DWH CRM INTERACTION FACT TABLE
-----------------------------------------------------------
IF OBJECT_ID(
    'dwh_customer360.dbo.dwh_fact_crm_interaction',
    'U'
) IS NULL
BEGIN
    CREATE TABLE dwh_customer360.dbo.dwh_fact_crm_interaction (
        interaction_key     INT IDENTITY(1,1) NOT NULL,
        client_key          INT NOT NULL,
        date_key            INT NOT NULL,
        channel             VARCHAR(50),
        interaction_type    VARCHAR(50),
        resolved_flag       VARCHAR(5),

        CONSTRAINT PK_dwh_fact_crm_interaction
            PRIMARY KEY (interaction_key),

        CONSTRAINT FK_dwh_fact_crm_interaction_client
            FOREIGN KEY (client_key)
            REFERENCES dwh_customer360.dbo.dwh_dim_client(client_key),

        CONSTRAINT FK_dwh_fact_crm_interaction_date
            FOREIGN KEY (date_key)
            REFERENCES dwh_customer360.dbo.dwh_dim_date(date_key)
    );
END;
GO
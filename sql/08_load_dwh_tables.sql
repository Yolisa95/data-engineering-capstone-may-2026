-----------------------------------------------------------
--   1. LOAD DWH DATE DIMENSION
-----------------------------------------------------------
DECLARE @current_date DATE = '2022-01-01';
DECLARE @end_date DATE = '2026-12-31';

WHILE @current_date <= @end_date
BEGIN

    IF NOT EXISTS (
        SELECT 1
        FROM dwh_customer360.dbo.dwh_dim_date
        WHERE date_key =
            CONVERT(INT, CONVERT(CHAR(8), @current_date, 112))
    )
    BEGIN
        INSERT INTO dwh_customer360.dbo.dwh_dim_date (
            date_key,
            full_date,
            day_number,
            month_number,
            month_name,
            quarter_number,
            year_number,
            day_of_week,
            day_name
        )
        VALUES (
            CONVERT(INT, CONVERT(CHAR(8), @current_date, 112)),
            @current_date,
            DAY(@current_date),
            MONTH(@current_date),
            DATENAME(MONTH, @current_date),
            DATEPART(QUARTER, @current_date),
            YEAR(@current_date),
            DATEPART(WEEKDAY, @current_date),
            DATENAME(WEEKDAY, @current_date)
        );
    END;

    SET @current_date = DATEADD(DAY, 1, @current_date);

END;
GO


-----------------------------------------------------------
--   2. LOAD DWH CLIENT DIMENSION
-----------------------------------------------------------
INSERT INTO dwh_customer360.dbo.dwh_dim_client (
    client_number,
    first_name,
    last_name,
    email,
    mobile_number,
    date_of_birth,
    gender,
    province,
    city,
    signup_date_key
)
SELECT
    s.client_number,
    s.first_name,
    s.last_name,
    s.email,
    s.mobile_number,
    s.date_of_birth,
    s.gender,
    s.province,
    s.city,
    s.signup_date_key
FROM (
    SELECT DISTINCT
        NULLIF(LTRIM(RTRIM(client_number)), '') AS client_number,

        NULLIF(LTRIM(RTRIM(first_name)), '') AS first_name,

        NULLIF(LTRIM(RTRIM(last_name)), '') AS last_name,

        LOWER(
            NULLIF(LTRIM(RTRIM(email)), '')
        ) AS email,

        NULLIF(
            REPLACE(LTRIM(RTRIM(mobile_number)), ' ', ''),
            ''
        ) AS mobile_number,

        TRY_CONVERT(
            DATE,
            NULLIF(LTRIM(RTRIM(date_of_birth)), '')
        ) AS date_of_birth,

        CASE
            WHEN NULLIF(LTRIM(RTRIM(gender)), '') IS NULL THEN 'U'
            WHEN UPPER(LTRIM(RTRIM(gender))) IN ('M', 'F', 'U')
                THEN UPPER(LTRIM(RTRIM(gender)))
            ELSE 'U'
        END AS gender,

        NULLIF(LTRIM(RTRIM(province)), '') AS province,

        NULLIF(LTRIM(RTRIM(city)), '') AS city,

        CONVERT(
            INT,
            CONVERT(
                CHAR(8),
                TRY_CONVERT(
                    DATE,
                    NULLIF(LTRIM(RTRIM(signup_date)), '')
                ),
                112
            )
        ) AS signup_date_key

    FROM stg_customer360.dbo.stg_dim_client
) AS s

WHERE s.client_number IS NOT NULL

AND NOT EXISTS (
    SELECT 1
    FROM dwh_customer360.dbo.dwh_dim_client AS d
    WHERE d.client_number = s.client_number
);
GO

-----------------------------------------------------------
--   3. LOAD DWH PRODUCT DIMENSION
-----------------------------------------------------------
INSERT INTO dwh_customer360.dbo.dwh_dim_product (
    account_number,
    product_type,
    account_status,
    credit_limit,
    loan_amount,
    account_balance
)
SELECT
    s.account_number,
    s.product_type,
    s.account_status,
    s.credit_limit,
    s.loan_amount,
    s.account_balance
FROM (
    SELECT DISTINCT
        NULLIF(LTRIM(RTRIM(account_number)), '') AS account_number,

        NULLIF(LTRIM(RTRIM(product_type)), '') AS product_type,

        NULLIF(LTRIM(RTRIM(account_status)), '') AS account_status,

        TRY_CONVERT(
            DECIMAL(18,2),
            NULLIF(LTRIM(RTRIM(credit_limit)), '')
        ) AS credit_limit,

        TRY_CONVERT(
            DECIMAL(18,2),
            NULLIF(LTRIM(RTRIM(loan_amount)), '')
        ) AS loan_amount,

        TRY_CONVERT(
            DECIMAL(18,2),
            NULLIF(LTRIM(RTRIM(account_balance)), '')
        ) AS account_balance

    FROM stg_customer360.dbo.stg_dim_product
) AS s

WHERE s.account_number IS NOT NULL

AND NOT EXISTS (
    SELECT 1
    FROM dwh_customer360.dbo.dwh_dim_product AS d
    WHERE d.account_number = s.account_number
);
GO

-----------------------------------------------------------
--   1. CREATE UNKNOWN PRODUCT MEMBER

--   PURPOSE: Creates a default product record for
--   transactions that do not have a matching account
--   in the product dimension. This prevents unmatched
--   transactions from being lost and maintains
--   referential integrity in the transaction fact table.
-----------------------------------------------------------
IF NOT EXISTS (
    SELECT 1
    FROM dwh_customer360.dbo.dwh_dim_product
    WHERE account_number = 'UNKNOWN'
)
BEGIN
    INSERT INTO dwh_customer360.dbo.dwh_dim_product (
        account_number,
        product_type,
        account_status,
        credit_limit,
        loan_amount,
        account_balance
    )
    VALUES (
        'UNKNOWN',
        'Unknown',
        'Unknown',
        NULL,
        NULL,
        NULL
    );
END;
GO


-----------------------------------------------------------
--   4. LOAD TRANSACTION FACT
-----------------------------------------------------------
INSERT INTO dwh_customer360.dbo.dwh_fact_transaction (
    client_key,
    product_key,
    date_key,
    transaction_type,
    channel,
    amount
)
SELECT
    c.client_key,

    COALESCE(
        p.product_key,
        unknown_product.product_key
    ) AS product_key,

    CONVERT(
        INT,
        CONVERT(
            CHAR(8),
            TRY_CONVERT(
                DATE,
                NULLIF(LTRIM(RTRIM(t.event_date)), '')
            ),
            112
        )
    ) AS date_key,

    NULLIF(
        LTRIM(RTRIM(t.transaction_type)),
        ''
    ) AS transaction_type,

    NULLIF(
        LTRIM(RTRIM(t.channel)),
        ''
    ) AS channel,

    TRY_CONVERT(
        DECIMAL(18,2),
        NULLIF(LTRIM(RTRIM(t.amount)), '')
    ) AS amount

FROM stg_customer360.dbo.stg_fact_transaction AS t

INNER JOIN dwh_customer360.dbo.dwh_dim_client AS c
    ON c.client_number =
       LTRIM(RTRIM(t.client_number))

LEFT JOIN dwh_customer360.dbo.dwh_dim_product AS p
    ON p.account_number =
       LTRIM(RTRIM(t.account_number))

CROSS JOIN (
    SELECT product_key
    FROM dwh_customer360.dbo.dwh_dim_product
    WHERE account_number = 'UNKNOWN'
) AS unknown_product

WHERE NOT EXISTS (
    SELECT 1
    FROM dwh_customer360.dbo.dwh_fact_transaction AS f
    WHERE f.client_key = c.client_key
      AND f.product_key =
          COALESCE(p.product_key, unknown_product.product_key)
      AND f.date_key =
          CONVERT(
              INT,
              CONVERT(
                  CHAR(8),
                  TRY_CONVERT(
                      DATE,
                      NULLIF(LTRIM(RTRIM(t.event_date)), '')
                  ),
                  112
              )
          )
      AND ISNULL(f.transaction_type, '') =
          ISNULL(NULLIF(LTRIM(RTRIM(t.transaction_type)), ''), '')
      AND ISNULL(f.channel, '') =
          ISNULL(NULLIF(LTRIM(RTRIM(t.channel)), ''), '')
      AND ISNULL(f.amount, 0) =
          ISNULL(
              TRY_CONVERT(
                  DECIMAL(18,2),
                  NULLIF(LTRIM(RTRIM(t.amount)), '')
              ),
              0
          )
);
GO

-----------------------------------------------------------
--   5. LOAD CRM INTERACTION FACT
-----------------------------------------------------------
INSERT INTO dwh_customer360.dbo.dwh_fact_crm_interaction (
    client_key,
    date_key,
    channel,
    interaction_type,
    resolved_flag
)
SELECT
    c.client_key,

    s.date_key,

    s.channel,

    s.interaction_type,

    s.resolved_flag

FROM (
    SELECT DISTINCT
        NULLIF(
            LTRIM(RTRIM(client_number)),
            ''
        ) AS client_number,

        CONVERT(
            INT,
            CONVERT(
                CHAR(8),
                TRY_CONVERT(
                    DATE,
                    NULLIF(LTRIM(RTRIM(event_date)), '')
                ),
                112
            )
        ) AS date_key,

        NULLIF(
            LTRIM(RTRIM(channel)),
            ''
        ) AS channel,

        NULLIF(
            LTRIM(RTRIM(interaction_type)),
            ''
        ) AS interaction_type,

        CASE
            WHEN UPPER(LTRIM(RTRIM(resolved_flag))) = 'Y'
                THEN 'Y'
            WHEN UPPER(LTRIM(RTRIM(resolved_flag))) = 'N'
                THEN 'N'
            ELSE NULL
        END AS resolved_flag

    FROM stg_customer360.dbo.stg_fact_crm_interaction
) AS s

INNER JOIN dwh_customer360.dbo.dwh_dim_client AS c
    ON c.client_number = s.client_number

WHERE NOT EXISTS (
    SELECT 1
    FROM dwh_customer360.dbo.dwh_fact_crm_interaction AS f
    WHERE f.client_key = c.client_key
      AND f.date_key = s.date_key
      AND ISNULL(f.channel, '') =
          ISNULL(s.channel, '')
      AND ISNULL(f.interaction_type, '') =
          ISNULL(s.interaction_type, '')
      AND ISNULL(f.resolved_flag, '') =
          ISNULL(s.resolved_flag, '')
);
GO
/* ============================================================
Customer 360 Intern Project
File: 01_profile_source.sql

Purpose: Profile the raw banking extract before designing the dimensional model.

Source table: stg_customer360.dbo.stg_activity_extract
============================================================ */


-----------------------------------------------------------
--   1. TOTAL ROW COUNT
-----------------------------------------------------------
SELECT
    COUNT(*) AS total_rows
FROM stg_customer360.dbo.stg_activity_extract;


-----------------------------------------------------------
--   2. ROW COUNT BY EVENT TYPE
-----------------------------------------------------------
SELECT
    event_type,
    COUNT(*) AS row_count
FROM stg_customer360.dbo.stg_activity_extract
GROUP BY event_type
ORDER BY row_count DESC;


-----------------------------------------------------------
--   3. DISTINCT CLIENT COUNT
-----------------------------------------------------------
SELECT
    COUNT(DISTINCT client_number) AS distinct_clients
FROM stg_customer360.dbo.stg_activity_extract;


-----------------------------------------------------------
--   4. MISSING CLIENT NUMBERS
-----------------------------------------------------------
SELECT
    COUNT(*) AS missing_client_numbers
FROM stg_customer360.dbo.stg_activity_extract
WHERE client_number IS NULL
   OR LTRIM(RTRIM(client_number)) = '';


-----------------------------------------------------------
--   5. MISSING CLIENT INFORMATION
-----------------------------------------------------------
SELECT
    SUM(CASE
        WHEN first_name IS NULL OR LTRIM(RTRIM(first_name)) = ''
        THEN 1 ELSE 0
    END) AS missing_first_name,

    SUM(CASE
        WHEN last_name IS NULL OR LTRIM(RTRIM(last_name)) = ''
        THEN 1 ELSE 0
    END) AS missing_last_name,

    SUM(CASE
        WHEN email IS NULL OR LTRIM(RTRIM(email)) = ''
        THEN 1 ELSE 0
    END) AS missing_email,

    SUM(CASE
        WHEN mobile_number IS NULL OR LTRIM(RTRIM(mobile_number)) = ''
        THEN 1 ELSE 0
    END) AS missing_mobile,

    SUM(CASE
        WHEN date_of_birth IS NULL OR LTRIM(RTRIM(date_of_birth)) = ''
        THEN 1 ELSE 0
    END) AS missing_date_of_birth,

    SUM(CASE
        WHEN gender IS NULL OR LTRIM(RTRIM(gender)) = ''
        THEN 1 ELSE 0
    END) AS missing_gender,

    SUM(CASE
        WHEN province IS NULL OR LTRIM(RTRIM(province)) = ''
        THEN 1 ELSE 0
    END) AS missing_province,

    SUM(CASE
        WHEN city IS NULL OR LTRIM(RTRIM(city)) = ''
        THEN 1 ELSE 0
    END) AS missing_city,

    SUM(CASE
        WHEN signup_date IS NULL OR LTRIM(RTRIM(signup_date)) = ''
        THEN 1 ELSE 0
    END) AS missing_signup_date
FROM stg_customer360.dbo.stg_activity_extract;


-----------------------------------------------------------
--   6. GENDER VALUES
-----------------------------------------------------------
SELECT
    gender,
    COUNT(*) AS row_count
FROM stg_customer360.dbo.stg_activity_extract
GROUP BY gender
ORDER BY row_count DESC;


-----------------------------------------------------------
--   7. PROVINCE VALUES
-----------------------------------------------------------
SELECT
    province,
    COUNT(*) AS row_count
FROM stg_customer360.dbo.stg_activity_extract
GROUP BY province
ORDER BY province;


-----------------------------------------------------------
--   8. INVALID DATES
-----------------------------------------------------------
SELECT
    SUM(CASE
        WHEN date_of_birth IS NOT NULL
         AND LTRIM(RTRIM(date_of_birth)) <> ''
         AND TRY_CONVERT(DATE, date_of_birth) IS NULL
        THEN 1 ELSE 0
    END) AS invalid_date_of_birth,

    SUM(CASE
        WHEN signup_date IS NOT NULL
         AND LTRIM(RTRIM(signup_date)) <> ''
         AND TRY_CONVERT(DATE, signup_date) IS NULL
        THEN 1 ELSE 0
    END) AS invalid_signup_date,

    SUM(CASE
        WHEN event_date IS NOT NULL
         AND LTRIM(RTRIM(event_date)) <> ''
         AND TRY_CONVERT(DATE, event_date) IS NULL
        THEN 1 ELSE 0
    END) AS invalid_event_date
FROM stg_customer360.dbo.stg_activity_extract;


-----------------------------------------------------------
--   9. DATE RANGES
-----------------------------------------------------------
SELECT
    MIN(TRY_CONVERT(DATE, date_of_birth)) AS earliest_date_of_birth,
    MAX(TRY_CONVERT(DATE, date_of_birth)) AS latest_date_of_birth,
    MIN(TRY_CONVERT(DATE, signup_date)) AS earliest_signup_date,
    MAX(TRY_CONVERT(DATE, signup_date)) AS latest_signup_date,
    MIN(TRY_CONVERT(DATE, event_date)) AS earliest_event_date,
    MAX(TRY_CONVERT(DATE, event_date)) AS latest_event_date
FROM stg_customer360.dbo.stg_activity_extract;


-----------------------------------------------------------
--   10. EVENTS BEFORE CLIENT SIGNUP
-----------------------------------------------------------
SELECT
    COUNT(*) AS events_before_signup
FROM stg_customer360.dbo.stg_activity_extract
WHERE TRY_CONVERT(DATE, event_date)
    < TRY_CONVERT(DATE, signup_date);


-----------------------------------------------------------
--   11. PRODUCT ENROLLMENT PROFILE
-----------------------------------------------------------
SELECT
    product_type,
    account_status,
    COUNT(*) AS enrollment_count
FROM stg_customer360.dbo.stg_activity_extract
WHERE LTRIM(RTRIM(event_type)) = 'Product Enrollment'
GROUP BY
    product_type,
    account_status
ORDER BY
    product_type,
    account_status;


-----------------------------------------------------------
--   12. DUPLICATE ACCOUNT NUMBERS IN PRODUCT ENROLLMENTS
-----------------------------------------------------------
SELECT
    account_number,
    COUNT(*) AS enrollment_rows
FROM stg_customer360.dbo.stg_activity_extract
WHERE LTRIM(RTRIM(event_type)) = 'Product Enrollment'
GROUP BY account_number
HAVING COUNT(*) > 1
ORDER BY enrollment_rows DESC;


-----------------------------------------------------------
--   13. TRANSACTION ACCOUNTS WITHOUT PRODUCT ENROLLMENT
-----------------------------------------------------------
SELECT
    t.account_number,
    COUNT(*) AS transaction_count
FROM stg_customer360.dbo.stg_activity_extract AS t
WHERE LTRIM(RTRIM(t.event_type)) = 'Transaction'
  AND NOT EXISTS (
        SELECT 1
        FROM stg_customer360.dbo.stg_activity_extract AS e
        WHERE LTRIM(RTRIM(e.event_type)) = 'Product Enrollment'
          AND LTRIM(RTRIM(e.account_number))
              = LTRIM(RTRIM(t.account_number))
  )
GROUP BY t.account_number
ORDER BY t.account_number;


-----------------------------------------------------------
--   14. TRANSACTION ACCOUNT OWNERSHIP CONSISTENCY
-----------------------------------------------------------
SELECT DISTINCT
    t.account_number,
    t.client_number AS transaction_client,
    e.client_number AS enrollment_client
FROM stg_customer360.dbo.stg_activity_extract AS t
INNER JOIN stg_customer360.dbo.stg_activity_extract AS e
    ON LTRIM(RTRIM(t.account_number))
        = LTRIM(RTRIM(e.account_number))
WHERE LTRIM(RTRIM(t.event_type)) = 'Transaction'
  AND LTRIM(RTRIM(e.event_type)) = 'Product Enrollment'
  AND LTRIM(RTRIM(t.client_number))
        <> LTRIM(RTRIM(e.client_number));


-----------------------------------------------------------
--   15. PRODUCT TYPE CONSISTENCY
-----------------------------------------------------------
SELECT
    t.account_number,
    t.product_type AS transaction_product,
    e.product_type AS enrollment_product,
    COUNT(*) AS affected_transactions
FROM stg_customer360.dbo.stg_activity_extract AS t
INNER JOIN stg_customer360.dbo.stg_activity_extract AS e
    ON LTRIM(RTRIM(t.account_number))
        = LTRIM(RTRIM(e.account_number))
WHERE LTRIM(RTRIM(t.event_type)) = 'Transaction'
  AND LTRIM(RTRIM(e.event_type)) = 'Product Enrollment'
  AND UPPER(LTRIM(RTRIM(t.product_type)))
        <> UPPER(LTRIM(RTRIM(e.product_type)))
GROUP BY
    t.account_number,
    t.product_type,
    e.product_type;


-----------------------------------------------------------
--   16. TRANSACTION AMOUNT SIGNS
-----------------------------------------------------------
SELECT
    transaction_type,
    COUNT(*) AS transaction_count,

    SUM(CASE
        WHEN TRY_CONVERT(DECIMAL(18,2), amount) > 0
        THEN 1 ELSE 0
    END) AS positive_amounts,

    SUM(CASE
        WHEN TRY_CONVERT(DECIMAL(18,2), amount) < 0
        THEN 1 ELSE 0
    END) AS negative_amounts,

    SUM(CASE
        WHEN TRY_CONVERT(DECIMAL(18,2), amount) = 0
        THEN 1 ELSE 0
    END) AS zero_amounts,

    MIN(TRY_CONVERT(DECIMAL(18,2), amount)) AS minimum_amount,
    MAX(TRY_CONVERT(DECIMAL(18,2), amount)) AS maximum_amount
FROM stg_customer360.dbo.stg_activity_extract
WHERE LTRIM(RTRIM(event_type)) = 'Transaction'
GROUP BY transaction_type
ORDER BY transaction_type;


-----------------------------------------------------------
--   17. INVALID NUMERIC VALUES
-----------------------------------------------------------
SELECT
    SUM(CASE
        WHEN amount IS NOT NULL
         AND LTRIM(RTRIM(amount)) <> ''
         AND TRY_CONVERT(DECIMAL(18,2), amount) IS NULL
        THEN 1 ELSE 0
    END) AS invalid_amount,

    SUM(CASE
        WHEN credit_limit IS NOT NULL
         AND LTRIM(RTRIM(credit_limit)) <> ''
         AND TRY_CONVERT(DECIMAL(18,2), credit_limit) IS NULL
        THEN 1 ELSE 0
    END) AS invalid_credit_limit,

    SUM(CASE
        WHEN loan_amount IS NOT NULL
         AND LTRIM(RTRIM(loan_amount)) <> ''
         AND TRY_CONVERT(DECIMAL(18,2), loan_amount) IS NULL
        THEN 1 ELSE 0
    END) AS invalid_loan_amount,

    SUM(CASE
        WHEN account_balance IS NOT NULL
         AND LTRIM(RTRIM(account_balance)) <> ''
         AND TRY_CONVERT(DECIMAL(18,2), account_balance) IS NULL
        THEN 1 ELSE 0
    END) AS invalid_account_balance
FROM stg_customer360.dbo.stg_activity_extract;


-----------------------------------------------------------
--   18. CRM INTERACTION PROFILE
-----------------------------------------------------------
SELECT
    channel,
    interaction_type,
    resolved_flag,
    COUNT(*) AS interaction_count
FROM stg_customer360.dbo.stg_activity_extract
WHERE LTRIM(RTRIM(event_type)) = 'CRM Interaction'
GROUP BY
    channel,
    interaction_type,
    resolved_flag
ORDER BY
    channel,
    interaction_type,
    resolved_flag;


-----------------------------------------------------------
--   19. TRANSACTION CHANNEL PROFILE
-----------------------------------------------------------
SELECT
    channel,
    COUNT(*) AS transaction_count
FROM stg_customer360.dbo.stg_activity_extract
WHERE LTRIM(RTRIM(event_type)) = 'Transaction'
GROUP BY channel
ORDER BY transaction_count DESC;


-----------------------------------------------------------
--   20. SUMMARY BY EVENT TYPE
-----------------------------------------------------------
SELECT
    event_type,
    COUNT(*) AS total_rows,
    COUNT(DISTINCT client_number) AS distinct_clients,
    COUNT(DISTINCT account_number) AS distinct_accounts,
    MIN(TRY_CONVERT(DATE, event_date)) AS first_event_date,
    MAX(TRY_CONVERT(DATE, event_date)) AS last_event_date
FROM stg_customer360.dbo.stg_activity_extract
GROUP BY event_type
ORDER BY event_type;


-----------------------------------------------------------
--   21. CLIENT ATTRIBUTE CONSISTENCY
-----------------------------------------------------------
SELECT
    client_number,
    COUNT(DISTINCT UPPER(LTRIM(RTRIM(first_name)))) AS first_name_versions,
    COUNT(DISTINCT UPPER(LTRIM(RTRIM(last_name)))) AS last_name_versions,
    COUNT(DISTINCT LOWER(LTRIM(RTRIM(email)))) AS email_versions,
    COUNT(DISTINCT LTRIM(RTRIM(mobile_number))) AS mobile_versions,
    COUNT(DISTINCT LTRIM(RTRIM(date_of_birth))) AS date_of_birth_versions,
    COUNT(DISTINCT UPPER(LTRIM(RTRIM(gender)))) AS gender_versions,
    COUNT(DISTINCT UPPER(LTRIM(RTRIM(province)))) AS province_versions,
    COUNT(DISTINCT UPPER(LTRIM(RTRIM(city)))) AS city_versions,
    COUNT(DISTINCT LTRIM(RTRIM(signup_date))) AS signup_date_versions
FROM stg_customer360.dbo.stg_activity_extract
GROUP BY client_number
HAVING
       COUNT(DISTINCT UPPER(LTRIM(RTRIM(first_name)))) > 1
    OR COUNT(DISTINCT UPPER(LTRIM(RTRIM(last_name)))) > 1
    OR COUNT(DISTINCT LOWER(LTRIM(RTRIM(email)))) > 1
    OR COUNT(DISTINCT LTRIM(RTRIM(mobile_number))) > 1
    OR COUNT(DISTINCT LTRIM(RTRIM(date_of_birth))) > 1
    OR COUNT(DISTINCT UPPER(LTRIM(RTRIM(gender)))) > 1
    OR COUNT(DISTINCT UPPER(LTRIM(RTRIM(province)))) > 1
    OR COUNT(DISTINCT UPPER(LTRIM(RTRIM(city)))) > 1
    OR COUNT(DISTINCT LTRIM(RTRIM(signup_date))) > 1
ORDER BY client_number;


-----------------------------------------------------------
--   22. EXACT DUPLICATE ROWS
-----------------------------------------------------------
SELECT
    client_number,
    first_name,
    last_name,
    email,
    mobile_number,
    date_of_birth,
    gender,
    province,
    city,
    signup_date,
    event_type,
    event_date,
    account_number,
    product_type,
    account_status,
    credit_limit,
    loan_amount,
    account_balance,
    channel,
    interaction_type,
    resolved_flag,
    transaction_type,
    amount,
    COUNT(*) AS duplicate_count
FROM stg_customer360.dbo.stg_activity_extract
GROUP BY
    client_number,
    first_name,
    last_name,
    email,
    mobile_number,
    date_of_birth,
    gender,
    province,
    city,
    signup_date,
    event_type,
    event_date,
    account_number,
    product_type,
    account_status,
    credit_limit,
    loan_amount,
    account_balance,
    channel,
    interaction_type,
    resolved_flag,
    transaction_type,
    amount
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC;
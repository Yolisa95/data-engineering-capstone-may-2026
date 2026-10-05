-----------------------------------------------------------
--   CUSTOMER BASE
-----------------------------------------------------------

--   1. How many customers does the bank have per province, and what share of the total does each province represent?

SELECT
    province,
    COUNT(*) AS customer_count,
    CAST(
        COUNT(*) * 100.0 /
        SUM(COUNT(*)) OVER ()
        AS DECIMAL(5,2)
    ) AS percentage_of_total
FROM dwh_customer360.dbo.dwh_dim_client
GROUP BY province
ORDER BY customer_count DESC;
GO

--   2. What is the age distribution of the customer base? Present it in age bands of your own choosing and justify the bands.

--   Age bands used: Under 25, 25-34, 35-44, 45-54, 55-64 and 65+.
--   These bands provide clear customer life-stage groupings while keeping the results easy to interpret.

DECLARE @reference_date DATE;

SELECT
    @reference_date = MAX(d.full_date)
FROM dwh_customer360.dbo.dwh_fact_transaction AS f
INNER JOIN dwh_customer360.dbo.dwh_dim_date AS d
    ON f.date_key = d.date_key;

WITH customer_age AS (
    SELECT
        client_key,
        DATEDIFF(YEAR, date_of_birth, @reference_date)
        -
        CASE
            WHEN DATEADD(
                YEAR,
                DATEDIFF(YEAR, date_of_birth, @reference_date),
                date_of_birth
            ) > @reference_date
            THEN 1
            ELSE 0
        END AS age
    FROM dwh_customer360.dbo.dwh_dim_client
)
SELECT
    CASE
        WHEN age < 25 THEN 'Under 25'
        WHEN age BETWEEN 25 AND 34 THEN '25-34'
        WHEN age BETWEEN 35 AND 44 THEN '35-44'
        WHEN age BETWEEN 45 AND 54 THEN '45-54'
        WHEN age BETWEEN 55 AND 64 THEN '55-64'
        ELSE '65+'
    END AS age_band,
    COUNT(*) AS customer_count
FROM customer_age
GROUP BY
    CASE
        WHEN age < 25 THEN 'Under 25'
        WHEN age BETWEEN 25 AND 34 THEN '25-34'
        WHEN age BETWEEN 35 AND 44 THEN '35-44'
        WHEN age BETWEEN 45 AND 54 THEN '45-54'
        WHEN age BETWEEN 55 AND 64 THEN '55-64'
        ELSE '65+'
    END
ORDER BY MIN(age);
GO

--   3. How many customers have signed up per month over the last two years? Is signup growth trending up, flat, or down?

DECLARE @latest_signup_date DATE;

SELECT
    @latest_signup_date = MAX(d.full_date)
FROM dwh_customer360.dbo.dwh_dim_client AS c
INNER JOIN dwh_customer360.dbo.dwh_dim_date AS d
    ON c.signup_date_key = d.date_key;

SELECT
    d.year_number,
    d.month_number,
    d.month_name,
    COUNT(*) AS signup_count
FROM dwh_customer360.dbo.dwh_dim_client AS c
INNER JOIN dwh_customer360.dbo.dwh_dim_date AS d
    ON c.signup_date_key = d.date_key
WHERE d.full_date >= DATEADD(YEAR, -2, @latest_signup_date)
GROUP BY
    d.year_number,
    d.month_number,
    d.month_name
ORDER BY
    d.year_number,
    d.month_number;
GO

--   4. How many customer records look like data quality problems (e.g. missing contact details, duplicate identity)? Report the count and what you count as a "problem".

--   A problem is defined as a customer with missing email or mobile number,
--   missing identity/demographic details, unknown gender, missing location
--   information, or a duplicate client number.

WITH duplicate_clients AS (
    SELECT
        client_number
    FROM dwh_customer360.dbo.dwh_dim_client
    GROUP BY client_number
    HAVING COUNT(*) > 1
)
SELECT
    COUNT(*) AS customers_with_data_quality_problems
FROM dwh_customer360.dbo.dwh_dim_client AS c
WHERE
       c.email IS NULL
    OR c.mobile_number IS NULL
    OR c.first_name IS NULL
    OR c.last_name IS NULL
    OR c.date_of_birth IS NULL
    OR c.gender IS NULL
    OR c.gender = 'U'
    OR c.province IS NULL
    OR c.city IS NULL
    OR EXISTS (
        SELECT 1
        FROM duplicate_clients AS d
        WHERE d.client_number = c.client_number
    );
GO

-----------------------------------------------------------
--   PRODUCTS
-----------------------------------------------------------

--   5. How many customers hold each product type, and how many customers hold more than one product type?

SELECT
    product_type,
    COUNT(DISTINCT c.client_key) AS customer_count
FROM dwh_customer360.dbo.dwh_dim_product AS p
INNER JOIN dwh_customer360.dbo.dwh_fact_transaction AS t
    ON p.product_key = t.product_key
INNER JOIN dwh_customer360.dbo.dwh_dim_client AS c
    ON t.client_key = c.client_key
WHERE p.account_number <> 'UNKNOWN'
GROUP BY product_type
ORDER BY customer_count DESC;
GO

SELECT
    COUNT(*) AS customers_with_multiple_product_types
FROM (
    SELECT
        t.client_key
    FROM dwh_customer360.dbo.dwh_fact_transaction AS t
    INNER JOIN dwh_customer360.dbo.dwh_dim_product AS p
        ON t.product_key = p.product_key
    WHERE p.account_number <> 'UNKNOWN'
    GROUP BY t.client_key
    HAVING COUNT(DISTINCT p.product_type) > 1
) AS multi_product_customers;
GO


--   6. What is the total and average account balance by product type?

SELECT
    product_type,
    COUNT(*) AS account_count,
    SUM(account_balance) AS total_account_balance,
    CAST(AVG(account_balance) AS DECIMAL(18,2)) AS average_account_balance
FROM dwh_customer360.dbo.dwh_dim_product
WHERE account_number <> 'UNKNOWN'
GROUP BY product_type
ORDER BY product_type;
GO


--   7. Which customers hold a Savings account but no Credit Card? Report the count, this is a cross-sell list.

WITH customer_products AS (
    SELECT DISTINCT
        t.client_key,
        p.product_type
    FROM dwh_customer360.dbo.dwh_fact_transaction AS t
    INNER JOIN dwh_customer360.dbo.dwh_dim_product AS p
        ON t.product_key = p.product_key
    WHERE p.account_number <> 'UNKNOWN'
),
cross_sell_customers AS (
    SELECT
        client_key
    FROM customer_products
    GROUP BY client_key
    HAVING
        MAX(CASE WHEN product_type = 'Savings' THEN 1 ELSE 0 END) = 1
        AND
        MAX(CASE WHEN product_type = 'Credit Card' THEN 1 ELSE 0 END) = 0
)
SELECT
    COUNT(*) AS savings_without_credit_card
FROM cross_sell_customers;
GO

WITH customer_products AS (
    SELECT DISTINCT
        t.client_key,
        p.product_type
    FROM dwh_customer360.dbo.dwh_fact_transaction AS t
    INNER JOIN dwh_customer360.dbo.dwh_dim_product AS p
        ON t.product_key = p.product_key
    WHERE p.account_number <> 'UNKNOWN'
),
cross_sell_customers AS (
    SELECT
        client_key
    FROM customer_products
    GROUP BY client_key
    HAVING
        MAX(CASE WHEN product_type = 'Savings' THEN 1 ELSE 0 END) = 1
        AND
        MAX(CASE WHEN product_type = 'Credit Card' THEN 1 ELSE 0 END) = 0
)
SELECT
    c.client_number,
    c.first_name,
    c.last_name,
    c.email,
    c.mobile_number
FROM cross_sell_customers AS x
INNER JOIN dwh_customer360.dbo.dwh_dim_client AS c
    ON x.client_key = c.client_key
ORDER BY c.client_number;
GO


--   8. What proportion of Credit Card accounts are within 90% of their credit limit?

SELECT
    COUNT(*) AS total_credit_card_accounts,
    SUM(
        CASE
            WHEN account_balance >= credit_limit * 0.90
            THEN 1
            ELSE 0
        END
    ) AS accounts_within_90_percent,
    CAST(
        SUM(
            CASE
                WHEN account_balance >= credit_limit * 0.90
                THEN 1
                ELSE 0
            END
        ) * 100.0 / NULLIF(COUNT(*), 0)
        AS DECIMAL(5,2)
    ) AS percentage_within_90_percent
FROM dwh_customer360.dbo.dwh_dim_product
WHERE product_type = 'Credit Card'
  AND credit_limit IS NOT NULL
  AND credit_limit > 0;
GO

-----------------------------------------------------------
--   TRANSACTIONS
-----------------------------------------------------------

--   9. What is the total transaction value by month, split by transaction type? Are there any seasonal patterns?

SELECT
    d.year_number,
    d.month_number,
    d.month_name,
    t.transaction_type,
    COUNT(*) AS transaction_count,
    SUM(t.amount) AS total_transaction_value
FROM dwh_customer360.dbo.dwh_fact_transaction AS t
INNER JOIN dwh_customer360.dbo.dwh_dim_date AS d
    ON t.date_key = d.date_key
GROUP BY
    d.year_number,
    d.month_number,
    d.month_name,
    t.transaction_type
ORDER BY
    d.year_number,
    d.month_number,
    t.transaction_type;
GO


--   10. Which transaction channel handles the most transactions, and which handles the highest total value? (These may not be the same channel, explain why, if so.)


SELECT
    channel,
    COUNT(*) AS transaction_count,
    SUM(amount) AS total_transaction_value,
    SUM(ABS(amount)) AS total_absolute_transaction_value
FROM dwh_customer360.dbo.dwh_fact_transaction
GROUP BY channel
ORDER BY transaction_count DESC;
GO


--   11. Define an "active customer" using transaction recency, then report how many customers are active versus not active as of the latest date in the data.

--   An active customer is defined as a customer who made at least one transaction
--   within the last 90 days relative to the latest transaction date in the data.

DECLARE @latest_transaction_date DATE;

SELECT
    @latest_transaction_date = MAX(d.full_date)
FROM dwh_customer360.dbo.dwh_fact_transaction AS t
INNER JOIN dwh_customer360.dbo.dwh_dim_date AS d
    ON t.date_key = d.date_key;

WITH last_transaction AS (
    SELECT
        t.client_key,
        MAX(d.full_date) AS last_transaction_date
    FROM dwh_customer360.dbo.dwh_fact_transaction AS t
    INNER JOIN dwh_customer360.dbo.dwh_dim_date AS d
        ON t.date_key = d.date_key
    GROUP BY t.client_key
),
customer_status AS (
    SELECT
        c.client_key,
        CASE
            WHEN lt.last_transaction_date >= DATEADD(DAY, -90, @latest_transaction_date)
                THEN 'Active'
            ELSE 'Not Active'
        END AS activity_status
    FROM dwh_customer360.dbo.dwh_dim_client AS c
    LEFT JOIN last_transaction AS lt
        ON c.client_key = lt.client_key
)
SELECT
    activity_status,
    COUNT(*) AS customer_count
FROM customer_status
GROUP BY activity_status;
GO


--   12. Who are the top 20 customers by total transaction value in the last 12 months, using the latest transaction date in the data?

DECLARE @latest_transaction_date_q12 DATE;

SELECT
    @latest_transaction_date_q12 = MAX(d.full_date)
FROM dwh_customer360.dbo.dwh_fact_transaction AS t
INNER JOIN dwh_customer360.dbo.dwh_dim_date AS d
    ON t.date_key = d.date_key;

SELECT TOP 20
    c.client_number,
    c.first_name,
    c.last_name,
    COUNT(*) AS transaction_count,
    SUM(t.amount) AS total_transaction_value,
    SUM(ABS(t.amount)) AS total_transaction_activity
FROM dwh_customer360.dbo.dwh_fact_transaction AS t
INNER JOIN dwh_customer360.dbo.dwh_dim_client AS c
    ON t.client_key = c.client_key
INNER JOIN dwh_customer360.dbo.dwh_dim_date AS d
    ON t.date_key = d.date_key
WHERE d.full_date > DATEADD(YEAR, -1, @latest_transaction_date_q12)
  AND d.full_date <= @latest_transaction_date_q12
GROUP BY
    c.client_number,
    c.first_name,
    c.last_name
ORDER BY total_transaction_value DESC;
GO

-----------------------------------------------------------
--   CRM / ENGAGEMENT
-----------------------------------------------------------

--   13. What is the average number of interactions per customer, split by interaction type?

WITH customer_interactions AS (
    SELECT
        client_key,
        interaction_type,
        COUNT(*) AS interaction_count
    FROM dwh_customer360.dbo.dwh_fact_crm_interaction
    GROUP BY
        client_key,
        interaction_type
)
SELECT
    interaction_type,
    CAST(AVG(CAST(interaction_count AS DECIMAL(10,2))) AS DECIMAL(10,2)) AS average_interactions_per_customer
FROM customer_interactions
GROUP BY interaction_type
ORDER BY interaction_type;
GO


--   14. Which channel is most used for complaints specifically, versus other interaction types?

SELECT
    interaction_type,
    channel,
    COUNT(*) AS interaction_count
FROM dwh_customer360.dbo.dwh_fact_crm_interaction
GROUP BY
    interaction_type,
    channel
ORDER BY
    interaction_type,
    interaction_count DESC;
GO


--   15. What is the resolution rate (`resolved_flag = Y`) by channel? Which channel resolves the least, and could that be sample-size noise rather than a real difference?

SELECT
    channel,
    COUNT(*) AS total_interactions,
    SUM(
        CASE
            WHEN resolved_flag = 'Y' THEN 1
            ELSE 0
        END
    ) AS resolved_interactions,
    CAST(
        SUM(
            CASE
                WHEN resolved_flag = 'Y' THEN 1
                ELSE 0
            END
        ) * 100.0 / NULLIF(COUNT(*), 0)
        AS DECIMAL(5,2)
    ) AS resolution_rate_percentage
FROM dwh_customer360.dbo.dwh_fact_crm_interaction
GROUP BY channel
ORDER BY resolution_rate_percentage ASC;
GO

-----------------------------------------------------------
--   COMBINED / SEGMENTATION
-----------------------------------------------------------

--   16. Segment customers into a small number of value tiers based on transaction activity (your choice of method, quartiles, fixed thresholds, etc.). Report the customer count and total transaction value per tier.

WITH customer_value AS (
    SELECT
        c.client_key,
        COALESCE(SUM(ABS(t.amount)), 0) AS total_transaction_value
    FROM dwh_customer360.dbo.dwh_dim_client AS c
    LEFT JOIN dwh_customer360.dbo.dwh_fact_transaction AS t
        ON c.client_key = t.client_key
    GROUP BY c.client_key
),
customer_tiers AS (
    SELECT
        client_key,
        total_transaction_value,
        NTILE(4) OVER (ORDER BY total_transaction_value) AS value_tier
    FROM customer_value
)
SELECT
    CASE value_tier
        WHEN 1 THEN 'Tier 1 - Low Value'
        WHEN 2 THEN 'Tier 2 - Medium Value'
        WHEN 3 THEN 'Tier 3 - High Value'
        WHEN 4 THEN 'Tier 4 - Very High Value'
    END AS value_tier,
    COUNT(*) AS customer_count,
    SUM(total_transaction_value) AS total_transaction_value
FROM customer_tiers
GROUP BY value_tier
ORDER BY value_tier;
GO


--   17. Build a simple customer lifecycle segmentation (e.g. New / Active / At risk / Dormant) using signup date and activity recency. State your thresholds and justify them. Report the customer count per segment.

--   New: signed up within the last 90 days.
--   Active: last transaction was within the last 90 days.
--   At risk: last transaction was between 91 and 180 days ago.
--   Dormant: last transaction was more than 180 days ago or the customer has never transacted.
--   These thresholds separate recently acquired and recently active customers from customers showing increasing periods of inactivity.

DECLARE @latest_activity_date DATE;

SELECT
    @latest_activity_date = MAX(d.full_date)
FROM dwh_customer360.dbo.dwh_fact_transaction AS t
INNER JOIN dwh_customer360.dbo.dwh_dim_date AS d
    ON t.date_key = d.date_key;

WITH customer_activity AS (
    SELECT
        c.client_key,
        signup.full_date AS signup_date,
        MAX(activity.full_date) AS last_transaction_date
    FROM dwh_customer360.dbo.dwh_dim_client AS c
    LEFT JOIN dwh_customer360.dbo.dwh_dim_date AS signup
        ON c.signup_date_key = signup.date_key
    LEFT JOIN dwh_customer360.dbo.dwh_fact_transaction AS t
        ON c.client_key = t.client_key
    LEFT JOIN dwh_customer360.dbo.dwh_dim_date AS activity
        ON t.date_key = activity.date_key
    GROUP BY
        c.client_key,
        signup.full_date
),
customer_segments AS (
    SELECT
        client_key,
        CASE
            WHEN signup_date >= DATEADD(DAY, -90, @latest_activity_date)
                THEN 'New'
            WHEN last_transaction_date >= DATEADD(DAY, -90, @latest_activity_date)
                THEN 'Active'
            WHEN last_transaction_date >= DATEADD(DAY, -180, @latest_activity_date)
                THEN 'At risk'
            ELSE 'Dormant'
        END AS lifecycle_segment
    FROM customer_activity
)
SELECT
    lifecycle_segment,
    COUNT(*) AS customer_count
FROM customer_segments
GROUP BY lifecycle_segment
ORDER BY
    CASE lifecycle_segment
        WHEN 'New' THEN 1
        WHEN 'Active' THEN 2
        WHEN 'At risk' THEN 3
        WHEN 'Dormant' THEN 4
    END;
GO


--   18. Is there a relationship between number of CRM interactions and transaction value? (A simple grouped comparison is enough, this is not a statistics course.)

WITH transaction_summary AS (
    SELECT
        client_key,
        SUM(ABS(amount)) AS total_transaction_value
    FROM dwh_customer360.dbo.dwh_fact_transaction
    GROUP BY client_key
),
crm_summary AS (
    SELECT
        client_key,
        COUNT(*) AS crm_interaction_count
    FROM dwh_customer360.dbo.dwh_fact_crm_interaction
    GROUP BY client_key
),
customer_summary AS (
    SELECT
        c.client_key,
        COALESCE(crm.crm_interaction_count, 0) AS crm_interaction_count,
        COALESCE(t.total_transaction_value, 0) AS total_transaction_value
    FROM dwh_customer360.dbo.dwh_dim_client AS c
    LEFT JOIN crm_summary AS crm
        ON c.client_key = crm.client_key
    LEFT JOIN transaction_summary AS t
        ON c.client_key = t.client_key
),
grouped_customers AS (
    SELECT
        CASE
            WHEN crm_interaction_count = 0 THEN '0 interactions'
            WHEN crm_interaction_count BETWEEN 1 AND 2 THEN '1-2 interactions'
            WHEN crm_interaction_count BETWEEN 3 AND 5 THEN '3-5 interactions'
            ELSE '6+ interactions'
        END AS interaction_group,
        total_transaction_value
    FROM customer_summary
)
SELECT
    interaction_group,
    COUNT(*) AS customer_count,
    CAST(AVG(total_transaction_value) AS DECIMAL(18,2)) AS average_transaction_value,
    SUM(total_transaction_value) AS total_transaction_value
FROM grouped_customers
GROUP BY interaction_group
ORDER BY
    CASE interaction_group
        WHEN '0 interactions' THEN 1
        WHEN '1-2 interactions' THEN 2
        WHEN '3-5 interactions' THEN 3
        WHEN '6+ interactions' THEN 4
    END;
GO

-----------------------------------------------------------
--   STRETCH
-----------------------------------------------------------

--   19. Build a month-over-month retention view: of customers active in month N, what percentage were still active in month N+1?

WITH monthly_activity AS (
    SELECT DISTINCT
        t.client_key,
        DATEFROMPARTS(d.year_number, d.month_number, 1) AS activity_month
    FROM dwh_customer360.dbo.dwh_fact_transaction AS t
    INNER JOIN dwh_customer360.dbo.dwh_dim_date AS d
        ON t.date_key = d.date_key
),
monthly_retention AS (
    SELECT
        current_month.activity_month,
        COUNT(DISTINCT current_month.client_key) AS active_customers,
        COUNT(DISTINCT next_month.client_key) AS retained_customers
    FROM monthly_activity AS current_month
    LEFT JOIN monthly_activity AS next_month
        ON current_month.client_key = next_month.client_key
        AND next_month.activity_month = DATEADD(MONTH, 1, current_month.activity_month)
    GROUP BY current_month.activity_month
)
SELECT
    activity_month,
    active_customers,
    retained_customers,
    CAST(
        retained_customers * 100.0 /
        NULLIF(active_customers, 0)
        AS DECIMAL(5,2)
    ) AS retention_rate_percentage
FROM monthly_retention
ORDER BY activity_month;
GO


--   20. Identify accounts with unusual transaction patterns (e.g. a sudden spike relative to the account's own history) and explain what additional data you'd want to confirm whether it's fraud?

WITH account_transactions AS (
    SELECT
        t.product_key,
        p.account_number,
        d.full_date AS transaction_date,
        ABS(t.amount) AS transaction_value,
        AVG(ABS(t.amount)) OVER (
            PARTITION BY t.product_key
        ) AS average_account_transaction
    FROM dwh_customer360.dbo.dwh_fact_transaction AS t
    INNER JOIN dwh_customer360.dbo.dwh_dim_product AS p
        ON t.product_key = p.product_key
    INNER JOIN dwh_customer360.dbo.dwh_dim_date AS d
        ON t.date_key = d.date_key
    WHERE p.account_number <> 'UNKNOWN'
)
SELECT
    account_number,
    transaction_date,
    transaction_value,
    CAST(average_account_transaction AS DECIMAL(18,2)) AS average_account_transaction,
    CAST(
        transaction_value / NULLIF(average_account_transaction, 0)
        AS DECIMAL(18,2)
    ) AS times_above_average
FROM account_transactions
WHERE transaction_value >= average_account_transaction * 3
ORDER BY times_above_average DESC;
GO

--   Additional data that would help assess possible fraud includes transaction timestamps,
--   merchant details, transaction location, device information, IP address, failed transaction
--   attempts, account login activity and confirmed fraud or chargeback records.
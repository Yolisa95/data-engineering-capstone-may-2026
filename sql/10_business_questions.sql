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

-- ------------------------------------------------------------
-- ANSWER
--
--   Eastern Cape has the largest customer base with 191 customers (12.87%).
--   It is followed by KwaZulu Natal with 187 (12.60%) and Mpumalanga with 176 (11.86%).
--   The remaining provinces are Western Cape 165 (11.12%), Gauteng 164 (11.05%),
--   Free State 164 (11.05%), North West 158 (10.65%), Northern Cape 142 (9.57%),
--   and Limpopo 137 (9.23%).
-- ------------------------------------------------------------

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

-- ------------------------------------------------------------
-- ANSWER
--
--   Under 25: 167 customers
--   25-34:     270 customers
--   35-44:     261 customers
--   45-54:     224 customers
--   55-64:     258 customers
--   65+:       304 customers

--   The 10-year bands provide simple life-stage groupings that are easy to compare.
--   The largest group is 65+ with 304 customers, while Under 25 is the smallest with 167.
-- ------------------------------------------------------------

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

-- ------------------------------------------------------------
-- ANSWER
--
--   Monthly signups fluctuate but are broadly flat rather than showing a sustained upward
--   or downward trend. Most complete months fall roughly between 28 and 49 signups.
--   Examples include 49 signups in April 2024, 47 in February 2025 and 39 in May 2025.
--   The first and last months in the two-year window should be interpreted carefully because
--   they can represent partial periods.
-- ------------------------------------------------------------

--   4. How many customer records look like data quality problems (e.g. missing contact details, duplicate identity)? Report the count and what you count as a "problem".

--   A problem is defined as a customer with missing email or mobile number, missing identity/demographic details, unknown gender, missing location, information, or a duplicate client number.

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


-- ------------------------------------------------------------
-- ANSWER
--
--   232 customers meet the data-quality problem definition used in this query.
--   A problem includes missing email/mobile/identity/demographic/location information,
--   gender recorded as unknown (U), or a duplicate client number.
-- ------------------------------------------------------------

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

-- ------------------------------------------------------------
-- ANSWER
--
--   Savings:       677 customers
--   Credit Card:   672 customers
--   Personal Loan: 647 customers
--   591 customers hold more than one product type based on products linked through
--   transaction activity.
-- ------------------------------------------------------------

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

-- ------------------------------------------------------------
-- ANSWER
--
--   Credit Card:   673 accounts, total balance 7,218,723.33, average balance 10,726.19
--   Personal Loan: 649 accounts, total balance 15,446,189.02, average balance 23,799.98
--   Savings:       678 accounts, total balance 26,100,944.34, average balance 38,496.97
--   Savings has both the highest total balance and the highest average balance.
-- ------------------------------------------------------------

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

-- ------------------------------------------------------------
-- ANSWER
--
--   382 customers hold a Savings account but no Credit Card based on products linked
--   through transaction activity. The second result set returns the detailed cross-sell
--   customer list with client number, name, email and mobile number.
-- ------------------------------------------------------------

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


-- ------------------------------------------------------------
-- ANSWER
--
--   There are 673 Credit Card accounts.
--   68 accounts are at or above 90% of their credit limit.
--   This represents 10.10% of Credit Card accounts.
-- ------------------------------------------------------------


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

-- ------------------------------------------------------------
-- ANSWER
--
--   The query returns monthly transaction value split by transaction type.
--   Transaction activity increases strongly through 2025, with particularly high activity
--   around July and August 2025. The extract does not show enough evidence of a repeating
--   year-on-year seasonal pattern, so the increase is better described as changing activity
--   volume rather than confirmed seasonality.
-- ------------------------------------------------------------

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

-- ------------------------------------------------------------
-- ANSWER
--
--   POS handles the most transactions with 4,122 transactions.
--   Online Banking has the highest net total transaction value at 6,011,468.17.
--   POS has a net total of -13,419,659.15 and the highest absolute transaction activity
--   at 16,553,061.05. The difference occurs because transaction counts measure frequency,
--   while total value is affected by transaction size and the positive/negative direction
--   of the transactions.
-- ------------------------------------------------------------

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

-- ------------------------------------------------------------
-- ANSWER
--
--   Active is defined as having at least one transaction within the last 90 days relative
--   to the latest transaction date in the extract.
--   Active customers:     20
--   Not active customers: 1,464
-- ------------------------------------------------------------

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


-- ------------------------------------------------------------
-- ANSWER
--
--   The top 20 customers by net transaction value in the last 12 months are:
--   1. CL01447 Nadia Pillay
--   2. CL00276 David Mabaso
--   3. CL00615 Sipho Abrahams
--   4. CL00479 Ayesha De Villiers
--   5. CL00554 Karabo De Villiers
--   6. CL00268 Kyle Petersen
--   7. CL00544 Mpho Petersen
--   8. CL00269 Ayesha Smith
--   9. CL00022 Ilse Nkosi
--   10. CL01271 Ilse Smith
--   11. CL01237 Grace Botha
--   12. CL01413 Ayesha Kruger
--   13. CL01395 Riaan Nkosi
--   14. CL00444 David De Villiers
--   15. CL01097 Marike Adams
--   16. CL00329 David Mahlangu
--   17. CL00314 Chane Mabaso
--   18. CL00093 Sam Dlamini
--   19. CL01213 Marike Naidoo
--   20. CL01221 Karabo Naidoo
--   The query uses the latest transaction date in the static extract as the reference date.
-- ------------------------------------------------------------

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

-- ------------------------------------------------------------
-- ANSWER
--
--   Complaint:           1.31 average interactions per customer
--   Feedback:            1.16
--   Fraud Report:        1.10
--   Product Application: 1.31
--   Query:                1.80
--   Query has the highest average number of interactions per customer.
-- ------------------------------------------------------------

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

-- ------------------------------------------------------------
-- ANSWER
--
--   Call is the most-used channel for Complaints with 195 interactions.
--   The leading channels for the other interaction types are:
--   Feedback - WhatsApp (107)
--   Fraud Report - WhatsApp (50)
--   Product Application - Email (193)
--   Query - Chat (434)
--   This shows that the preferred channel differs by interaction type.
-- ------------------------------------------------------------

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


-- ------------------------------------------------------------
-- ANSWER
--
--   WhatsApp: 74.58% (663 of 889)
--   Call:     74.77% (664 of 888)
--   Email:    76.02% (691 of 909)
--   Branch:   76.27% (688 of 902)
--   Chat:     77.17% (703 of 911)
--   WhatsApp has the lowest resolution rate. However, the rates are close and the channel
--   sample sizes are similar, so the small differences should not automatically be treated
--   as evidence that one channel performs materially worse than another.
-- ------------------------------------------------------------


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

-- ------------------------------------------------------------
-- ANSWER
--
--   Tier 1 - Low Value:       371 customers, total transaction value 1,869,940.36
--   Tier 2 - Medium Value:    371 customers, total transaction value 10,471,181.45
--   Tier 3 - High Value:      371 customers, total transaction value 17,559,136.36
--   Tier 4 - Very High Value: 371 customers, total transaction value 30,181,692.52
--   Quartiles were used so that customers are divided into four equally sized groups
--   based on total absolute transaction activity.
-- ------------------------------------------------------------

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

-- ------------------------------------------------------------
-- ANSWER
--
--   Lifecycle thresholds:
--   New: signed up within the last 90 days.
--   Active: last transaction within the last 90 days.
--   At risk: last transaction 91-180 days ago.
--   Dormant: last transaction more than 180 days ago or never transacted.
--   Results:
--   Active:  20 customers
--   At risk: 876 customers
--   Dormant: 588 customers
--   No customers fall into New using the latest activity date and the stated precedence.
--   These thresholds separate recent activity from increasing periods of inactivity.
-- ------------------------------------------------------------

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


-- ------------------------------------------------------------
-- ANSWER
--
--   0 interactions:   53 customers, average transaction value 45,658.87
--   1-2 interactions: 566 customers, average transaction value 40,692.07
--   3-5 interactions: 750 customers, average transaction value 40,507.23
--   6+ interactions:  115 customers, average transaction value 36,955.62
--   Average transaction value decreases as CRM interaction frequency increases in these
--   groups. This suggests a weak negative relationship in this extract, but it does not
--   establish that CRM interactions cause lower transaction value.
-- ------------------------------------------------------------


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

-- ------------------------------------------------------------
-- ANSWER
--
--   The query produces a month-by-month retention view using transaction activity.
--   Retention generally rises as the active customer base grows, reaching 71.13% in
--   June 2025 and 75.34% in July 2025.
--   Retention then falls sharply after August 2025 because transaction activity becomes
--   very sparse in the remaining months of the static extract. Those final months should
--   therefore be interpreted with caution.
-- ------------------------------------------------------------

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

-- ------------------------------------------------------------
-- ANSWER
--
--   12 transactions were identified at three or more times the account's own average.
--   The flagged accounts are:
--   AC000005, AC000486, AC000331, AC001308, AC001026, AC001368,
--   AC001544, AC001666, AC000418, AC001591, AC001806 and AC000684.
--   These are unusual transactions, not confirmed fraud.
--   Additional information such as exact timestamps, merchant details, transaction location,
--   device/IP information, authentication results, failed attempts, login activity,
--   chargebacks and confirmed fraud labels would be needed for a stronger fraud assessment.
-- ------------------------------------------------------------


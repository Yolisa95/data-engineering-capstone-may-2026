-----------------------------------------------------------
--   1. CREATE STAGING DATABASE
-----------------------------------------------------------
IF NOT EXISTS (
    SELECT 1
    FROM sys.databases
    WHERE name = 'stg_customer360'
)
BEGIN
    CREATE DATABASE stg_customer360;
END;


-----------------------------------------------------------
--   2. CREATE DATA WAREHOUSE DATABASE
-----------------------------------------------------------
IF NOT EXISTS (
    SELECT 1
    FROM sys.databases
    WHERE name = 'dwh_customer360'
)
BEGIN
    CREATE DATABASE dwh_customer360;
END;



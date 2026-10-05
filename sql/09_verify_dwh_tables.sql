-----------------------------------------------------------
--   VERIFY DWH DATE DIMENSION
-----------------------------------------------------------
SELECT *
FROM dwh_customer360.dbo.dwh_dim_date;
GO


-----------------------------------------------------------
--   VERIFY DWH CLIENT DIMENSION
-----------------------------------------------------------
SELECT *
FROM dwh_customer360.dbo.dwh_dim_client;
GO


-----------------------------------------------------------
--   VERIFY DWH PRODUCT DIMENSION
-----------------------------------------------------------
SELECT *
FROM dwh_customer360.dbo.dwh_dim_product;
GO


-----------------------------------------------------------
--   VERIFY DWH TRANSACTION FACT
-----------------------------------------------------------
SELECT *
FROM dwh_customer360.dbo.dwh_fact_transaction;
GO


-----------------------------------------------------------
--   VERIFY DWH CRM INTERACTION FACT
-----------------------------------------------------------
SELECT *
FROM dwh_customer360.dbo.dwh_fact_crm_interaction;
GO
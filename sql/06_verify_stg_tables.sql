-----------------------------------------------------------
--   VERIFY STAGING CLIENT DIMENSION
-----------------------------------------------------------
SELECT *
FROM stg_customer360.dbo.stg_dim_client;
GO


-----------------------------------------------------------
--   VERIFY STAGING PRODUCT DIMENSION
-----------------------------------------------------------
SELECT *
FROM stg_customer360.dbo.stg_dim_product;
GO


-----------------------------------------------------------
--   VERIFY STAGING TRANSACTION FACT
-----------------------------------------------------------
SELECT *
FROM stg_customer360.dbo.stg_fact_transaction;
GO


-----------------------------------------------------------
--   VERIFY STAGING CRM INTERACTION FACT
-----------------------------------------------------------
SELECT *
FROM stg_customer360.dbo.stg_fact_crm_interaction;
GO
# Customer 360 Data Engineering Project

## Overview

The **Customer 360 Data Engineering Project** is an end-to-end data engineering solution for a fictional retail bank. The project transforms a raw banking activity extract into a structured dimensional data warehouse for customer, product, transaction, and CRM analysis.

The project follows a **Medallion Architecture**, where data moves through **Bronze, Silver, and Gold layers**. This approach separates raw data ingestion, data preparation, and business-ready analytical data.

The source contains three main types of customer activity:

- Product Enrollment
- CRM Interaction
- Transaction

The solution was developed using **Microsoft SQL Server, SQL Server Integration Services (SSIS), SQL Server Management Studio (SSMS), Visual Studio/SSDT, SQL, and draw.io**.

---

## Architecture

The project uses a **Medallion Architecture** consisting of three layers:

### Bronze Layer — Raw / Landing

The Bronze layer stores the raw source data with minimal transformation.

**Source:**

`data/raw/activity_extract.csv`

**Landing table:**

`stg_customer360.dbo.stg_activity_extract`

The purpose of this layer is to preserve the original source data for profiling, validation, and troubleshooting.

### Silver Layer — Staging / Transformation

The Silver layer separates and prepares the raw data for the dimensional warehouse.

The staging tables are:

- `stg_dim_client`
- `stg_dim_product`
- `stg_fact_transaction`
- `stg_fact_crm_interaction`

The `event_type` field is used to separate **Product Enrollment**, **CRM Interaction**, and **Transaction** records.

The Silver layer performs preparation such as:

- Trimming whitespace
- Handling blank and NULL values
- Standardising values
- Converting data types
- Deduplicating customer records
- Deduplicating CRM interactions
- Preparing records for dimension and fact loading

### Gold Layer — Dimensional Data Warehouse

The Gold layer contains the final business-ready dimensional model.

**Dimensions:**

- `dim_client`
- `dim_date`
- `dim_product`

**Fact tables:**

- `fact_transaction`
- `fact_crm_interaction`

The Gold layer is used to answer the Customer 360 business questions and perform customer, product, transaction, CRM, and segmentation analysis.

### Architecture Flow

```text
activity_extract.csv
        |
        v
+----------------------------------+
| BRONZE                           |
| Raw / Landing                    |
|                                  |
| stg_activity_extract             |
+----------------------------------+
        |
        v
+----------------------------------+
| SILVER                           |
| Staging / Transformation         |
|                                  |
| stg_dim_client                   |
| stg_dim_product                  |
| stg_fact_transaction             |
| stg_fact_crm_interaction         |
+----------------------------------+
        |
        v
+----------------------------------+
| GOLD                             |
| Dimensional Data Warehouse       |
|                                  |
| dim_client                       |
| dim_date                         |
| dim_product                      |
| fact_transaction                 |
| fact_crm_interaction             |
+----------------------------------+
        |
        v
+----------------------------------+
| BUSINESS ANALYSIS                |
|                                  |
| Customer Analysis                |
| Product Analysis                 |
| Transaction Analysis             |
| CRM Analysis                     |
| Customer Segmentation            |
+----------------------------------+
```

---

## Dimensional Model

The Gold layer uses a **fact constellation / galaxy schema** because the model contains multiple fact tables that share common dimensions.

### `dim_client`

Contains one row per customer.

Main attributes include:

- Client number
- First name
- Last name
- Email
- Mobile number
- Date of birth
- Gender
- Province
- City
- Signup date

A surrogate `client_key` is used in the warehouse, while `client_number` is retained as the source business key.

The client dimension follows a **Type 1 Slowly Changing Dimension (SCD)** approach because the project focuses on the current customer view rather than maintaining historical versions of customer attributes.

### `dim_date`

Contains calendar attributes used for time-based analysis, including:

- Full date
- Day
- Month
- Month name
- Quarter
- Year
- Day of week

### `dim_product`

Contains account and product information, including:

- Account number
- Product type
- Account status
- Credit limit
- Loan amount
- Account balance

A surrogate `product_key` is used for warehouse relationships.

### `fact_transaction`

**Grain:** One row per transaction event.

Contains:

- Client key
- Product key
- Date key
- Transaction type
- Channel
- Amount

### `fact_crm_interaction`

**Grain:** One row per unique CRM interaction.

Contains:

- Client key
- Date key
- Channel
- Interaction type
- Resolved flag

Transactions and CRM interactions are stored in separate fact tables because they represent different business processes and have different grains.

---

## ETL Process

The ETL pipeline was developed using **SQL Server Integration Services (SSIS)**.

The solution contains four main packages:

```text
01_load_raw_activity_extract.dtsx
02_create_load_stg_tables.dtsx
03_create_load_dwh_tables.dtsx
04_master_package.dtsx
```

The master package controls the complete pipeline:

```text
01_load_raw_activity_extract.dtsx
              |
              v
        BRONZE LAYER
        Raw / Landing
              |
              v
02_create_load_stg_tables.dtsx
              |
              v
        SILVER LAYER
   Staging / Transformation
              |
              v
03_create_load_dwh_tables.dtsx
              |
              v
         GOLD LAYER
 Dimensional Data Warehouse
```

`04_master_package.dtsx` provides a single entry point for running the complete ETL process.

Dimensions are loaded before the fact tables so that the required surrogate keys are available when fact records are inserted.

---

## Data Quality

Source data profiling was completed before loading the dimensional model.

The source contains **21,500 activity records** across **1,484 distinct clients**.

| Event Type | Records |
|---|---:|
| Transaction | 15,000 |
| CRM Interaction | 4,500 |
| Product Enrollment | 2,000 |
| **Total** | **21,500** |

The main data quality findings included:

- Missing email addresses
- Missing mobile numbers
- Missing or unknown gender values
- Repeated customer information across activity records
- One exact duplicate CRM interaction
- Transaction accounts without corresponding Product Enrollment records
- Positive, negative, and zero transaction amounts

The ETL process preserves valid business activity where possible.

Customers are deduplicated using `client_number`. The exact duplicate CRM interaction is removed to prevent double counting. Transactions without a matching Product Enrollment record are retained rather than discarded and can be associated with an **Unknown Product** member.

Detailed data quality findings and handling decisions are documented in:

`docs/customer360_data_quality_writeup.docx`

---

## Business Analysis

The Gold layer is used to answer the Customer 360 business questions.

The analysis covers:

- Customer distribution by province
- Customer age distribution
- Customer signup trends
- Customer data quality
- Product holdings and cross-holding
- Account balances
- Cross-sell opportunities
- Credit Card utilisation
- Monthly transaction activity
- Transaction channel usage
- Active and inactive customers
- Top customers by transaction value
- CRM interaction activity
- Complaint channels
- Resolution rates
- Customer value segmentation
- Customer lifecycle segmentation
- CRM engagement compared with transaction value
- Month-over-month retention
- Unusual transaction patterns

The SQL queries include the corresponding results and interpretations as comments in the code.

The business analysis is available in:

`sql/10_business_questions.sql`

---

## Repository Structure

```text
data-engineering-capstone-may-2026/
│
├── data/
│   └── raw/
│       └── activity_extract.csv
│
├── docs/
│   ├── BusinessQuestions_and_Answers.docx
│   ├── customer360_data_quality_writeup.docx
│   ├── customer360_star_schema.jpg
│   ├── dictionary.md
│   ├── questions.md
│   └── scope.docx
│
├── sql/
│   ├── 01_create_databases.sql
│   ├── 02_create_landing_table.sql
│   ├── 03_data_profiling.sql
│   ├── 04_create_stg_tables.sql
│   ├── 05_load_stg_tables.sql
│   ├── 06_verify_stg_tables.sql
│   ├── 07_create_dwh_tables.sql
│   ├── 08_load_dwh_tables.sql
│   ├── 09_verify_dwh_tables.sql
│   └── 10_business_questions.sql
│
├── ssis/
│   ├── 01_load_raw_activity_extract.dtsx
│   ├── 02_create_load_stg_tables.dtsx
│   ├── 03_create_load_dwh_tables.dtsx
│   └── 04_master_package.dtsx
│
└── README.md
```

---

## How to Run the Project

### Prerequisites

The following tools are required:

- Microsoft SQL Server
- SQL Server Management Studio (SSMS)
- Visual Studio with SSIS/SSDT
- Git

### Execution

1. Clone the repository.

2. Confirm that the source file is available:

   `data/raw/activity_extract.csv`

3. Run:

   `sql/01_create_databases.sql`

4. Run:

   `sql/02_create_landing_table.sql`

5. Open the Customer 360 SSIS project in Visual Studio.

6. Confirm that the flat-file connection points to the correct `activity_extract.csv` location.

7. Confirm that the SQL Server connection managers point to the correct SQL Server instance.

8. Execute:

   `04_master_package.dtsx`

   This runs the **Bronze → Silver → Gold** pipeline.

9. Verify the Silver layer using:

   `sql/06_verify_stg_tables.sql`

10. Verify the Gold layer using:

    `sql/09_verify_dwh_tables.sql`

11. Run the business analysis:

    `sql/10_business_questions.sql`

---

## Technologies Used

| Technology | Purpose |
|---|---|
| SQL Server | Data storage and dimensional warehouse |
| SSMS | SQL development, profiling and validation |
| SSIS | ETL and pipeline orchestration |
| Visual Studio / SSDT | SSIS package development |
| SQL | Profiling, transformation, loading and analysis |
| draw.io | Dimensional model / ERD |
| Git & GitHub | Version control and project submission |

---

## Summary

The Customer 360 project implements a **Medallion Architecture** to transform raw retail banking activity into business-ready analytical data.

The **Bronze layer** preserves the raw source data, the **Silver layer** separates and prepares customer, product, transaction, and CRM data, and the **Gold layer** contains the final dimensional warehouse.

The final model uses shared dimensions and separate transaction and CRM fact tables with clearly defined grains. This provides a structured Customer 360 view for analysing customer demographics, product holdings, transaction behaviour, CRM engagement, and customer segmentation.

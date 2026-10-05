# Customer 360 Data Engineering Project

## Overview

The Customer 360 project is an end-to-end data engineering solution for a fictional retail bank. The project transforms a raw banking activity extract into a dimensional data warehouse that supports analysis across customers, products, transactions, and CRM interactions.

The solution was developed using **SQL Server, SSIS, SSMS, Visual Studio/SSDT, SQL, and draw.io**.

The source file contains three types of customer activity:

- Product Enrollment
- CRM Interaction
- Transaction

These events are loaded into a raw landing layer, separated into staging tables, cleaned and transformed, and then loaded into the dimensional data warehouse.

---

## Architecture

The project follows a layered architecture:

```text
activity_extract.csv
        |
        v
Raw / Landing Layer
stg_activity_extract
        |
        v
Staging Layer
stg_dim_client
stg_dim_product
stg_fact_transaction
stg_fact_crm_interaction
        |
        v
Cleaning & Transformation
        |
        v
Dimensional Data Warehouse
dim_client
dim_date
dim_product
fact_transaction
fact_crm_interaction
        |
        v
Business Analysis
```

### Raw / Landing Layer

The raw banking extract is first loaded into:

```text
stg_customer360.dbo.stg_activity_extract
```

The purpose of this layer is to preserve the source data with minimal transformation before cleaning and modelling.

### Staging Layer

The staging layer separates the source data into the main business entities and processes:

```text
stg_dim_client
stg_dim_product
stg_fact_transaction
stg_fact_crm_interaction
```

The source `event_type` is used to separate Product Enrollment, CRM Interaction, and Transaction records.

### Dimensional Data Warehouse

The final warehouse contains three dimensions and two fact tables:

**Dimensions**
- `dim_client`
- `dim_date`
- `dim_product`

**Facts**
- `fact_transaction`
- `fact_crm_interaction`

Transactions and CRM interactions are stored in separate fact tables because they represent different business processes and have different grains.

---

## Dimensional Model

The dimensional model is structured around the following tables:

### `dim_client`

Contains one row per customer and includes customer details such as:

- Client number
- Name
- Email
- Mobile number
- Date of birth
- Gender
- Province
- City
- Signup date

A surrogate `client_key` is used in the warehouse.

The client dimension follows a **Type 1 SCD approach**, as the project focuses on the current customer view rather than maintaining historical versions of customer attributes.

### `dim_date`

Provides standard calendar attributes including:

- Full date
- Day
- Month
- Month name
- Quarter
- Year
- Day of week

The transaction and CRM fact tables reference the date dimension using `date_key`.

### `dim_product`

Contains product and account information including:

- Account number
- Product type
- Account status
- Credit limit
- Loan amount
- Account balance

A surrogate `product_key` is used to link products to transaction activity.

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

The two fact tables share common dimensions where appropriate, providing a consistent Customer 360 view.

---

## ETL Process

The ETL process was developed using **SQL Server Integration Services (SSIS)**.

The solution contains the following packages:

```text
01_load_raw_activity_extract.dtsx
02_create_load_stg_tables.dtsx
03_create_load_dwh_tables.dtsx
04_master_package.dtsx
```

The master package controls the execution order:

```text
Load Raw Data
      |
      v
Create / Load Staging
      |
      v
Create / Load Data Warehouse
```

Dimensions are loaded before the fact tables so that the required surrogate keys are available when fact records are inserted.

The ETL process performs transformations such as:

- Trimming whitespace
- Handling blank and NULL values
- Converting data types
- Standardising text values
- Deduplicating customer records
- Deduplicating CRM interactions
- Performing dimension key lookups
- Handling unmatched product records

---

## Data Quality

The raw source contained **21,500 activity records** across **1,484 distinct clients**.

The source consisted of:

| Event Type | Records |
|---|---:|
| Transaction | 15,000 |
| CRM Interaction | 4,500 |
| Product Enrollment | 2,000 |
| **Total** | **21,500** |

Source profiling identified several data quality issues, including:

- Missing email addresses
- Missing mobile numbers
- Missing or unknown gender values
- Repeated customer information across activity rows
- One exact duplicate CRM interaction
- Transaction accounts without corresponding Product Enrollment records
- Positive, negative, and zero transaction amounts

The ETL process was designed to preserve valid business activity rather than remove records unnecessarily.

Customers are deduplicated using `client_number`, the duplicate CRM interaction is removed, blank values are handled appropriately, and unmatched transaction accounts can be linked to an **Unknown Product** member.

A detailed discussion of the findings and handling decisions is included in the project data quality document.

---

## Business Analysis

The dimensional warehouse is used to answer the supplied Customer 360 business questions.

The analysis covers:

- Customer distribution and demographics
- Customer signup trends
- Product holdings
- Cross-selling opportunities
- Account balances and credit utilisation
- Transaction trends and channel usage
- Active and inactive customers
- CRM interactions and resolution rates
- Customer value segmentation
- Customer lifecycle segmentation
- Customer retention
- Unusual transaction activity

The analysis is performed against the dimensional model rather than the raw or staging data.

---

## Repository Structure

```text
data-engineering-capstone-may-2026/
|
|-- data/
|   `-- raw/
|       `-- activity_extract.csv
|
|-- docs/
|   |-- BusinessQuestions_and_Answers.docx
|   |-- customer360_data_quality_writeup.docx
|   |-- customer360_star_schema.jpg
|   |-- dictionary.md
|   |-- questions.md
|   `-- scope.docx
|
|-- sql/
|   |-- 01_create_databases.sql
|   |-- 02_create_landing_table.sql
|   |-- 03_data_profiling.sql
|   |-- 04_create_stg_tables.sql
|   |-- 05_load_stg_tables.sql
|   |-- 06_verify_stg_tables.sql
|   |-- 07_create_dwh_tables.sql
|   |-- 08_load_dwh_tables.sql
|   |-- 09_verify_dwh_tables.sql
|   `-- 10_business_questions.sql
|
|-- ssis/
|   |-- 01_load_raw_activity_extract.dtsx
|   |-- 02_create_load_stg_tables.dtsx
|   |-- 03_create_load_dwh_tables.dtsx
|   `-- 04_master_package.dtsx
|
`-- README.md
```

---

## Running the Project

### Prerequisites

- Microsoft SQL Server
- SQL Server Management Studio (SSMS)
- Visual Studio with SSIS/SSDT
- `activity_extract.csv`

### Steps

1. Clone the repository.
2. Confirm that `activity_extract.csv` is available in `data/raw/`.
3. Run `01_create_databases.sql`.
4. Run `02_create_landing_table.sql`.
5. Open the Customer360 SSIS project in Visual Studio.
6. Update the flat-file and SQL Server connection managers if required.
7. Run `04_master_package.dtsx`.
8. Run `06_verify_stg_tables.sql` to verify the staging load.
9. Run `09_verify_dwh_tables.sql` to verify the dimensional warehouse.
10. Run `10_business_questions.sql` to perform the business analysis.

---

## Technologies Used

| Technology | Purpose |
|---|---|
| SQL Server | Data storage and dimensional warehouse |
| SSMS | SQL development and validation |
| SSIS | ETL and workflow orchestration |
| Visual Studio / SSDT | SSIS development |
| SQL | Profiling, transformation and analysis |
| draw.io | Dimensional model / ERD |
| Git & GitHub | Version control and project submission |

---

## Summary

The Customer 360 project demonstrates an end-to-end data engineering workflow from raw data ingestion to business analysis.

The solution separates raw, staging, and dimensional warehouse layers, cleans and standardises source data, and models transaction and CRM activity at clearly defined grains. The final warehouse provides a structured Customer 360 view that supports customer, product, transaction, and CRM analysis while accounting for the main data quality issues identified in the source.

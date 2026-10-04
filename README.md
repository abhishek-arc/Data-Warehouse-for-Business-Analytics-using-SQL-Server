# Sales Data Warehouse in SQL Server

A data warehouse built in SQL Server that combines sales data from two source systems (CRM and ERP), cleans it, and models it as a star schema for business analytics.

## Architecture

The warehouse uses the **Medallion architecture** with one schema per layer:

```
CSV files (CRM, ERP)
      │  BULK INSERT              bronze.load_bronze
      ▼
   BRONZE   raw data, exactly as in the source files            (tables)
      │  clean + standardise      silver.load_silver
      ▼
   SILVER   cleaned, typed and standardised data                (tables)
      │  integrate + model
      ▼
   GOLD     star schema: dim_customers, dim_products, fact_sales (views)
      │
      ▼
   Reports / business analysis
```

| Layer  | What it holds | How it is loaded |
|--------|---------------|------------------|
| Bronze | Raw copy of the 6 CSV files | Stored procedure, truncate + `BULK INSERT` |
| Silver | Cleaned data, same tables as bronze | Stored procedure, truncate + `INSERT ... SELECT` |
| Gold   | Star schema for reporting | Views on top of silver |

Both load procedures run inside a transaction. If any step fails, everything is rolled back and the error is raised.

## Source data

| System | File | Content |
|--------|------|---------|
| CRM | `cust_info.csv` | Customers |
| CRM | `prd_info.csv` | Products, including old versions |
| CRM | `sales_details.csv` | Sales order lines |
| ERP | `CUST_AZ12.csv` | Customer birthdate and gender |
| ERP | `LOC_A101.csv` | Customer country |
| ERP | `PX_CAT_G1V2.csv` | Product category and subcategory |

How the tables connect:

- `sales_details.sls_cust_id` → `cust_info.cst_id`
- `sales_details.sls_prd_key` → `prd_info.prd_key` (characters 7+ of `prd_key`)
- `prd_info.prd_key` (first 5 characters, `-` → `_`) → `PX_CAT_G1V2.id`
- `cust_info.cst_key` → `CUST_AZ12.cid` (after removing the `NAS` prefix)
- `cust_info.cst_key` → `LOC_A101.cid` (after removing `-`)

## Data cleaning (silver layer)

| Table | Problem | Fix |
|-------|---------|-----|
| crm_cust_info | Duplicate and missing customer ids | Keep the latest record per customer (`ROW_NUMBER`), drop NULL ids |
| crm_cust_info | Extra spaces in names | `TRIM` |
| crm_cust_info | Codes `S`, `M`, `F` | Single / Married, Female / Male, unknown → `n/a` |
| crm_prd_info | Category hidden inside product key | Split into `cat_id` and `prd_key` |
| crm_prd_info | Missing cost | Set to 0 |
| crm_prd_info | Wrong end dates | End date = day before the next version starts (`LEAD`) |
| crm_prd_info | Product line codes | Mountain / Road / Touring / Other Sales |
| crm_sales_details | Dates stored as integers, some invalid | Convert to `DATE`, invalid → NULL |
| crm_sales_details | Missing or negative price | Derive from sales / quantity, make positive |
| crm_sales_details | Sales ≠ quantity × price | Recalculate as quantity × price |
| erp_cust_az12 | `NAS` prefix on customer id | Removed |
| erp_cust_az12 | Birthdates in the future | Set to NULL |
| erp_cust_az12 | Gender written many ways | Female / Male / n/a |
| erp_loc_a101 | `-` in customer id | Removed |
| erp_loc_a101 | `DE`, `US`, `USA`, blanks | Germany, United States, n/a |

## Data model (gold layer)

```
 dim_customers                fact_sales                 dim_products
 ─────────────                ──────────                 ────────────
 customer_key  ◄────────────  customer_key               product_key
 customer_id                  product_key  ────────────► product_id
 customer_number              order_number               product_number
 first_name, last_name        order_date                 product_name
 country                      shipping_date              category, subcategory
 marital_status               due_date                   maintenance
 gender                       sales_amount               cost
 birthdate                    quantity                   product_line
 create_date                  price                      start_date
```

- `fact_sales` has one row per order line.
- `customer_key` and `product_key` are surrogate keys.
- Gender comes from the CRM. If the CRM value is unknown, the ERP value is used.
- `dim_products` holds only the current version of each product.

## Project structure

```
├── datasets/
│   ├── source_crm/                 cust_info, prd_info, sales_details
│   └── source_erp/                 CUST_AZ12, LOC_A101, PX_CAT_G1V2
├── scripts/
│   ├── init_database.sql           creates the database and schemas
│   ├── bronze/
│   │   ├── ddl_bronze.sql          bronze tables
│   │   └── load_bronze.sql         procedure bronze.load_bronze
│   ├── silver/
│   │   ├── ddl_silver.sql          silver tables
│   │   └── load_silver.sql         procedure silver.load_silver
│   └── gold/
│       └── ddl_gold.sql            star schema views
├── tests/
│   ├── quality_checks_silver.sql
│   └── quality_checks_gold.sql
└── analysis/
    └── business_analysis.sql       example business questions
```

## How to run

1. Install SQL Server (Express or Developer) and SSMS.
2. In `scripts/bronze/load_bronze.sql`, change the file paths to where the `datasets` folder is on your machine.
3. Run the scripts in this order:

   ```
   scripts/init_database.sql
   scripts/bronze/ddl_bronze.sql
   scripts/bronze/load_bronze.sql
   scripts/silver/ddl_silver.sql
   scripts/silver/load_silver.sql
   scripts/gold/ddl_gold.sql
   ```

4. Load the data:

   ```sql
   EXEC bronze.load_bronze;
   EXEC silver.load_silver;
   ```

5. Run `tests/quality_checks_silver.sql` and `tests/quality_checks_gold.sql`. The checks should return no rows.
6. Query the gold views, or run `analysis/business_analysis.sql`.

To refresh the data later, run only step 4. The gold views update automatically.

## Results

| | |
|---|---|
| Sales order lines | 60,398 |
| Orders | 27,659 |
| Customers | 18,484 |
| Current products | 295 |
| Total revenue | 29.36 M |

- Bikes bring in about 96% of revenue, while accessories and clothing sell in volume at low prices.
- The United States (31%) and Australia (31%) are the largest markets.
- 2013 was the strongest year, with about 16.3 M in revenue.

## Tools

SQL Server, SQL Server Management Studio (SSMS), T-SQL, Git

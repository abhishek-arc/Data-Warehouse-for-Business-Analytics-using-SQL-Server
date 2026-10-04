# Datasets

The raw data comes from two source systems. Each system exported its tables as CSV files (comma-separated, with a header row).

```
datasets/
├── source_crm/          Customer Relationship Management system
│   ├── cust_info.csv
│   ├── prd_info.csv
│   └── sales_details.csv
└── source_erp/          Enterprise Resource Planning system
    ├── CUST_AZ12.csv
    ├── LOC_A101.csv
    └── PX_CAT_G1V2.csv
```

| File | Rows | Loaded into |
|------|-----:|-------------|
| source_crm/cust_info.csv | 18,494 | bronze.crm_cust_info |
| source_crm/prd_info.csv | 397 | bronze.crm_prd_info |
| source_crm/sales_details.csv | 60,398 | bronze.crm_sales_details |
| source_erp/CUST_AZ12.csv | 18,484 | bronze.erp_cust_az12 |
| source_erp/LOC_A101.csv | 18,484 | bronze.erp_loc_a101 |
| source_erp/PX_CAT_G1V2.csv | 37 | bronze.erp_px_cat_g1v2 |

---

## CRM

### cust_info.csv — customers

| Column | Description | Example |
|--------|-------------|---------|
| cst_id | Customer id | 11000 |
| cst_key | Customer number, used to link to the ERP files | AW00011000 |
| cst_firstname | First name | Jon |
| cst_lastname | Last name | Yang |
| cst_marital_status | `M` = married, `S` = single | M |
| cst_gndr | `M` = male, `F` = female | M |
| cst_create_date | Date the customer was created | 2025-10-06 |

Data issues: duplicate and missing `cst_id` values, extra spaces in names, missing gender and marital status.

### prd_info.csv — products

| Column | Description | Example |
|--------|-------------|---------|
| prd_id | Product id | 210 |
| prd_key | Category code (first 5 characters) + product number | CO-RF-FR-R92B-58 |
| prd_nm | Product name | HL Road Frame - Black- 58 |
| prd_cost | Product cost | 12 |
| prd_line | `M` mountain, `R` road, `S` other sales, `T` touring | R |
| prd_start_dt | Date this version of the product started | 2003-07-01 |
| prd_end_dt | Date this version ended (empty for current version) | 2007-12-28 |

A product can appear more than once, once for each version (for example after a cost change).

Data issues: missing cost, product line codes with extra spaces, end dates before start dates.

### sales_details.csv — sales order lines

| Column | Description | Example |
|--------|-------------|---------|
| sls_ord_num | Order number | SO43697 |
| sls_prd_key | Product number (matches the end of `prd_key`) | BK-R93R-62 |
| sls_cust_id | Customer id (matches `cst_id`) | 21768 |
| sls_order_dt | Order date as an integer `YYYYMMDD` | 20101229 |
| sls_ship_dt | Shipping date as an integer `YYYYMMDD` | 20110105 |
| sls_due_dt | Due date as an integer `YYYYMMDD` | 20110110 |
| sls_sales | Sales amount for the line | 3578 |
| sls_quantity | Units ordered | 1 |
| sls_price | Price per unit | 3578 |

Data issues: invalid dates (`0` or wrong length), sales not equal to quantity × price, missing or negative prices.

---

## ERP

### CUST_AZ12.csv — customer details

| Column | Description | Example |
|--------|-------------|---------|
| CID | Customer number, sometimes with a `NAS` prefix | NASAW00011000 |
| BDATE | Birthdate | 1971-10-06 |
| GEN | Gender, written in different ways (`Male`, `M`, `F`, blank) | Male |

Data issues: `NAS` prefix on ids, birthdates in the future, inconsistent gender values.

### LOC_A101.csv — customer location

| Column | Description | Example |
|--------|-------------|---------|
| CID | Customer number with a hyphen | AW-00011000 |
| CNTRY | Country, written in different ways (`DE`, `US`, `USA`, blank) | Australia |

Data issues: hyphen in ids, country codes mixed with country names, blanks.

### PX_CAT_G1V2.csv — product categories

| Column | Description | Example |
|--------|-------------|---------|
| ID | Category id (matches the first 5 characters of `prd_key`, with `_` instead of `-`) | AC_BR |
| CAT | Category | Accessories |
| SUBCAT | Subcategory | Bike Racks |
| MAINTENANCE | Whether the product needs maintenance | Yes |

The category `CO_PE` used by some products is missing from this file.

---

## How the files connect

```
sales_details.sls_cust_id  ──►  cust_info.cst_id
sales_details.sls_prd_key  ──►  prd_info.prd_key            (characters 7 onwards)
prd_info.prd_key           ──►  PX_CAT_G1V2.ID              (first 5 characters, '-' → '_')
cust_info.cst_key          ──►  CUST_AZ12.CID               (after removing 'NAS')
cust_info.cst_key          ──►  LOC_A101.CID                (after removing '-')
```

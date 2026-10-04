# Naming Conventions

## General

- `snake_case`: lowercase words separated by underscores.
- English names only.
- No SQL reserved words as names.

## Schemas

One schema per layer: `bronze`, `silver`, `gold`.

## Tables and views

| Layer | Pattern | Example | Rule |
|-------|---------|---------|------|
| Bronze | `<source>_<table>` | `crm_cust_info` | Source system + original table name, not renamed |
| Silver | `<source>_<table>` | `erp_loc_a101` | Same names as bronze |
| Gold | `<type>_<entity>` | `dim_customers`, `fact_sales` | Business names. `dim_` = dimension, `fact_` = fact |

## Columns

| Kind | Pattern | Example |
|------|---------|---------|
| Bronze / silver columns | Same as the source | `cst_firstname`, `sls_order_dt` |
| Gold columns | Clear business names | `first_name`, `order_date` |
| Surrogate keys | `<entity>_key` | `customer_key`, `product_key` |
| Technical columns added by the warehouse | `dwh_<name>` | `dwh_create_date` |

## Stored procedures

| Pattern | Example |
|---------|---------|
| `<layer>.load_<layer>` | `bronze.load_bronze`, `silver.load_silver` |

## Script files

Scripts are numbered in the order they should be run:

```
00_init_database.sql
01_ddl_bronze.sql   02_load_bronze.sql
03_ddl_silver.sql   04_load_silver.sql
05_ddl_gold.sql
```

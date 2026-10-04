/*
    Quality checks for the silver layer. Run after EXEC silver.load_silver.
    Every query should return NO rows, unless the comment says otherwise.
*/

USE SalesDataWarehouse;
GO

-- crm_cust_info: customer id is unique and not NULL
SELECT cst_id, COUNT(*) AS cnt
FROM silver.crm_cust_info
GROUP BY cst_id
HAVING COUNT(*) > 1 OR cst_id IS NULL;

-- crm_cust_info: no leading or trailing spaces in names
SELECT cst_firstname, cst_lastname
FROM silver.crm_cust_info
WHERE LEN(cst_firstname) <> LEN(TRIM(cst_firstname))
   OR DATALENGTH(cst_lastname) <> DATALENGTH(TRIM(cst_lastname));

-- crm_cust_info: only standard values (expect: Single, Married, n/a / Female, Male, n/a)
SELECT DISTINCT cst_marital_status, cst_gndr FROM silver.crm_cust_info;

-- crm_prd_info: product id is unique and not NULL
SELECT prd_id, COUNT(*) AS cnt
FROM silver.crm_prd_info
GROUP BY prd_id
HAVING COUNT(*) > 1 OR prd_id IS NULL;

-- crm_prd_info: cost is not NULL or negative
SELECT * FROM silver.crm_prd_info
WHERE prd_cost IS NULL OR prd_cost < 0;

-- crm_prd_info: end date is not before start date
SELECT * FROM silver.crm_prd_info
WHERE prd_end_dt < prd_start_dt;

-- crm_sales_details: order date is not after ship or due date
SELECT * FROM silver.crm_sales_details
WHERE sls_order_dt > sls_ship_dt OR sls_order_dt > sls_due_dt;

-- crm_sales_details: sales = quantity * price, all positive
SELECT * FROM silver.crm_sales_details
WHERE sls_sales IS NULL OR sls_quantity IS NULL OR sls_price IS NULL
   OR sls_sales <= 0 OR sls_quantity <= 0 OR sls_price <= 0
   OR sls_sales <> sls_quantity * sls_price;

-- erp_cust_az12: no future birthdates
SELECT * FROM silver.erp_cust_az12
WHERE bdate > GETDATE();

-- erp_cust_az12 / erp_loc_a101: only standard values (inspect the list)
SELECT DISTINCT gen   FROM silver.erp_cust_az12;
SELECT DISTINCT cntry FROM silver.erp_loc_a101 ORDER BY cntry;

-- ERP customers that do not match a CRM customer
SELECT cid FROM silver.erp_cust_az12
WHERE cid NOT IN (SELECT cst_key FROM silver.crm_cust_info);

SELECT cid FROM silver.erp_loc_a101
WHERE cid NOT IN (SELECT cst_key FROM silver.crm_cust_info);

-- product categories that do not exist in ERP
-- (returns CO_PE: this category is missing from the ERP source file, so its
--  7 products show an empty category in gold.dim_products. Known source gap.)
SELECT DISTINCT cat_id FROM silver.crm_prd_info
WHERE cat_id NOT IN (SELECT id FROM silver.erp_px_cat_g1v2);

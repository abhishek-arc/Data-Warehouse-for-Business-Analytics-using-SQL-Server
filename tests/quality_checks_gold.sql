/*
    Quality checks for the gold layer. Every query should return NO rows.
*/

USE SalesDataWarehouse;
GO

-- surrogate keys are unique
SELECT customer_key, COUNT(*) AS cnt
FROM gold.dim_customers
GROUP BY customer_key
HAVING COUNT(*) > 1;

SELECT product_key, COUNT(*) AS cnt
FROM gold.dim_products
GROUP BY product_key
HAVING COUNT(*) > 1;

-- natural keys used by the fact view are unique (otherwise joins duplicate sales)
SELECT product_number, COUNT(*) AS cnt
FROM gold.dim_products
GROUP BY product_number
HAVING COUNT(*) > 1;

-- every sale links to a customer and a product
SELECT *
FROM gold.fact_sales
WHERE customer_key IS NULL OR product_key IS NULL;

-- no sales lost or duplicated between silver and gold
SELECT
    (SELECT COUNT(*) FROM silver.crm_sales_details) AS silver_rows,
    (SELECT COUNT(*) FROM gold.fact_sales)          AS gold_rows
WHERE (SELECT COUNT(*) FROM silver.crm_sales_details) <> (SELECT COUNT(*) FROM gold.fact_sales);

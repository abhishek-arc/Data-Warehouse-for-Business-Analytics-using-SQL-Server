/*
    Example business questions answered from the gold star schema.
*/

USE SalesDataWarehouse;
GO

-- Overall numbers
SELECT
    SUM(sales_amount)            AS total_revenue,
    SUM(quantity)                AS items_sold,
    COUNT(DISTINCT order_number) AS total_orders,
    COUNT(DISTINCT customer_key) AS customers_who_ordered
FROM gold.fact_sales;

-- Revenue by category, with share of total
SELECT
    p.category,
    SUM(f.sales_amount) AS revenue,
    CAST(100.0 * SUM(f.sales_amount) / SUM(SUM(f.sales_amount)) OVER () AS DECIMAL(5, 2)) AS pct_of_total
FROM gold.fact_sales AS f
JOIN gold.dim_products AS p ON f.product_key = p.product_key
GROUP BY p.category
ORDER BY revenue DESC;

-- Revenue and customers by country
SELECT
    c.country,
    SUM(f.sales_amount)            AS revenue,
    COUNT(DISTINCT f.customer_key) AS customers
FROM gold.fact_sales AS f
JOIN gold.dim_customers AS c ON f.customer_key = c.customer_key
GROUP BY c.country
ORDER BY revenue DESC;

-- Top 10 products by revenue
SELECT TOP 10
    p.product_name,
    SUM(f.sales_amount) AS revenue
FROM gold.fact_sales AS f
JOIN gold.dim_products AS p ON f.product_key = p.product_key
GROUP BY p.product_name
ORDER BY revenue DESC;

-- Revenue per year
SELECT
    YEAR(order_date)  AS order_year,
    SUM(sales_amount) AS revenue,
    COUNT(DISTINCT customer_key) AS customers
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY YEAR(order_date)
ORDER BY order_year;

-- Monthly revenue with running total and change from previous month
WITH monthly AS (
    SELECT
        DATEFROMPARTS(YEAR(order_date), MONTH(order_date), 1) AS order_month,
        SUM(sales_amount) AS revenue
    FROM gold.fact_sales
    WHERE order_date IS NOT NULL
    GROUP BY DATEFROMPARTS(YEAR(order_date), MONTH(order_date), 1)
)
SELECT
    order_month,
    revenue,
    SUM(revenue) OVER (ORDER BY order_month)     AS running_total,
    revenue - LAG(revenue) OVER (ORDER BY order_month) AS change_from_last_month
FROM monthly
ORDER BY order_month;

-- Customer segments by total spend
WITH spend AS (
    SELECT customer_key, SUM(sales_amount) AS total_spend
    FROM gold.fact_sales
    GROUP BY customer_key
)
SELECT
    CASE
        WHEN total_spend >= 5000 THEN 'VIP'
        WHEN total_spend >= 1000 THEN 'Regular'
        ELSE 'Low spend'
    END AS segment,
    COUNT(*)         AS customers,
    SUM(total_spend) AS revenue
FROM spend
GROUP BY
    CASE
        WHEN total_spend >= 5000 THEN 'VIP'
        WHEN total_spend >= 1000 THEN 'Regular'
        ELSE 'Low spend'
    END
ORDER BY revenue DESC;

-- Best product in each category
WITH product_revenue AS (
    SELECT
        p.category,
        p.product_name,
        SUM(f.sales_amount) AS revenue,
        RANK() OVER (PARTITION BY p.category ORDER BY SUM(f.sales_amount) DESC) AS rnk
    FROM gold.fact_sales AS f
    JOIN gold.dim_products AS p ON f.product_key = p.product_key
    GROUP BY p.category, p.product_name
)
SELECT category, product_name, revenue
FROM product_revenue
WHERE rnk = 1;

/*
    Load Silver: bronze -> silver (full load).
    Cleans, standardises and fixes the raw data. Every table is emptied and reloaded.
    Everything runs in one transaction: if any step fails, nothing is changed.

    Run:  EXEC silver.load_silver;
*/

USE SalesDataWarehouse;
GO

CREATE OR ALTER PROCEDURE silver.load_silver AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        /* ---------------------------------------------------------------
           crm_cust_info
           - remove customers with no id
           - remove duplicates: keep the latest record of each customer
           - trim spaces from names
           - codes to readable values (S/M -> Single/Married, F/M -> Female/Male)
        --------------------------------------------------------------- */
        TRUNCATE TABLE silver.crm_cust_info;

        INSERT INTO silver.crm_cust_info
            (cst_id, cst_key, cst_firstname, cst_lastname, cst_marital_status, cst_gndr, cst_create_date)
        SELECT
            cst_id,
            cst_key,
            TRIM(cst_firstname),
            TRIM(cst_lastname),
            CASE UPPER(TRIM(cst_marital_status))
                WHEN 'S' THEN 'Single'
                WHEN 'M' THEN 'Married'
                ELSE 'n/a'
            END,
            CASE UPPER(TRIM(cst_gndr))
                WHEN 'F' THEN 'Female'
                WHEN 'M' THEN 'Male'
                ELSE 'n/a'
            END,
            cst_create_date
        FROM (
            SELECT *,
                   ROW_NUMBER() OVER (PARTITION BY cst_id ORDER BY cst_create_date DESC) AS rn
            FROM bronze.crm_cust_info
            WHERE cst_id IS NOT NULL
        ) AS t
        WHERE rn = 1;

        /* ---------------------------------------------------------------
           crm_prd_info
           - split prd_key 'CO-RF-FR-R92B-58' into
               cat_id  = 'CO_RF'      (matches erp_px_cat_g1v2.id)
               prd_key = 'FR-R92B-58' (matches crm_sales_details.sls_prd_key)
           - missing cost -> 0
           - product line codes to readable values
           - end date = one day before the next version of the product starts
             (source end dates are unreliable; the current version gets NULL)
        --------------------------------------------------------------- */
        TRUNCATE TABLE silver.crm_prd_info;

        INSERT INTO silver.crm_prd_info
            (prd_id, cat_id, prd_key, prd_nm, prd_cost, prd_line, prd_start_dt, prd_end_dt)
        SELECT
            prd_id,
            REPLACE(LEFT(prd_key, 5), '-', '_'),
            SUBSTRING(prd_key, 7, LEN(prd_key)),
            TRIM(prd_nm),
            ISNULL(prd_cost, 0),
            CASE UPPER(TRIM(prd_line))
                WHEN 'M' THEN 'Mountain'
                WHEN 'R' THEN 'Road'
                WHEN 'S' THEN 'Other Sales'
                WHEN 'T' THEN 'Touring'
                ELSE 'n/a'
            END,
            prd_start_dt,
            DATEADD(DAY, -1, LEAD(prd_start_dt) OVER (PARTITION BY prd_key ORDER BY prd_start_dt))
        FROM bronze.crm_prd_info;

        /* ---------------------------------------------------------------
           crm_sales_details
           - integer dates (20101229) -> DATE; invalid ones (0, wrong length) -> NULL
           - price: missing or 0 -> sales / quantity, negative -> positive
           - sales: missing, negative or not equal to quantity * price -> quantity * price
        --------------------------------------------------------------- */
        TRUNCATE TABLE silver.crm_sales_details;

        WITH fixed_price AS (
            SELECT *,
                   CASE
                       WHEN sls_price IS NULL OR sls_price = 0
                           THEN ABS(sls_sales) / NULLIF(sls_quantity, 0)
                       ELSE ABS(sls_price)
                   END AS price
            FROM bronze.crm_sales_details
        )
        INSERT INTO silver.crm_sales_details
            (sls_ord_num, sls_prd_key, sls_cust_id, sls_order_dt, sls_ship_dt, sls_due_dt,
             sls_sales, sls_quantity, sls_price)
        SELECT
            sls_ord_num,
            sls_prd_key,
            sls_cust_id,
            CASE WHEN LEN(sls_order_dt) = 8 THEN TRY_CONVERT(DATE, CAST(sls_order_dt AS CHAR(8))) END,
            CASE WHEN LEN(sls_ship_dt)  = 8 THEN TRY_CONVERT(DATE, CAST(sls_ship_dt  AS CHAR(8))) END,
            CASE WHEN LEN(sls_due_dt)   = 8 THEN TRY_CONVERT(DATE, CAST(sls_due_dt   AS CHAR(8))) END,
            CASE
                WHEN sls_sales IS NULL OR sls_sales <= 0 OR sls_sales <> sls_quantity * price
                    THEN sls_quantity * price
                ELSE sls_sales
            END,
            sls_quantity,
            price
        FROM fixed_price;

        /* ---------------------------------------------------------------
           erp_cust_az12
           - remove the 'NAS' prefix so cid matches crm_cust_info.cst_key
           - birthdates in the future -> NULL
           - gender values to Female / Male / n/a
        --------------------------------------------------------------- */
        TRUNCATE TABLE silver.erp_cust_az12;

        INSERT INTO silver.erp_cust_az12 (cid, bdate, gen)
        SELECT
            CASE WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LEN(cid)) ELSE cid END,
            CASE WHEN bdate > GETDATE() THEN NULL ELSE bdate END,
            CASE
                WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE') THEN 'Female'
                WHEN UPPER(TRIM(gen)) IN ('M', 'MALE')   THEN 'Male'
                ELSE 'n/a'
            END
        FROM bronze.erp_cust_az12;

        /* ---------------------------------------------------------------
           erp_loc_a101
           - remove '-' so cid matches crm_cust_info.cst_key (AW-00011000 -> AW00011000)
           - country codes to full names, blanks -> n/a
        --------------------------------------------------------------- */
        TRUNCATE TABLE silver.erp_loc_a101;

        INSERT INTO silver.erp_loc_a101 (cid, cntry)
        SELECT
            REPLACE(cid, '-', ''),
            CASE
                WHEN TRIM(cntry) = 'DE'           THEN 'Germany'
                WHEN TRIM(cntry) IN ('US', 'USA') THEN 'United States'
                WHEN TRIM(cntry) = '' OR cntry IS NULL THEN 'n/a'
                ELSE TRIM(cntry)
            END
        FROM bronze.erp_loc_a101;

        /* ---------------------------------------------------------------
           erp_px_cat_g1v2
           - already clean, only trim spaces
        --------------------------------------------------------------- */
        TRUNCATE TABLE silver.erp_px_cat_g1v2;

        INSERT INTO silver.erp_px_cat_g1v2 (id, cat, subcat, maintenance)
        SELECT TRIM(id), TRIM(cat), TRIM(subcat), TRIM(maintenance)
        FROM bronze.erp_px_cat_g1v2;

        COMMIT;
        PRINT 'Silver layer loaded.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        PRINT 'Silver load failed. No tables were changed.';
        THROW;
    END CATCH
END;
GO

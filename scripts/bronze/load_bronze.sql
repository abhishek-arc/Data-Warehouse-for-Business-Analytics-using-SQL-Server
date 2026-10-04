/*
    Load Bronze: CSV files -> bronze tables (full load).
    Every table is emptied and reloaded, so the procedure can be run any number of times.
    Everything runs in one transaction: if any file fails, nothing is changed.

    NOTE: change the file paths below to where the datasets folder is on your machine.
          The SQL Server service account must be able to read that folder.

    Run:  EXEC bronze.load_bronze;
*/

USE SalesDataWarehouse;
GO

CREATE OR ALTER PROCEDURE bronze.load_bronze AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- CRM
        TRUNCATE TABLE bronze.crm_cust_info;
        BULK INSERT bronze.crm_cust_info
        FROM 'A:\INTERNSHIP\sde\sql data warehouse (claude)\datasets\source_crm\cust_info.csv'
        WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', TABLOCK);

        TRUNCATE TABLE bronze.crm_prd_info;
        BULK INSERT bronze.crm_prd_info
        FROM 'A:\INTERNSHIP\sde\sql data warehouse (claude)\datasets\source_crm\prd_info.csv'
        WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', TABLOCK);

        TRUNCATE TABLE bronze.crm_sales_details;
        BULK INSERT bronze.crm_sales_details
        FROM 'A:\INTERNSHIP\sde\sql data warehouse (claude)\datasets\source_crm\sales_details.csv'
        WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', TABLOCK);

        -- ERP
        TRUNCATE TABLE bronze.erp_cust_az12;
        BULK INSERT bronze.erp_cust_az12
        FROM 'A:\INTERNSHIP\sde\sql data warehouse (claude)\datasets\source_erp\CUST_AZ12.csv'
        WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', TABLOCK);

        TRUNCATE TABLE bronze.erp_loc_a101;
        BULK INSERT bronze.erp_loc_a101
        FROM 'A:\INTERNSHIP\sde\sql data warehouse (claude)\datasets\source_erp\LOC_A101.csv'
        WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', TABLOCK);

        TRUNCATE TABLE bronze.erp_px_cat_g1v2;
        BULK INSERT bronze.erp_px_cat_g1v2
        FROM 'A:\INTERNSHIP\sde\sql data warehouse (claude)\datasets\source_erp\PX_CAT_G1V2.csv'
        WITH (FIRSTROW = 2, FIELDTERMINATOR = ',', TABLOCK);

        COMMIT;
        PRINT 'Bronze layer loaded.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        PRINT 'Bronze load failed. No tables were changed.';
        THROW;
    END CATCH
END;
GO

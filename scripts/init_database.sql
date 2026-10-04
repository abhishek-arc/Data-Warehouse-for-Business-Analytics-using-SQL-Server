/*
    Create the data warehouse database and one schema per layer.
    bronze : raw data, loaded as-is from the CSV files
    silver : cleaned and standardised data
    gold   : business-ready star schema (views)
*/

USE master;
GO

CREATE DATABASE SalesDataWarehouse;
GO

USE SalesDataWarehouse;
GO

CREATE SCHEMA bronze;
GO
CREATE SCHEMA silver;
GO
CREATE SCHEMA gold;
GO

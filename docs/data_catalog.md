# Data Catalog — Gold Layer

The gold layer is the business-ready layer. It is a star schema made of views, built on top of the silver tables.

```
               gold.dim_customers
                       │
                       │ customer_key
                       ▼
              ┌─────────────────┐
              │ gold.fact_sales │
              └─────────────────┘
                       ▲
                       │ product_key
                       │
                gold.dim_products
```

---

## gold.dim_customers

One row per customer. Combines CRM customer data with birthdate, gender and country from the ERP.

| Column | Type | Description |
|--------|------|-------------|
| customer_key | INT | Surrogate key of the dimension |
| customer_id | INT | Customer id from the CRM |
| customer_number | NVARCHAR(50) | Customer number, e.g. `AW00011000` |
| first_name | NVARCHAR(50) | First name |
| last_name | NVARCHAR(50) | Last name |
| country | NVARCHAR(50) | Country, e.g. `Australia` (`n/a` if unknown) |
| marital_status | NVARCHAR(50) | `Married`, `Single` or `n/a` |
| gender | NVARCHAR(50) | `Male`, `Female` or `n/a`. CRM value first, ERP value if the CRM value is unknown |
| birthdate | DATE | Date of birth |
| create_date | DATE | Date the customer was created in the CRM |

## gold.dim_products

One row per product, current version only. Combines CRM product data with category data from the ERP.

| Column | Type | Description |
|--------|------|-------------|
| product_key | INT | Surrogate key of the dimension |
| product_id | INT | Product id from the CRM |
| product_number | NVARCHAR(50) | Product number, e.g. `FR-R92B-58` |
| product_name | NVARCHAR(50) | Product name |
| category_id | NVARCHAR(50) | Category id, e.g. `CO_RF` |
| category | NVARCHAR(50) | Category, e.g. `Bikes`, `Components` |
| subcategory | NVARCHAR(50) | Subcategory, e.g. `Road Frames` |
| maintenance | NVARCHAR(50) | `Yes` / `No` |
| cost | INT | Product cost |
| product_line | NVARCHAR(50) | `Mountain`, `Road`, `Touring`, `Other Sales` or `n/a` |
| start_date | DATE | Date this product version became available |

## gold.fact_sales

One row per sales order line (order number + product).

| Column | Type | Description |
|--------|------|-------------|
| order_number | NVARCHAR(50) | Sales order number, e.g. `SO54496` |
| product_key | INT | Links to `gold.dim_products` |
| customer_key | INT | Links to `gold.dim_customers` |
| order_date | DATE | Date the order was placed |
| shipping_date | DATE | Date the order was shipped |
| due_date | DATE | Date payment was due |
| sales_amount | INT | Line total (quantity × price) |
| quantity | INT | Units ordered |
| price | INT | Price per unit |

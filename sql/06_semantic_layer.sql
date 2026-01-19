-- ============================================================================
-- SEMANTIC LAYER - Snowflake Semantic Views
-- ============================================================================
-- This script creates native Snowflake Semantic Views for AI consumption.
-- Semantic Views provide:
--   - Logical table definitions with relationships
--   - Dimensions and metrics for Cortex Analyst
--   - Business-friendly names and descriptions
--   - Natural language query capabilities
--
-- Reference: https://docs.snowflake.com/en/user-guide/views-semantic/sql
-- ============================================================================

USE ROLE DATA_ADMIN;
USE DATABASE SEM_DEV;
USE WAREHOUSE ANALYTICS_WH;

-- ─────────────────────────────────────────────────────────────────────────────
-- SCHEMA SETUP
-- ─────────────────────────────────────────────────────────────────────────────

CREATE SCHEMA IF NOT EXISTS SEM_DEV.SEM_SALES
    COMMENT = 'Semantic layer for sales analytics - AI-safe views for Cortex Analyst';

CREATE SCHEMA IF NOT EXISTS SEM_DEV.SEM_CUSTOMER
    COMMENT = 'Semantic layer for customer analytics - RFM scoring and segmentation';

CREATE SCHEMA IF NOT EXISTS SEM_DEV.SEM_PRODUCT
    COMMENT = 'Semantic layer for product analytics - inventory and performance';

-- ─────────────────────────────────────────────────────────────────────────────
-- SEMANTIC VIEW: Sales Analytics
-- ─────────────────────────────────────────────────────────────────────────────
-- This semantic view combines orders, line items, customers, and products
-- for comprehensive sales analysis with Cortex Analyst.

CREATE OR REPLACE SEMANTIC VIEW SEM_DEV.SEM_SALES.SALES_ANALYTICS

  COMMENT = 'Sales analytics semantic view for Cortex Analyst. Combines orders, line items, customers, and products for comprehensive revenue analysis.'

  TABLES (
    -- Orders table
    orders AS CURATED_DEV.CURATED_FACTS.FACT_ORDERS
      PRIMARY KEY (ORDER_KEY)
      WITH SYNONYMS = ('sales orders', 'customer orders', 'purchases')
      COMMENT = 'Order header information including status and priority',
    
    -- Line items table  
    line_items AS CURATED_DEV.CURATED_FACTS.FACT_LINEITEM
      PRIMARY KEY (ORDER_KEY, LINE_NUMBER)
      WITH SYNONYMS = ('order lines', 'order items', 'order details')
      COMMENT = 'Individual line items within orders with pricing and delivery info',
    
    -- Customers table
    customers AS CURATED_DEV.CURATED_DIMENSIONS.DIM_CUSTOMER
      PRIMARY KEY (CUSTOMER_KEY)
      WITH SYNONYMS = ('buyers', 'accounts', 'clients')
      COMMENT = 'Customer dimension with segmentation and tier information',
    
    -- Parts/Products table
    parts AS CURATED_DEV.CURATED_DIMENSIONS.DIM_PART
      PRIMARY KEY (PART_KEY)
      WITH SYNONYMS = ('products', 'items', 'inventory')
      COMMENT = 'Product catalog with pricing and categorization',
    
    -- Suppliers table
    suppliers AS CURATED_DEV.CURATED_DIMENSIONS.DIM_SUPPLIER
      PRIMARY KEY (SUPPLIER_KEY)
      WITH SYNONYMS = ('vendors', 'providers')
      COMMENT = 'Supplier information with performance tiers',
    
    -- Geography table
    geography AS CURATED_DEV.CURATED_DIMENSIONS.DIM_GEOGRAPHY
      PRIMARY KEY (NATION_KEY)
      WITH SYNONYMS = ('regions', 'locations', 'countries')
      COMMENT = 'Geographic hierarchy for regional analysis',
    
    -- Date table
    dates AS CURATED_DEV.CURATED_DIMENSIONS.DIM_DATE
      PRIMARY KEY (DATE_KEY)
      WITH SYNONYMS = ('calendar', 'time periods')
      COMMENT = 'Date dimension for time-based analysis'
  )

  RELATIONSHIPS (
    -- Orders to Customers
    orders_to_customers AS
      orders (CUSTOMER_KEY) REFERENCES customers
      COMMENT = 'Each order belongs to one customer',
    
    -- Line Items to Orders
    line_items_to_orders AS
      line_items (ORDER_KEY) REFERENCES orders
      COMMENT = 'Each line item belongs to one order',
    
    -- Line Items to Parts
    line_items_to_parts AS
      line_items (PART_KEY) REFERENCES parts
      COMMENT = 'Each line item references one product',
    
    -- Line Items to Suppliers
    line_items_to_suppliers AS
      line_items (SUPPLIER_KEY) REFERENCES suppliers
      COMMENT = 'Each line item is fulfilled by one supplier',
    
    -- Customers to Geography
    customers_to_geography AS
      customers (NATION_KEY) REFERENCES geography
      COMMENT = 'Each customer belongs to one nation/region',
    
    -- Orders to Dates
    orders_to_dates AS
      orders (ORDER_DATE_KEY) REFERENCES dates
      COMMENT = 'Each order has an order date'
  )

  FACTS (
    -- Revenue facts
    line_items.revenue AS EXTENDED_PRICE
      WITH SYNONYMS = ('sales', 'gross revenue', 'total price')
      COMMENT = 'Extended price before discounts',
    
    line_items.net_revenue AS DISCOUNTED_PRICE
      WITH SYNONYMS = ('net sales', 'discounted revenue')
      COMMENT = 'Price after discount applied',
    
    line_items.discount_amount AS DISCOUNT_AMOUNT
      WITH SYNONYMS = ('discount value', 'savings')
      COMMENT = 'Dollar amount of discount',
    
    line_items.tax_amount AS TAX_AMOUNT
      COMMENT = 'Tax amount on line item',
    
    -- Quantity facts
    line_items.quantity AS QUANTITY
      WITH SYNONYMS = ('units', 'items sold', 'volume')
      COMMENT = 'Quantity ordered',
    
    -- Delivery facts
    line_items.delivery_days AS DELIVERY_DAYS
      WITH SYNONYMS = ('lead time', 'shipping time', 'transit days')
      COMMENT = 'Days between order and delivery',
    
    -- Order value
    orders.order_total AS TOTAL_PRICE
      WITH SYNONYMS = ('order value', 'order amount')
      COMMENT = 'Total order value'
  )

  DIMENSIONS (
    -- Time dimensions
    dates.year AS YEAR
      WITH SYNONYMS = ('fiscal year', 'calendar year')
      COMMENT = 'Year of the order',
    
    dates.quarter AS QUARTER
      WITH SYNONYMS = ('fiscal quarter', 'Q1/Q2/Q3/Q4')
      COMMENT = 'Quarter of the order (1-4)',
    
    dates.month AS MONTH
      COMMENT = 'Month number (1-12)',
    
    dates.month_name AS MONTH_NAME
      COMMENT = 'Month name (January, February, etc.)',
    
    dates.full_date AS ORDER_DATE
      WITH SYNONYMS = ('sale date', 'purchase date', 'transaction date')
      COMMENT = 'Date when the order was placed',
    
    -- Geographic dimensions
    geography.region_name AS REGION
      WITH SYNONYMS = ('area', 'territory', 'zone')
      COMMENT = 'Geographic region (AMERICA, EUROPE, ASIA, etc.)',
    
    geography.nation_name AS NATION
      WITH SYNONYMS = ('country')
      COMMENT = 'Country name',
    
    -- Customer dimensions
    customers.market_segment AS MARKET_SEGMENT
      WITH SYNONYMS = ('segment', 'customer type', 'industry')
      COMMENT = 'Customer market segment (AUTOMOBILE, BUILDING, etc.)',
    
    customers.customer_tier AS CUSTOMER_TIER
      WITH SYNONYMS = ('tier', 'customer level', 'account tier')
      COMMENT = 'Customer tier based on balance (PREMIUM, STANDARD, etc.)',
    
    -- Product dimensions
    parts.part_name AS PRODUCT_NAME
      WITH SYNONYMS = ('item name', 'product')
      COMMENT = 'Product name',
    
    parts.brand AS BRAND
      WITH SYNONYMS = ('manufacturer brand')
      COMMENT = 'Product brand',
    
    parts.part_type AS PRODUCT_TYPE
      WITH SYNONYMS = ('type', 'category')
      COMMENT = 'Product type/category',
    
    parts.price_tier AS PRICE_TIER
      COMMENT = 'Product price tier (BUDGET, MID, PREMIUM, LUXURY)',
    
    -- Supplier dimensions
    suppliers.supplier_name AS SUPPLIER
      WITH SYNONYMS = ('vendor', 'provider')
      COMMENT = 'Supplier name',
    
    suppliers.supplier_tier AS SUPPLIER_TIER
      COMMENT = 'Supplier performance tier',
    
    -- Order dimensions
    orders.order_status_desc AS ORDER_STATUS
      WITH SYNONYMS = ('status')
      COMMENT = 'Order fulfillment status',
    
    orders.order_priority AS ORDER_PRIORITY
      WITH SYNONYMS = ('priority', 'urgency')
      COMMENT = 'Order priority level',
    
    -- Line item dimensions
    line_items.ship_mode AS SHIP_MODE
      WITH SYNONYMS = ('shipping method', 'delivery method')
      COMMENT = 'Shipping mode (AIR, TRUCK, SHIP, etc.)',
    
    line_items.return_status AS RETURN_STATUS
      COMMENT = 'Return flag (R=Returned, A=Accepted, N=None)',
    
    line_items.delivery_status AS DELIVERY_STATUS
      WITH SYNONYMS = ('on time', 'late')
      COMMENT = 'Delivery status (ON_TIME, LATE, EARLY)'
  )

  METRICS (
    -- Revenue metrics
    orders.total_revenue AS SUM(line_items.revenue)
      WITH SYNONYMS = ('gross sales', 'total sales', 'revenue')
      COMMENT = 'Total gross revenue across all orders',
    
    orders.total_net_revenue AS SUM(line_items.net_revenue)
      WITH SYNONYMS = ('net sales')
      COMMENT = 'Total revenue after discounts',
    
    orders.total_discounts AS SUM(line_items.discount_amount)
      COMMENT = 'Total discount amount given',
    
    -- Order metrics
    orders.order_count AS COUNT(DISTINCT orders.ORDER_KEY)
      WITH SYNONYMS = ('number of orders', 'order volume')
      COMMENT = 'Count of unique orders',
    
    orders.average_order_value AS AVG(orders.order_total)
      WITH SYNONYMS = ('AOV', 'avg order', 'average sale')
      COMMENT = 'Average value per order',
    
    -- Customer metrics
    customers.customer_count AS COUNT(DISTINCT customers.CUSTOMER_KEY)
      WITH SYNONYMS = ('number of customers', 'unique customers')
      COMMENT = 'Count of unique customers',
    
    -- Quantity metrics
    line_items.total_quantity AS SUM(line_items.quantity)
      WITH SYNONYMS = ('units sold', 'total units', 'volume')
      COMMENT = 'Total quantity of items sold',
    
    line_items.average_quantity AS AVG(line_items.quantity)
      COMMENT = 'Average quantity per line item',
    
    -- Delivery metrics
    line_items.average_delivery_days AS AVG(line_items.delivery_days)
      WITH SYNONYMS = ('avg lead time', 'average shipping time')
      COMMENT = 'Average days to deliver',
    
    line_items.on_time_delivery_rate AS 
      (COUNT_IF(line_items.DELIVERY_STATUS = 'ON_TIME') * 100.0 / NULLIF(COUNT(*), 0))
      WITH SYNONYMS = ('OTD rate', 'delivery performance')
      COMMENT = 'Percentage of orders delivered on time',
    
    -- Return metrics
    line_items.return_rate AS 
      (COUNT_IF(line_items.RETURN_FLAG = 'R') * 100.0 / NULLIF(COUNT(*), 0))
      WITH SYNONYMS = ('return percentage')
      COMMENT = 'Percentage of items returned'
  );

-- Apply governance tags
ALTER SEMANTIC VIEW SEM_DEV.SEM_SALES.SALES_ANALYTICS
    SET TAG GOVERNANCE.TAGS.CONTRACT_ID = 'sem_sales_analytics_v1',
            GOVERNANCE.TAGS.DATA_CLASSIFICATION = 'INTERNAL',
            GOVERNANCE.TAGS.AI_ALLOWED = 'TRUE';

-- Grant access
GRANT SELECT, REFERENCES ON SEMANTIC VIEW SEM_DEV.SEM_SALES.SALES_ANALYTICS TO ROLE DATA_ANALYST;
GRANT SELECT, REFERENCES ON SEMANTIC VIEW SEM_DEV.SEM_SALES.SALES_ANALYTICS TO ROLE AI_AGENT;
GRANT SELECT, REFERENCES ON SEMANTIC VIEW SEM_DEV.SEM_SALES.SALES_ANALYTICS TO ROLE BI_VIEWER;

-- ─────────────────────────────────────────────────────────────────────────────
-- SEMANTIC VIEW: Customer Analytics
-- ─────────────────────────────────────────────────────────────────────────────
-- Customer-centric view with RFM scoring and segmentation for churn analysis.

CREATE OR REPLACE SEMANTIC VIEW SEM_DEV.SEM_CUSTOMER.CUSTOMER_ANALYTICS

  COMMENT = 'Customer analytics semantic view with RFM scoring, segmentation, and lifetime value analysis. Ideal for churn prediction and customer health queries.'

  TABLES (
    -- Customers
    customers AS CURATED_DEV.CURATED_DIMENSIONS.DIM_CUSTOMER
      PRIMARY KEY (CUSTOMER_KEY)
      WITH SYNONYMS = ('accounts', 'buyers', 'clients')
      COMMENT = 'Customer master data with segmentation',
    
    -- Customer order summary
    customer_orders AS CURATED_DEV.CURATED_FACTS.FACT_CUSTOMER_ORDERS_SUMMARY
      PRIMARY KEY (CUSTOMER_KEY)
      WITH SYNONYMS = ('customer metrics', 'customer stats')
      COMMENT = 'Aggregated order statistics per customer',
    
    -- Geography
    geography AS CURATED_DEV.CURATED_DIMENSIONS.DIM_GEOGRAPHY
      PRIMARY KEY (NATION_KEY)
      COMMENT = 'Geographic information'
  )

  RELATIONSHIPS (
    customers_to_orders AS
      customers (CUSTOMER_KEY) REFERENCES customer_orders
      COMMENT = 'Each customer has aggregated order statistics',
    
    customers_to_geography AS
      customers (NATION_KEY) REFERENCES geography
      COMMENT = 'Each customer belongs to a nation/region'
  )

  FACTS (
    -- Order facts
    customer_orders.total_orders AS TOTAL_ORDERS
      WITH SYNONYMS = ('order count', 'purchase count')
      COMMENT = 'Total number of orders placed',
    
    customer_orders.total_revenue AS TOTAL_REVENUE
      WITH SYNONYMS = ('lifetime value', 'LTV', 'customer value')
      COMMENT = 'Total revenue from customer',
    
    customer_orders.avg_order_value AS AVG_ORDER_VALUE
      WITH SYNONYMS = ('AOV', 'average purchase')
      COMMENT = 'Average value per order',
    
    customer_orders.total_quantity AS TOTAL_QUANTITY
      COMMENT = 'Total items purchased',
    
    -- Time-based facts
    customer_orders.days_since_last_order AS DAYS_SINCE_LAST_ORDER
      WITH SYNONYMS = ('recency', 'days inactive')
      COMMENT = 'Days since most recent order',
    
    customer_orders.customer_tenure_days AS TENURE_DAYS
      WITH SYNONYMS = ('customer age', 'days as customer')
      COMMENT = 'Days since first order'
  )

  DIMENSIONS (
    -- Customer attributes
    customers.market_segment AS MARKET_SEGMENT
      WITH SYNONYMS = ('segment', 'industry', 'vertical')
      COMMENT = 'Customer market segment',
    
    customers.customer_tier AS CUSTOMER_TIER
      WITH SYNONYMS = ('tier', 'level', 'account tier')
      COMMENT = 'Customer tier based on account balance',
    
    customers.balance_status AS BALANCE_STATUS
      COMMENT = 'Account balance status (POSITIVE, ZERO, NEGATIVE)',
    
    -- Geographic
    geography.region_name AS REGION
      WITH SYNONYMS = ('area', 'territory')
      COMMENT = 'Geographic region',
    
    geography.nation_name AS NATION
      WITH SYNONYMS = ('country')
      COMMENT = 'Country name',
    
    -- Activity status
    customer_orders.activity_status AS ACTIVITY_STATUS
      WITH SYNONYMS = ('status', 'health', 'engagement')
      COMMENT = 'Customer activity status (ACTIVE, AT_RISK, CHURNED, NEW)',
    
    -- Dates
    customer_orders.first_order_date AS FIRST_ORDER_DATE
      WITH SYNONYMS = ('acquisition date', 'signup date')
      COMMENT = 'Date of first order',
    
    customer_orders.last_order_date AS LAST_ORDER_DATE
      WITH SYNONYMS = ('most recent order', 'latest purchase')
      COMMENT = 'Date of most recent order'
  )

  METRICS (
    -- Customer counts
    customers.total_customers AS COUNT(DISTINCT customers.CUSTOMER_KEY)
      WITH SYNONYMS = ('customer count', 'number of customers')
      COMMENT = 'Total unique customers',
    
    customers.active_customers AS COUNT_IF(customer_orders.ACTIVITY_STATUS = 'ACTIVE')
      WITH SYNONYMS = ('engaged customers')
      COMMENT = 'Customers with recent activity',
    
    customers.at_risk_customers AS COUNT_IF(customer_orders.ACTIVITY_STATUS = 'AT_RISK')
      WITH SYNONYMS = ('churn risk', 'customers at risk')
      COMMENT = 'Customers at risk of churning',
    
    customers.churned_customers AS COUNT_IF(customer_orders.ACTIVITY_STATUS = 'CHURNED')
      WITH SYNONYMS = ('lost customers', 'inactive customers')
      COMMENT = 'Customers who have churned',
    
    -- Value metrics
    customers.average_lifetime_value AS AVG(customer_orders.total_revenue)
      WITH SYNONYMS = ('avg LTV', 'average customer value')
      COMMENT = 'Average lifetime value per customer',
    
    customers.total_lifetime_value AS SUM(customer_orders.total_revenue)
      WITH SYNONYMS = ('total LTV', 'total customer value')
      COMMENT = 'Sum of all customer lifetime values',
    
    -- Engagement metrics
    customers.average_orders_per_customer AS AVG(customer_orders.total_orders)
      WITH SYNONYMS = ('order frequency', 'avg orders')
      COMMENT = 'Average number of orders per customer',
    
    customers.average_recency AS AVG(customer_orders.days_since_last_order)
      WITH SYNONYMS = ('avg days since order')
      COMMENT = 'Average days since last order across customers'
  );

-- Apply governance tags
ALTER SEMANTIC VIEW SEM_DEV.SEM_CUSTOMER.CUSTOMER_ANALYTICS
    SET TAG GOVERNANCE.TAGS.CONTRACT_ID = 'sem_customer_analytics_v1',
            GOVERNANCE.TAGS.DATA_CLASSIFICATION = 'INTERNAL',
            GOVERNANCE.TAGS.AI_ALLOWED = 'TRUE';

-- Grant access
GRANT SELECT, REFERENCES ON SEMANTIC VIEW SEM_DEV.SEM_CUSTOMER.CUSTOMER_ANALYTICS TO ROLE DATA_ANALYST;
GRANT SELECT, REFERENCES ON SEMANTIC VIEW SEM_DEV.SEM_CUSTOMER.CUSTOMER_ANALYTICS TO ROLE AI_AGENT;

-- ─────────────────────────────────────────────────────────────────────────────
-- SEMANTIC VIEW: Supplier Analytics
-- ─────────────────────────────────────────────────────────────────────────────
-- Supplier performance view for procurement and vendor management.

CREATE OR REPLACE SEMANTIC VIEW SEM_DEV.SEM_SALES.SUPPLIER_ANALYTICS

  COMMENT = 'Supplier performance semantic view for procurement analytics. Tracks delivery performance, quality metrics, and supplier value.'

  TABLES (
    suppliers AS CURATED_DEV.CURATED_DIMENSIONS.DIM_SUPPLIER
      PRIMARY KEY (SUPPLIER_KEY)
      WITH SYNONYMS = ('vendors', 'providers')
      COMMENT = 'Supplier master data',
    
    line_items AS CURATED_DEV.CURATED_FACTS.FACT_LINEITEM
      PRIMARY KEY (ORDER_KEY, LINE_NUMBER)
      COMMENT = 'Order line items for supplier performance',
    
    partsupp AS CURATED_DEV.CURATED_FACTS.FACT_PARTSUPP
      PRIMARY KEY (PART_KEY, SUPPLIER_KEY)
      COMMENT = 'Part-supplier relationships and inventory'
  )

  RELATIONSHIPS (
    line_items_to_suppliers AS
      line_items (SUPPLIER_KEY) REFERENCES suppliers
      COMMENT = 'Line items fulfilled by suppliers',
    
    partsupp_to_suppliers AS
      partsupp (SUPPLIER_KEY) REFERENCES suppliers
      COMMENT = 'Parts supplied by each supplier'
  )

  FACTS (
    -- Sales facts
    line_items.revenue AS EXTENDED_PRICE
      COMMENT = 'Revenue from supplier items',
    
    line_items.quantity AS QUANTITY
      COMMENT = 'Quantity sold',
    
    line_items.delivery_days AS DELIVERY_DAYS
      WITH SYNONYMS = ('lead time', 'shipping days')
      COMMENT = 'Days to deliver',
    
    -- Inventory facts
    partsupp.available_qty AS AVAILABLE_QUANTITY
      WITH SYNONYMS = ('stock', 'inventory')
      COMMENT = 'Available quantity in inventory',
    
    partsupp.supply_cost AS SUPPLY_COST
      WITH SYNONYMS = ('cost', 'unit cost')
      COMMENT = 'Cost per unit from supplier'
  )

  DIMENSIONS (
    -- Supplier attributes
    suppliers.supplier_name AS SUPPLIER_NAME
      WITH SYNONYMS = ('vendor name', 'provider')
      COMMENT = 'Supplier name',
    
    suppliers.supplier_tier AS SUPPLIER_TIER
      WITH SYNONYMS = ('tier', 'ranking')
      COMMENT = 'Supplier performance tier',
    
    suppliers.nation_name AS NATION
      WITH SYNONYMS = ('country', 'location')
      COMMENT = 'Supplier country',
    
    suppliers.region_name AS REGION
      WITH SYNONYMS = ('area', 'territory')
      COMMENT = 'Supplier region',
    
    -- Delivery status
    line_items.delivery_status AS DELIVERY_STATUS
      WITH SYNONYMS = ('on time status')
      COMMENT = 'Delivery performance (ON_TIME, LATE, EARLY)',
    
    line_items.return_status AS RETURN_STATUS
      COMMENT = 'Return flag'
  )

  METRICS (
    -- Volume metrics
    suppliers.order_count AS COUNT(DISTINCT line_items.ORDER_KEY)
      WITH SYNONYMS = ('orders', 'order volume')
      COMMENT = 'Number of orders with this supplier',
    
    suppliers.total_revenue AS SUM(line_items.revenue)
      WITH SYNONYMS = ('sales', 'revenue')
      COMMENT = 'Total revenue from supplier',
    
    suppliers.total_quantity AS SUM(line_items.quantity)
      WITH SYNONYMS = ('units sold', 'volume')
      COMMENT = 'Total units sold',
    
    -- Performance metrics
    suppliers.average_delivery_days AS AVG(line_items.delivery_days)
      WITH SYNONYMS = ('avg lead time', 'average shipping')
      COMMENT = 'Average days to deliver',
    
    suppliers.on_time_rate AS 
      (COUNT_IF(line_items.DELIVERY_STATUS = 'ON_TIME') * 100.0 / NULLIF(COUNT(*), 0))
      WITH SYNONYMS = ('OTD', 'on time delivery rate')
      COMMENT = 'Percentage delivered on time',
    
    suppliers.late_delivery_rate AS 
      (COUNT_IF(line_items.DELIVERY_STATUS = 'LATE') * 100.0 / NULLIF(COUNT(*), 0))
      WITH SYNONYMS = ('late rate')
      COMMENT = 'Percentage delivered late',
    
    suppliers.return_rate AS 
      (COUNT_IF(line_items.RETURN_FLAG = 'R') * 100.0 / NULLIF(COUNT(*), 0))
      WITH SYNONYMS = ('return percentage', 'defect rate')
      COMMENT = 'Percentage of items returned',
    
    -- Inventory metrics
    suppliers.parts_supplied AS COUNT(DISTINCT partsupp.PART_KEY)
      WITH SYNONYMS = ('product count', 'SKUs')
      COMMENT = 'Number of unique parts supplied',
    
    suppliers.total_inventory AS SUM(partsupp.available_qty)
      WITH SYNONYMS = ('stock level', 'inventory on hand')
      COMMENT = 'Total inventory available'
  );

-- Apply governance tags
ALTER SEMANTIC VIEW SEM_DEV.SEM_SALES.SUPPLIER_ANALYTICS
    SET TAG GOVERNANCE.TAGS.CONTRACT_ID = 'sem_supplier_analytics_v1',
            GOVERNANCE.TAGS.DATA_CLASSIFICATION = 'INTERNAL',
            GOVERNANCE.TAGS.AI_ALLOWED = 'TRUE';

-- Grant access
GRANT SELECT, REFERENCES ON SEMANTIC VIEW SEM_DEV.SEM_SALES.SUPPLIER_ANALYTICS TO ROLE DATA_ANALYST;
GRANT SELECT, REFERENCES ON SEMANTIC VIEW SEM_DEV.SEM_SALES.SUPPLIER_ANALYTICS TO ROLE AI_AGENT;

-- ─────────────────────────────────────────────────────────────────────────────
-- SEMANTIC VIEW: Product Analytics
-- ─────────────────────────────────────────────────────────────────────────────
-- Product performance and inventory analysis.

CREATE OR REPLACE SEMANTIC VIEW SEM_DEV.SEM_PRODUCT.PRODUCT_ANALYTICS

  COMMENT = 'Product analytics semantic view for inventory management and product performance analysis. Tracks sales velocity, margins, and stock levels.'

  TABLES (
    parts AS CURATED_DEV.CURATED_DIMENSIONS.DIM_PART
      PRIMARY KEY (PART_KEY)
      WITH SYNONYMS = ('products', 'items', 'SKUs')
      COMMENT = 'Product catalog',
    
    line_items AS CURATED_DEV.CURATED_FACTS.FACT_LINEITEM
      PRIMARY KEY (ORDER_KEY, LINE_NUMBER)
      COMMENT = 'Sales transactions',
    
    partsupp AS CURATED_DEV.CURATED_FACTS.FACT_PARTSUPP
      PRIMARY KEY (PART_KEY, SUPPLIER_KEY)
      COMMENT = 'Inventory and supply information'
  )

  RELATIONSHIPS (
    line_items_to_parts AS
      line_items (PART_KEY) REFERENCES parts
      COMMENT = 'Line items reference products',
    
    partsupp_to_parts AS
      partsupp (PART_KEY) REFERENCES parts
      COMMENT = 'Inventory records for products'
  )

  FACTS (
    -- Sales facts
    line_items.revenue AS EXTENDED_PRICE
      WITH SYNONYMS = ('sales', 'gross revenue')
      COMMENT = 'Revenue from product sales',
    
    line_items.net_revenue AS DISCOUNTED_PRICE
      COMMENT = 'Revenue after discounts',
    
    line_items.quantity AS QUANTITY
      WITH SYNONYMS = ('units', 'volume')
      COMMENT = 'Quantity sold',
    
    -- Pricing facts
    parts.retail_price AS RETAIL_PRICE
      WITH SYNONYMS = ('price', 'list price')
      COMMENT = 'Product retail price',
    
    partsupp.supply_cost AS SUPPLY_COST
      WITH SYNONYMS = ('cost', 'unit cost')
      COMMENT = 'Cost from supplier',
    
    -- Inventory facts
    partsupp.available_qty AS AVAILABLE_QUANTITY
      WITH SYNONYMS = ('stock', 'inventory', 'on hand')
      COMMENT = 'Available inventory quantity'
  )

  DIMENSIONS (
    -- Product attributes
    parts.part_name AS PRODUCT_NAME
      WITH SYNONYMS = ('name', 'item name')
      COMMENT = 'Product name',
    
    parts.brand AS BRAND
      COMMENT = 'Product brand',
    
    parts.manufacturer AS MANUFACTURER
      WITH SYNONYMS = ('maker')
      COMMENT = 'Product manufacturer',
    
    parts.part_type AS PRODUCT_TYPE
      WITH SYNONYMS = ('type', 'category')
      COMMENT = 'Product type/category',
    
    parts.size_category AS SIZE
      COMMENT = 'Product size category',
    
    parts.price_tier AS PRICE_TIER
      WITH SYNONYMS = ('pricing tier')
      COMMENT = 'Price tier (BUDGET, MID, PREMIUM, LUXURY)',
    
    parts.container_type AS CONTAINER
      WITH SYNONYMS = ('packaging')
      COMMENT = 'Container/packaging type',
    
    -- Return status
    line_items.return_status AS RETURN_STATUS
      COMMENT = 'Return flag'
  )

  METRICS (
    -- Sales metrics
    parts.total_revenue AS SUM(line_items.revenue)
      WITH SYNONYMS = ('sales', 'gross sales')
      COMMENT = 'Total revenue from product',
    
    parts.total_quantity_sold AS SUM(line_items.quantity)
      WITH SYNONYMS = ('units sold', 'volume')
      COMMENT = 'Total units sold',
    
    parts.order_count AS COUNT(DISTINCT line_items.ORDER_KEY)
      WITH SYNONYMS = ('orders', 'transactions')
      COMMENT = 'Number of orders containing product',
    
    -- Margin metrics
    parts.gross_margin AS (AVG(parts.retail_price) - AVG(partsupp.supply_cost))
      WITH SYNONYMS = ('margin', 'profit')
      COMMENT = 'Average gross margin per unit',
    
    parts.gross_margin_pct AS 
      ((AVG(parts.retail_price) - AVG(partsupp.supply_cost)) * 100.0 / NULLIF(AVG(parts.retail_price), 0))
      WITH SYNONYMS = ('margin %', 'profit margin')
      COMMENT = 'Gross margin percentage',
    
    -- Inventory metrics
    parts.total_inventory AS SUM(partsupp.available_qty)
      WITH SYNONYMS = ('stock', 'inventory on hand')
      COMMENT = 'Total available inventory',
    
    parts.supplier_count AS COUNT(DISTINCT partsupp.SUPPLIER_KEY)
      WITH SYNONYMS = ('vendors', 'sources')
      COMMENT = 'Number of suppliers for product',
    
    -- Quality metrics
    parts.return_rate AS 
      (COUNT_IF(line_items.RETURN_FLAG = 'R') * 100.0 / NULLIF(COUNT(*), 0))
      WITH SYNONYMS = ('return %', 'defect rate')
      COMMENT = 'Percentage of items returned'
  );

-- Apply governance tags
ALTER SEMANTIC VIEW SEM_DEV.SEM_PRODUCT.PRODUCT_ANALYTICS
    SET TAG GOVERNANCE.TAGS.CONTRACT_ID = 'sem_product_analytics_v1',
            GOVERNANCE.TAGS.DATA_CLASSIFICATION = 'INTERNAL',
            GOVERNANCE.TAGS.AI_ALLOWED = 'TRUE';

-- Grant access
GRANT SELECT, REFERENCES ON SEMANTIC VIEW SEM_DEV.SEM_PRODUCT.PRODUCT_ANALYTICS TO ROLE DATA_ANALYST;
GRANT SELECT, REFERENCES ON SEMANTIC VIEW SEM_DEV.SEM_PRODUCT.PRODUCT_ANALYTICS TO ROLE AI_AGENT;

-- ─────────────────────────────────────────────────────────────────────────────
-- SEMANTIC VIEW: Governance Analytics
-- ─────────────────────────────────────────────────────────────────────────────
-- Contract health and governance observability.

CREATE OR REPLACE SEMANTIC VIEW SEM_DEV.SEM_SALES.GOVERNANCE_ANALYTICS

  COMMENT = 'Governance analytics semantic view for monitoring data contract health, SLA compliance, and data quality across the platform.'

  TABLES (
    contracts AS GOVERNANCE.CONTRACT_REGISTRY.CONTRACTS
      PRIMARY KEY (CONTRACT_ID)
      WITH SYNONYMS = ('data contracts', 'agreements')
      COMMENT = 'Registered data contracts',
    
    consumers AS GOVERNANCE.CONTRACT_REGISTRY.CONTRACT_CONSUMERS
      PRIMARY KEY (CONSUMER_ID)
      COMMENT = 'Contract consumers/subscribers',
    
    quality_rules AS GOVERNANCE.CONTRACT_REGISTRY.QUALITY_RULES
      PRIMARY KEY (RULE_ID)
      COMMENT = 'Data quality rules',
    
    alerts AS GOVERNANCE.OBSERVABILITY.ALERTS
      PRIMARY KEY (ALERT_ID)
      COMMENT = 'Active and historical alerts'
  )

  RELATIONSHIPS (
    consumers_to_contracts AS
      consumers (CONTRACT_ID) REFERENCES contracts
      COMMENT = 'Consumers subscribe to contracts',
    
    quality_rules_to_contracts AS
      quality_rules (CONTRACT_ID) REFERENCES contracts
      COMMENT = 'Quality rules belong to contracts',
    
    alerts_to_contracts AS
      alerts (CONTRACT_ID) REFERENCES contracts
      COMMENT = 'Alerts are raised for contracts'
  )

  FACTS (
    -- Contract metadata (as numeric for counting)
    contracts.version_number AS 1
      COMMENT = 'Contract version indicator'
  )

  DIMENSIONS (
    -- Contract attributes
    contracts.contract_id AS CONTRACT_ID
      WITH SYNONYMS = ('id', 'contract name')
      COMMENT = 'Unique contract identifier',
    
    contracts.contract_type AS CONTRACT_TYPE
      WITH SYNONYMS = ('type')
      COMMENT = 'Type of contract (data, product)',
    
    contracts.status AS STATUS
      WITH SYNONYMS = ('state', 'lifecycle')
      COMMENT = 'Contract status (draft, active, deprecated)',
    
    contracts.producer_system AS PRODUCER
      WITH SYNONYMS = ('source', 'owner', 'publisher')
      COMMENT = 'System that produces the data',
    
    -- Consumer attributes
    consumers.consumer_system AS CONSUMER
      WITH SYNONYMS = ('subscriber', 'user')
      COMMENT = 'System consuming the contract',
    
    consumers.use_case AS USE_CASE
      COMMENT = 'Business use case for consumption',
    
    -- Quality rule attributes
    quality_rules.rule_name AS RULE_NAME
      COMMENT = 'Quality rule name',
    
    quality_rules.severity AS RULE_SEVERITY
      COMMENT = 'Rule severity (error, warning, info)',
    
    quality_rules.enabled AS RULE_ENABLED
      COMMENT = 'Whether rule is active',
    
    -- Alert attributes
    alerts.alert_type AS ALERT_TYPE
      WITH SYNONYMS = ('type')
      COMMENT = 'Type of alert',
    
    alerts.severity AS ALERT_SEVERITY
      WITH SYNONYMS = ('priority', 'criticality')
      COMMENT = 'Alert severity level',
    
    alerts.status AS ALERT_STATUS
      COMMENT = 'Alert status (OPEN, ACKNOWLEDGED, RESOLVED)',
    
    alerts.title AS ALERT_TITLE
      COMMENT = 'Alert title/summary'
  )

  METRICS (
    -- Contract metrics
    contracts.total_contracts AS COUNT(DISTINCT contracts.CONTRACT_ID)
      WITH SYNONYMS = ('contract count')
      COMMENT = 'Total number of contracts',
    
    contracts.active_contracts AS COUNT_IF(contracts.STATUS = 'active')
      COMMENT = 'Number of active contracts',
    
    -- Consumer metrics
    consumers.total_consumers AS COUNT(DISTINCT consumers.CONSUMER_ID)
      WITH SYNONYMS = ('subscriber count')
      COMMENT = 'Total contract consumers',
    
    consumers.avg_consumers_per_contract AS 
      (COUNT(DISTINCT consumers.CONSUMER_ID) * 1.0 / NULLIF(COUNT(DISTINCT contracts.CONTRACT_ID), 0))
      COMMENT = 'Average consumers per contract',
    
    -- Quality rule metrics
    quality_rules.total_rules AS COUNT(DISTINCT quality_rules.RULE_ID)
      WITH SYNONYMS = ('rule count')
      COMMENT = 'Total quality rules defined',
    
    quality_rules.enabled_rules AS COUNT_IF(quality_rules.ENABLED = TRUE)
      COMMENT = 'Number of enabled rules',
    
    -- Alert metrics
    alerts.total_alerts AS COUNT(DISTINCT alerts.ALERT_ID)
      WITH SYNONYMS = ('alert count')
      COMMENT = 'Total alerts',
    
    alerts.open_alerts AS COUNT_IF(alerts.STATUS = 'OPEN')
      WITH SYNONYMS = ('active alerts', 'unresolved alerts')
      COMMENT = 'Number of open alerts',
    
    alerts.critical_alerts AS COUNT_IF(alerts.SEVERITY = 'CRITICAL')
      WITH SYNONYMS = ('high priority alerts')
      COMMENT = 'Number of critical severity alerts'
  );

-- Apply governance tags
ALTER SEMANTIC VIEW SEM_DEV.SEM_SALES.GOVERNANCE_ANALYTICS
    SET TAG GOVERNANCE.TAGS.CONTRACT_ID = 'sem_governance_analytics_v1',
            GOVERNANCE.TAGS.DATA_CLASSIFICATION = 'INTERNAL',
            GOVERNANCE.TAGS.AI_ALLOWED = 'TRUE';

-- Grant access
GRANT SELECT, REFERENCES ON SEMANTIC VIEW SEM_DEV.SEM_SALES.GOVERNANCE_ANALYTICS TO ROLE DATA_STEWARD;
GRANT SELECT, REFERENCES ON SEMANTIC VIEW SEM_DEV.SEM_SALES.GOVERNANCE_ANALYTICS TO ROLE DATA_ANALYST;

-- ─────────────────────────────────────────────────────────────────────────────
-- VERIFICATION
-- ─────────────────────────────────────────────────────────────────────────────

SELECT 'Semantic Views Created Successfully' AS STATUS;

-- List all semantic views
SHOW SEMANTIC VIEWS IN DATABASE SEM_DEV;

-- Show dimensions in sales analytics
SHOW SEMANTIC DIMENSIONS IN SEMANTIC VIEW SEM_DEV.SEM_SALES.SALES_ANALYTICS;

-- Show metrics in sales analytics
SHOW SEMANTIC METRICS IN SEMANTIC VIEW SEM_DEV.SEM_SALES.SALES_ANALYTICS;

-- ─────────────────────────────────────────────────────────────────────────────
-- NOTES FOR CORTEX ANALYST
-- ─────────────────────────────────────────────────────────────────────────────
/*
These semantic views are designed for use with Cortex Analyst. To query them:

1. Direct SQL query:
   SELECT * FROM SEMANTIC VIEW SEM_DEV.SEM_SALES.SALES_ANALYTICS
   WHERE REGION = 'AMERICA'
   AGGREGATE BY YEAR, QUARTER
   METRICS total_revenue, order_count;

2. Via Cortex Analyst API:
   Call Cortex Analyst with the semantic view reference and natural language query.
   The synonyms and comments help Cortex understand user intent.

3. Grant access to Cortex Analyst users:
   GRANT REFERENCES, SELECT ON SEMANTIC VIEW <view_name> TO ROLE <analyst_role>;

Available Semantic Views:
- SEM_DEV.SEM_SALES.SALES_ANALYTICS - Sales, revenue, orders
- SEM_DEV.SEM_CUSTOMER.CUSTOMER_ANALYTICS - Customer health, churn, LTV
- SEM_DEV.SEM_SALES.SUPPLIER_ANALYTICS - Supplier performance
- SEM_DEV.SEM_PRODUCT.PRODUCT_ANALYTICS - Product performance, inventory
- SEM_DEV.SEM_SALES.GOVERNANCE_ANALYTICS - Contract health, alerts
*/

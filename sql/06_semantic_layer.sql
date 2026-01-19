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
  TABLES (
    -- Orders table
    orders AS CURATED_DEV.CURATED_FACTS.FACT_ORDERS
      PRIMARY KEY (ORDER_KEY)
      WITH SYNONYMS = ('sales orders', 'customer orders', 'purchases'),
    
    -- Line items table  
    line_items AS CURATED_DEV.CURATED_FACTS.FACT_LINEITEM
      PRIMARY KEY (ORDER_KEY, LINE_NUMBER)
      WITH SYNONYMS = ('order lines', 'order items', 'order details'),
    
    -- Customers table
    customers AS CURATED_DEV.CURATED_DIMENSIONS.DIM_CUSTOMER
      PRIMARY KEY (CUSTOMER_KEY)
      WITH SYNONYMS = ('buyers', 'accounts', 'clients'),
    
    -- Parts/Products table
    parts AS CURATED_DEV.CURATED_DIMENSIONS.DIM_PART
      PRIMARY KEY (PART_KEY)
      WITH SYNONYMS = ('products', 'items', 'inventory'),
    
    -- Suppliers table
    suppliers AS CURATED_DEV.CURATED_DIMENSIONS.DIM_SUPPLIER
      PRIMARY KEY (SUPPLIER_KEY)
      WITH SYNONYMS = ('vendors', 'providers'),
    
    -- Geography table
    geography AS CURATED_DEV.CURATED_DIMENSIONS.DIM_GEOGRAPHY
      PRIMARY KEY (NATION_KEY)
      WITH SYNONYMS = ('regions', 'locations', 'countries'),
    
    -- Date table
    dates AS CURATED_DEV.CURATED_DIMENSIONS.DIM_DATE
      PRIMARY KEY (DATE_KEY)
      WITH SYNONYMS = ('calendar', 'time periods')
  )
  RELATIONSHIPS (
    -- Orders to Customers
    orders_to_customers AS
      orders (CUSTOMER_KEY) REFERENCES customers,
    
    -- Line Items to Orders
    line_items_to_orders AS
      line_items (ORDER_KEY) REFERENCES orders,
    
    -- Line Items to Parts
    line_items_to_parts AS
      line_items (PART_KEY) REFERENCES parts,
    
    -- Line Items to Suppliers
    line_items_to_suppliers AS
      line_items (SUPPLIER_KEY) REFERENCES suppliers,
    
    -- Customers to Geography
    customers_to_geography AS
      customers (NATION_KEY) REFERENCES geography,
    
    -- Orders to Dates
    orders_to_dates AS
      orders (ORDER_DATE_KEY) REFERENCES dates (DATE_KEY)
  )
  FACTS (
    -- Revenue facts (using actual column names from FACT_LINEITEM)
    line_items.EXTENDED_PRICE
      WITH SYNONYMS = ('sales', 'gross revenue', 'total price', 'revenue'),
    
    line_items.DISCOUNTED_PRICE
      WITH SYNONYMS = ('net sales', 'discounted revenue', 'net revenue'),
    
    line_items.DISCOUNT_AMOUNT
      WITH SYNONYMS = ('discount value', 'savings'),
    
    line_items.TAX_AMOUNT,
    
    -- Quantity facts
    line_items.QUANTITY
      WITH SYNONYMS = ('units', 'items sold', 'volume'),
    
    -- Delivery facts
    line_items.DELIVERY_DAYS
      WITH SYNONYMS = ('lead time', 'shipping time', 'transit days'),
    
    -- Order value (from FACT_ORDERS)
    orders.ORDER_TOTAL
      WITH SYNONYMS = ('order value', 'order amount', 'total price')
  )
  DIMENSIONS (
    -- Time dimensions (from DIM_DATE)
    dates.YEAR
      WITH SYNONYMS = ('fiscal year', 'calendar year'),
    
    dates.QUARTER
      WITH SYNONYMS = ('fiscal quarter', 'Q1/Q2/Q3/Q4'),
    
    dates.MONTH,
    
    dates.MONTH_NAME,
    
    dates.FULL_DATE
      WITH SYNONYMS = ('order date', 'sale date', 'purchase date', 'transaction date'),
    
    -- Geographic dimensions (from DIM_GEOGRAPHY)
    geography.REGION_NAME
      WITH SYNONYMS = ('region', 'area', 'territory', 'zone'),
    
    geography.NATION_NAME
      WITH SYNONYMS = ('nation', 'country'),
    
    -- Customer dimensions (from DIM_CUSTOMER)
    customers.MARKET_SEGMENT
      WITH SYNONYMS = ('segment', 'customer type', 'industry'),
    
    customers.CUSTOMER_TIER
      WITH SYNONYMS = ('tier', 'customer level', 'account tier'),
    
    -- Product dimensions (from DIM_PART)
    parts.PART_NAME
      WITH SYNONYMS = ('product name', 'item name', 'product'),
    
    parts.BRAND
      WITH SYNONYMS = ('manufacturer brand'),
    
    parts.PART_TYPE
      WITH SYNONYMS = ('product type', 'type', 'category'),
    
    parts.PRICE_TIER,
    
    -- Supplier dimensions (from DIM_SUPPLIER)
    suppliers.SUPPLIER_NAME
      WITH SYNONYMS = ('supplier', 'vendor', 'provider'),
    
    suppliers.SUPPLIER_TIER,
    
    -- Order dimensions (from FACT_ORDERS)
    orders.ORDER_STATUS_DESC
      WITH SYNONYMS = ('order status', 'status'),
    
    orders.ORDER_PRIORITY
      WITH SYNONYMS = ('priority', 'urgency'),
    
    -- Line item dimensions (from FACT_LINEITEM)
    line_items.SHIP_MODE
      WITH SYNONYMS = ('shipping method', 'delivery method'),
    
    line_items.RETURN_STATUS,
    
    line_items.DELIVERY_STATUS
      WITH SYNONYMS = ('on time', 'late')
  )
  METRICS (
    -- Revenue metrics
    total_revenue AS SUM(line_items.EXTENDED_PRICE)
      WITH SYNONYMS = ('gross sales', 'total sales', 'revenue'),
    
    total_net_revenue AS SUM(line_items.DISCOUNTED_PRICE)
      WITH SYNONYMS = ('net sales'),
    
    total_discounts AS SUM(line_items.DISCOUNT_AMOUNT),
    
    -- Order metrics
    order_count AS COUNT(DISTINCT orders.ORDER_KEY)
      WITH SYNONYMS = ('number of orders', 'order volume'),
    
    average_order_value AS AVG(orders.ORDER_TOTAL)
      WITH SYNONYMS = ('AOV', 'avg order', 'average sale'),
    
    -- Customer metrics
    customer_count AS COUNT(DISTINCT customers.CUSTOMER_KEY)
      WITH SYNONYMS = ('number of customers', 'unique customers'),
    
    -- Quantity metrics
    total_quantity AS SUM(line_items.QUANTITY)
      WITH SYNONYMS = ('units sold', 'total units', 'volume'),
    
    average_quantity AS AVG(line_items.QUANTITY),
    
    -- Delivery metrics
    average_delivery_days AS AVG(line_items.DELIVERY_DAYS)
      WITH SYNONYMS = ('avg lead time', 'average shipping time'),
    
    on_time_delivery_rate AS 
      (COUNT_IF(line_items.DELIVERY_STATUS = 'ON_TIME') * 100.0 / NULLIF(COUNT(*), 0))
      WITH SYNONYMS = ('OTD rate', 'delivery performance'),
    
    -- Return metrics
    return_rate AS 
      (COUNT_IF(line_items.RETURN_FLAG = 'R') * 100.0 / NULLIF(COUNT(*), 0))
      WITH SYNONYMS = ('return percentage')
  )
  COMMENT = 'Sales analytics semantic view for Cortex Analyst. Combines orders, line items, customers, and products for comprehensive revenue analysis.';

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
  TABLES (
    -- Customers
    customers AS CURATED_DEV.CURATED_DIMENSIONS.DIM_CUSTOMER
      PRIMARY KEY (CUSTOMER_KEY)
      WITH SYNONYMS = ('accounts', 'buyers', 'clients'),
    
    -- Customer order summary
    customer_orders AS CURATED_DEV.CURATED_FACTS.FACT_CUSTOMER_ORDERS_SUMMARY
      PRIMARY KEY (CUSTOMER_KEY)
      WITH SYNONYMS = ('customer metrics', 'customer stats'),
    
    -- Geography
    geography AS CURATED_DEV.CURATED_DIMENSIONS.DIM_GEOGRAPHY
      PRIMARY KEY (NATION_KEY)
  )
  RELATIONSHIPS (
    customers_to_orders AS
      customers (CUSTOMER_KEY) REFERENCES customer_orders,
    
    customers_to_geography AS
      customers (NATION_KEY) REFERENCES geography
  )
  FACTS (
    -- Order facts (from FACT_CUSTOMER_ORDERS_SUMMARY)
    customer_orders.TOTAL_ORDERS
      WITH SYNONYMS = ('order count', 'purchase count'),
    
    customer_orders.TOTAL_REVENUE
      WITH SYNONYMS = ('lifetime value', 'LTV', 'customer value'),
    
    customer_orders.AVG_ORDER_VALUE
      WITH SYNONYMS = ('AOV', 'average purchase'),
    
    customer_orders.TOTAL_QUANTITY,
    
    -- Time-based facts
    customer_orders.DAYS_SINCE_LAST_ORDER
      WITH SYNONYMS = ('recency', 'days inactive'),
    
    customer_orders.CUSTOMER_TENURE_DAYS
      WITH SYNONYMS = ('tenure', 'customer age', 'days as customer')
  )
  DIMENSIONS (
    -- Customer attributes (from DIM_CUSTOMER)
    customers.MARKET_SEGMENT
      WITH SYNONYMS = ('segment', 'industry', 'vertical'),
    
    customers.CUSTOMER_TIER
      WITH SYNONYMS = ('tier', 'level', 'account tier'),
    
    customers.BALANCE_STATUS,
    
    -- Geographic (from DIM_GEOGRAPHY)
    geography.REGION_NAME
      WITH SYNONYMS = ('region', 'area', 'territory'),
    
    geography.NATION_NAME
      WITH SYNONYMS = ('nation', 'country'),
    
    -- Activity status (from FACT_CUSTOMER_ORDERS_SUMMARY)
    customer_orders.ACTIVITY_STATUS
      WITH SYNONYMS = ('status', 'health', 'engagement'),
    
    -- Dates
    customer_orders.FIRST_ORDER_DATE
      WITH SYNONYMS = ('acquisition date', 'signup date'),
    
    customer_orders.LAST_ORDER_DATE
      WITH SYNONYMS = ('most recent order', 'latest purchase')
  )
  METRICS (
    -- Customer counts
    total_customers AS COUNT(DISTINCT customers.CUSTOMER_KEY)
      WITH SYNONYMS = ('customer count', 'number of customers'),
    
    active_customers AS COUNT_IF(customer_orders.ACTIVITY_STATUS = 'ACTIVE')
      WITH SYNONYMS = ('engaged customers'),
    
    at_risk_customers AS COUNT_IF(customer_orders.ACTIVITY_STATUS = 'AT_RISK')
      WITH SYNONYMS = ('churn risk', 'customers at risk'),
    
    churned_customers AS COUNT_IF(customer_orders.ACTIVITY_STATUS = 'CHURNED')
      WITH SYNONYMS = ('lost customers', 'inactive customers'),
    
    -- Value metrics
    average_lifetime_value AS AVG(customer_orders.TOTAL_REVENUE)
      WITH SYNONYMS = ('avg LTV', 'average customer value'),
    
    total_lifetime_value AS SUM(customer_orders.TOTAL_REVENUE)
      WITH SYNONYMS = ('total LTV', 'total customer value'),
    
    -- Engagement metrics
    average_orders_per_customer AS AVG(customer_orders.TOTAL_ORDERS)
      WITH SYNONYMS = ('order frequency', 'avg orders'),
    
    average_recency AS AVG(customer_orders.DAYS_SINCE_LAST_ORDER)
      WITH SYNONYMS = ('avg days since order')
  )
  COMMENT = 'Customer analytics semantic view with RFM scoring, segmentation, and lifetime value analysis. Ideal for churn prediction and customer health queries.';

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
  TABLES (
    suppliers AS CURATED_DEV.CURATED_DIMENSIONS.DIM_SUPPLIER
      PRIMARY KEY (SUPPLIER_KEY)
      WITH SYNONYMS = ('vendors', 'providers'),
    
    line_items AS CURATED_DEV.CURATED_FACTS.FACT_LINEITEM
      PRIMARY KEY (ORDER_KEY, LINE_NUMBER),
    
    partsupp AS CURATED_DEV.CURATED_FACTS.FACT_PARTSUPP
      PRIMARY KEY (PART_KEY, SUPPLIER_KEY)
  )
  RELATIONSHIPS (
    line_items_to_suppliers AS
      line_items (SUPPLIER_KEY) REFERENCES suppliers,
    
    partsupp_to_suppliers AS
      partsupp (SUPPLIER_KEY) REFERENCES suppliers
  )
  FACTS (
    -- Sales facts (from FACT_LINEITEM)
    line_items.EXTENDED_PRICE
      WITH SYNONYMS = ('revenue', 'sales'),
    
    line_items.QUANTITY,
    
    line_items.DELIVERY_DAYS
      WITH SYNONYMS = ('lead time', 'shipping days'),
    
    -- Inventory facts (from FACT_PARTSUPP)
    partsupp.AVAILABLE_QUANTITY
      WITH SYNONYMS = ('stock', 'inventory'),
    
    partsupp.SUPPLY_COST
      WITH SYNONYMS = ('cost', 'unit cost')
  )
  DIMENSIONS (
    -- Supplier attributes (from DIM_SUPPLIER)
    suppliers.SUPPLIER_NAME
      WITH SYNONYMS = ('vendor name', 'provider'),
    
    suppliers.SUPPLIER_TIER
      WITH SYNONYMS = ('tier', 'ranking'),
    
    suppliers.NATION_NAME
      WITH SYNONYMS = ('nation', 'country', 'location'),
    
    suppliers.REGION_NAME
      WITH SYNONYMS = ('region', 'area', 'territory'),
    
    -- Delivery status (from FACT_LINEITEM)
    line_items.DELIVERY_STATUS
      WITH SYNONYMS = ('on time status'),
    
    line_items.RETURN_STATUS
  )
  METRICS (
    -- Volume metrics
    order_count AS COUNT(DISTINCT line_items.ORDER_KEY)
      WITH SYNONYMS = ('orders', 'order volume'),
    
    total_revenue AS SUM(line_items.EXTENDED_PRICE)
      WITH SYNONYMS = ('sales', 'revenue'),
    
    total_quantity AS SUM(line_items.QUANTITY)
      WITH SYNONYMS = ('units sold', 'volume'),
    
    -- Performance metrics
    average_delivery_days AS AVG(line_items.DELIVERY_DAYS)
      WITH SYNONYMS = ('avg lead time', 'average shipping'),
    
    on_time_rate AS 
      (COUNT_IF(line_items.DELIVERY_STATUS = 'ON_TIME') * 100.0 / NULLIF(COUNT(*), 0))
      WITH SYNONYMS = ('OTD', 'on time delivery rate'),
    
    late_delivery_rate AS 
      (COUNT_IF(line_items.DELIVERY_STATUS = 'LATE') * 100.0 / NULLIF(COUNT(*), 0))
      WITH SYNONYMS = ('late rate'),
    
    return_rate AS 
      (COUNT_IF(line_items.RETURN_FLAG = 'R') * 100.0 / NULLIF(COUNT(*), 0))
      WITH SYNONYMS = ('return percentage', 'defect rate'),
    
    -- Inventory metrics
    parts_supplied AS COUNT(DISTINCT partsupp.PART_KEY)
      WITH SYNONYMS = ('product count', 'SKUs'),
    
    total_inventory AS SUM(partsupp.AVAILABLE_QUANTITY)
      WITH SYNONYMS = ('stock level', 'inventory on hand')
  )
  COMMENT = 'Supplier performance semantic view for procurement analytics. Tracks delivery performance, quality metrics, and supplier value.';

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
  TABLES (
    parts AS CURATED_DEV.CURATED_DIMENSIONS.DIM_PART
      PRIMARY KEY (PART_KEY)
      WITH SYNONYMS = ('products', 'items', 'SKUs'),
    
    line_items AS CURATED_DEV.CURATED_FACTS.FACT_LINEITEM
      PRIMARY KEY (ORDER_KEY, LINE_NUMBER),
    
    partsupp AS CURATED_DEV.CURATED_FACTS.FACT_PARTSUPP
      PRIMARY KEY (PART_KEY, SUPPLIER_KEY)
  )
  RELATIONSHIPS (
    line_items_to_parts AS
      line_items (PART_KEY) REFERENCES parts,
    
    partsupp_to_parts AS
      partsupp (PART_KEY) REFERENCES parts
  )
  FACTS (
    -- Sales facts (from FACT_LINEITEM)
    line_items.EXTENDED_PRICE
      WITH SYNONYMS = ('sales', 'gross revenue', 'revenue'),
    
    line_items.DISCOUNTED_PRICE
      WITH SYNONYMS = ('net revenue'),
    
    line_items.QUANTITY
      WITH SYNONYMS = ('units', 'volume'),
    
    -- Pricing facts (from DIM_PART)
    parts.RETAIL_PRICE
      WITH SYNONYMS = ('price', 'list price'),
    
    -- Cost facts (from FACT_PARTSUPP)
    partsupp.SUPPLY_COST
      WITH SYNONYMS = ('cost', 'unit cost'),
    
    -- Inventory facts
    partsupp.AVAILABLE_QUANTITY
      WITH SYNONYMS = ('stock', 'inventory', 'on hand')
  )
  DIMENSIONS (
    -- Product attributes (from DIM_PART)
    parts.PART_NAME
      WITH SYNONYMS = ('product name', 'name', 'item name'),
    
    parts.BRAND,
    
    parts.MANUFACTURER
      WITH SYNONYMS = ('maker'),
    
    parts.PART_TYPE
      WITH SYNONYMS = ('product type', 'type', 'category'),
    
    parts.SIZE_CATEGORY
      WITH SYNONYMS = ('size'),
    
    parts.PRICE_TIER
      WITH SYNONYMS = ('pricing tier'),
    
    parts.CONTAINER_TYPE
      WITH SYNONYMS = ('container', 'packaging'),
    
    -- Return status (from FACT_LINEITEM)
    line_items.RETURN_STATUS
  )
  METRICS (
    -- Sales metrics
    total_revenue AS SUM(line_items.EXTENDED_PRICE)
      WITH SYNONYMS = ('sales', 'gross sales'),
    
    total_quantity_sold AS SUM(line_items.QUANTITY)
      WITH SYNONYMS = ('units sold', 'volume'),
    
    order_count AS COUNT(DISTINCT line_items.ORDER_KEY)
      WITH SYNONYMS = ('orders', 'transactions'),
    
    -- Margin metrics
    gross_margin AS (AVG(parts.RETAIL_PRICE) - AVG(partsupp.SUPPLY_COST))
      WITH SYNONYMS = ('margin', 'profit'),
    
    gross_margin_pct AS 
      ((AVG(parts.RETAIL_PRICE) - AVG(partsupp.SUPPLY_COST)) * 100.0 / NULLIF(AVG(parts.RETAIL_PRICE), 0))
      WITH SYNONYMS = ('margin %', 'profit margin'),
    
    -- Inventory metrics
    total_inventory AS SUM(partsupp.AVAILABLE_QUANTITY)
      WITH SYNONYMS = ('stock', 'inventory on hand'),
    
    supplier_count AS COUNT(DISTINCT partsupp.SUPPLIER_KEY)
      WITH SYNONYMS = ('vendors', 'sources'),
    
    -- Quality metrics
    return_rate AS 
      (COUNT_IF(line_items.RETURN_FLAG = 'R') * 100.0 / NULLIF(COUNT(*), 0))
      WITH SYNONYMS = ('return %', 'defect rate')
  )
  COMMENT = 'Product analytics semantic view for inventory management and product performance analysis. Tracks sales velocity, margins, and stock levels.';

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
  TABLES (
    contracts AS GOVERNANCE.CONTRACT_REGISTRY.CONTRACTS
      PRIMARY KEY (CONTRACT_ID)
      WITH SYNONYMS = ('data contracts', 'agreements'),
    
    consumers AS GOVERNANCE.CONTRACT_REGISTRY.CONTRACT_CONSUMERS
      PRIMARY KEY (CONSUMER_ID),
    
    quality_rules AS GOVERNANCE.CONTRACT_REGISTRY.QUALITY_RULES
      PRIMARY KEY (RULE_ID),
    
    alerts AS GOVERNANCE.OBSERVABILITY.ALERTS
      PRIMARY KEY (ALERT_ID)
  )
  RELATIONSHIPS (
    consumers_to_contracts AS
      consumers (CONTRACT_ID) REFERENCES contracts,
    
    quality_rules_to_contracts AS
      quality_rules (CONTRACT_ID) REFERENCES contracts,
    
    alerts_to_contracts AS
      alerts (CONTRACT_ID) REFERENCES contracts
  )
  FACTS (
    -- Contract version (from CONTRACTS)
    contracts.VERSION AS VERSION_NUMBER
  )
  DIMENSIONS (
    -- Contract attributes (from CONTRACTS)
    contracts.CONTRACT_ID
      WITH SYNONYMS = ('id', 'contract name'),
    
    contracts.CONTRACT_TYPE
      WITH SYNONYMS = ('type'),
    
    contracts.STATUS
      WITH SYNONYMS = ('state', 'lifecycle'),
    
    contracts.PRODUCER_SYSTEM
      WITH SYNONYMS = ('producer', 'source', 'owner', 'publisher'),
    
    -- Consumer attributes (from CONTRACT_CONSUMERS)
    consumers.CONSUMER_SYSTEM
      WITH SYNONYMS = ('consumer', 'subscriber', 'user'),
    
    consumers.USE_CASE,
    
    -- Quality rule attributes (from QUALITY_RULES)
    quality_rules.RULE_NAME,
    
    quality_rules.SEVERITY
      WITH SYNONYMS = ('rule severity'),
    
    quality_rules.ENABLED
      WITH SYNONYMS = ('rule enabled'),
    
    -- Alert attributes (from ALERTS)
    alerts.ALERT_TYPE
      WITH SYNONYMS = ('type'),
    
    alerts.SEVERITY
      WITH SYNONYMS = ('alert severity', 'priority', 'criticality'),
    
    alerts.STATUS
      WITH SYNONYMS = ('alert status'),
    
    alerts.TITLE
      WITH SYNONYMS = ('alert title')
  )
  METRICS (
    -- Contract metrics
    total_contracts AS COUNT(DISTINCT contracts.CONTRACT_ID)
      WITH SYNONYMS = ('contract count'),
    
    active_contracts AS COUNT_IF(contracts.STATUS = 'active'),
    
    -- Consumer metrics
    total_consumers AS COUNT(DISTINCT consumers.CONSUMER_ID)
      WITH SYNONYMS = ('subscriber count'),
    
    avg_consumers_per_contract AS 
      (COUNT(DISTINCT consumers.CONSUMER_ID) * 1.0 / NULLIF(COUNT(DISTINCT contracts.CONTRACT_ID), 0)),
    
    -- Quality rule metrics
    total_rules AS COUNT(DISTINCT quality_rules.RULE_ID)
      WITH SYNONYMS = ('rule count'),
    
    enabled_rules AS COUNT_IF(quality_rules.ENABLED = TRUE),
    
    -- Alert metrics
    total_alerts AS COUNT(DISTINCT alerts.ALERT_ID)
      WITH SYNONYMS = ('alert count'),
    
    open_alerts AS COUNT_IF(alerts.STATUS = 'OPEN')
      WITH SYNONYMS = ('active alerts', 'unresolved alerts'),
    
    critical_alerts AS COUNT_IF(alerts.SEVERITY = 'CRITICAL')
      WITH SYNONYMS = ('high priority alerts')
  )
  COMMENT = 'Governance analytics semantic view for monitoring data contract health, SLA compliance, and data quality across the platform.';

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
   WHERE REGION_NAME = 'AMERICA'
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

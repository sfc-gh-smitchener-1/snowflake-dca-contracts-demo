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
-- Reference: https://docs.snowflake.com/en/sql-reference/sql/create-semantic-view
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

CREATE OR REPLACE SEMANTIC VIEW SEM_DEV.SEM_SALES.SALES_ANALYTICS
AS
  TABLES (
    orders AS CURATED_DEV.CURATED_FACTS.FACT_ORDERS PRIMARY KEY (ORDER_KEY),
    line_items AS CURATED_DEV.CURATED_FACTS.FACT_LINEITEM PRIMARY KEY (ORDER_KEY, LINE_NUMBER),
    customers AS CURATED_DEV.CURATED_DIMENSIONS.DIM_CUSTOMER PRIMARY KEY (CUSTOMER_KEY),
    parts AS CURATED_DEV.CURATED_DIMENSIONS.DIM_PART PRIMARY KEY (PART_KEY),
    suppliers AS CURATED_DEV.CURATED_DIMENSIONS.DIM_SUPPLIER PRIMARY KEY (SUPPLIER_KEY),
    geography AS CURATED_DEV.CURATED_DIMENSIONS.DIM_GEOGRAPHY PRIMARY KEY (NATION_KEY),
    dates AS CURATED_DEV.CURATED_DIMENSIONS.DIM_DATE PRIMARY KEY (DATE_KEY)
  )
  RELATIONSHIPS (
    orders.CUSTOMER_KEY = customers.CUSTOMER_KEY,
    line_items.ORDER_KEY = orders.ORDER_KEY,
    line_items.PART_KEY = parts.PART_KEY,
    line_items.SUPPLIER_KEY = suppliers.SUPPLIER_KEY,
    customers.NATION_KEY = geography.NATION_KEY,
    orders.ORDER_DATE_KEY = dates.DATE_KEY
  )
  FACTS (
    line_items.EXTENDED_PRICE AS extended_price,
    line_items.DISCOUNTED_PRICE AS discounted_price,
    line_items.DISCOUNT_AMOUNT AS discount_amount,
    line_items.TAX_AMOUNT AS tax_amount,
    line_items.QUANTITY AS quantity,
    line_items.DELIVERY_DAYS AS delivery_days,
    orders.ORDER_TOTAL AS order_total
  )
  DIMENSIONS (
    dates.YEAR AS year,
    dates.QUARTER AS quarter,
    dates.MONTH AS month,
    dates.MONTH_NAME AS month_name,
    dates.FULL_DATE AS full_date,
    geography.REGION_NAME AS region_name,
    geography.NATION_NAME AS nation_name,
    customers.MARKET_SEGMENT AS market_segment,
    customers.CUSTOMER_TIER AS customer_tier,
    parts.PART_NAME AS part_name,
    parts.BRAND AS brand,
    parts.PART_TYPE AS part_type,
    parts.PRICE_TIER AS price_tier,
    suppliers.SUPPLIER_NAME AS supplier_name,
    suppliers.SUPPLIER_TIER AS supplier_tier,
    orders.ORDER_STATUS_DESC AS order_status,
    orders.ORDER_PRIORITY AS order_priority,
    line_items.SHIP_MODE AS ship_mode,
    line_items.RETURN_STATUS AS return_status,
    line_items.DELIVERY_STATUS AS delivery_status
  )
  METRICS (
    total_revenue AS SUM(extended_price),
    total_net_revenue AS SUM(discounted_price),
    total_discounts AS SUM(discount_amount),
    total_tax AS SUM(tax_amount),
    total_quantity AS SUM(quantity),
    average_order_value AS AVG(order_total),
    average_delivery_days AS AVG(delivery_days),
    line_item_count AS COUNT(line_items.LINE_NUMBER),
    order_count AS COUNT(orders.ORDER_KEY)
  )
  COMMENT = 'Sales analytics semantic view for Cortex Analyst';

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

CREATE OR REPLACE SEMANTIC VIEW SEM_DEV.SEM_CUSTOMER.CUSTOMER_ANALYTICS
AS
  TABLES (
    customers AS CURATED_DEV.CURATED_DIMENSIONS.DIM_CUSTOMER PRIMARY KEY (CUSTOMER_KEY),
    customer_orders AS CURATED_DEV.CURATED_FACTS.FACT_CUSTOMER_ORDERS_SUMMARY PRIMARY KEY (CUSTOMER_KEY),
    geography AS CURATED_DEV.CURATED_DIMENSIONS.DIM_GEOGRAPHY PRIMARY KEY (NATION_KEY)
  )
  RELATIONSHIPS (
    customers.CUSTOMER_KEY = customer_orders.CUSTOMER_KEY,
    customers.NATION_KEY = geography.NATION_KEY
  )
  FACTS (
    customer_orders.TOTAL_ORDERS AS total_orders,
    customer_orders.TOTAL_REVENUE AS total_revenue,
    customer_orders.AVG_ORDER_VALUE AS avg_order_value,
    customer_orders.TOTAL_QUANTITY AS total_quantity,
    customer_orders.DAYS_SINCE_LAST_ORDER AS days_since_last_order,
    customer_orders.CUSTOMER_TENURE_DAYS AS customer_tenure_days
  )
  DIMENSIONS (
    customers.MARKET_SEGMENT AS market_segment,
    customers.CUSTOMER_TIER AS customer_tier,
    customers.BALANCE_STATUS AS balance_status,
    geography.REGION_NAME AS region_name,
    geography.NATION_NAME AS nation_name,
    customer_orders.ACTIVITY_STATUS AS activity_status,
    customer_orders.FIRST_ORDER_DATE AS first_order_date,
    customer_orders.LAST_ORDER_DATE AS last_order_date
  )
  METRICS (
    customer_count AS COUNT(customers.CUSTOMER_KEY),
    total_lifetime_value AS SUM(total_revenue),
    average_lifetime_value AS AVG(total_revenue),
    total_orders_all AS SUM(total_orders),
    average_orders_per_customer AS AVG(total_orders),
    average_recency AS AVG(days_since_last_order),
    average_tenure AS AVG(customer_tenure_days)
  )
  COMMENT = 'Customer analytics semantic view with RFM scoring and segmentation';

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

CREATE OR REPLACE SEMANTIC VIEW SEM_DEV.SEM_SALES.SUPPLIER_ANALYTICS
AS
  TABLES (
    suppliers AS CURATED_DEV.CURATED_DIMENSIONS.DIM_SUPPLIER PRIMARY KEY (SUPPLIER_KEY),
    line_items AS CURATED_DEV.CURATED_FACTS.FACT_LINEITEM PRIMARY KEY (ORDER_KEY, LINE_NUMBER),
    partsupp AS CURATED_DEV.CURATED_FACTS.FACT_PARTSUPP PRIMARY KEY (PART_KEY, SUPPLIER_KEY)
  )
  RELATIONSHIPS (
    line_items.SUPPLIER_KEY = suppliers.SUPPLIER_KEY,
    partsupp.SUPPLIER_KEY = suppliers.SUPPLIER_KEY
  )
  FACTS (
    line_items.EXTENDED_PRICE AS extended_price,
    line_items.QUANTITY AS quantity,
    line_items.DELIVERY_DAYS AS delivery_days,
    partsupp.AVAILABLE_QUANTITY AS available_quantity,
    partsupp.SUPPLY_COST AS supply_cost
  )
  DIMENSIONS (
    suppliers.SUPPLIER_NAME AS supplier_name,
    suppliers.SUPPLIER_TIER AS supplier_tier,
    suppliers.NATION_NAME AS nation_name,
    suppliers.REGION_NAME AS region_name,
    line_items.DELIVERY_STATUS AS delivery_status,
    line_items.RETURN_STATUS AS return_status
  )
  METRICS (
    supplier_count AS COUNT(suppliers.SUPPLIER_KEY),
    total_revenue AS SUM(extended_price),
    total_quantity AS SUM(quantity),
    average_delivery_days AS AVG(delivery_days),
    total_inventory AS SUM(available_quantity),
    total_supply_cost AS SUM(supply_cost),
    line_item_count AS COUNT(line_items.LINE_NUMBER)
  )
  COMMENT = 'Supplier performance semantic view for procurement analytics';

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

CREATE OR REPLACE SEMANTIC VIEW SEM_DEV.SEM_PRODUCT.PRODUCT_ANALYTICS
AS
  TABLES (
    parts AS CURATED_DEV.CURATED_DIMENSIONS.DIM_PART PRIMARY KEY (PART_KEY),
    line_items AS CURATED_DEV.CURATED_FACTS.FACT_LINEITEM PRIMARY KEY (ORDER_KEY, LINE_NUMBER),
    partsupp AS CURATED_DEV.CURATED_FACTS.FACT_PARTSUPP PRIMARY KEY (PART_KEY, SUPPLIER_KEY)
  )
  RELATIONSHIPS (
    line_items.PART_KEY = parts.PART_KEY,
    partsupp.PART_KEY = parts.PART_KEY
  )
  FACTS (
    line_items.EXTENDED_PRICE AS extended_price,
    line_items.DISCOUNTED_PRICE AS discounted_price,
    line_items.QUANTITY AS quantity,
    parts.RETAIL_PRICE AS retail_price,
    partsupp.SUPPLY_COST AS supply_cost,
    partsupp.AVAILABLE_QUANTITY AS available_quantity
  )
  DIMENSIONS (
    parts.PART_NAME AS part_name,
    parts.BRAND AS brand,
    parts.MANUFACTURER AS manufacturer,
    parts.PART_TYPE AS part_type,
    parts.SIZE_CATEGORY AS size_category,
    parts.PRICE_TIER AS price_tier,
    parts.CONTAINER_TYPE AS container_type,
    line_items.RETURN_STATUS AS return_status
  )
  METRICS (
    product_count AS COUNT(parts.PART_KEY),
    total_revenue AS SUM(extended_price),
    total_net_revenue AS SUM(discounted_price),
    total_quantity_sold AS SUM(quantity),
    total_inventory AS SUM(available_quantity),
    total_inventory_cost AS SUM(supply_cost),
    average_retail_price AS AVG(retail_price),
    average_supply_cost AS AVG(supply_cost)
  )
  COMMENT = 'Product analytics semantic view for inventory and performance';

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

CREATE OR REPLACE SEMANTIC VIEW SEM_DEV.SEM_SALES.GOVERNANCE_ANALYTICS
AS
  TABLES (
    contracts AS GOVERNANCE.CONTRACT_REGISTRY.CONTRACTS PRIMARY KEY (CONTRACT_ID),
    consumers AS GOVERNANCE.CONTRACT_REGISTRY.CONTRACT_CONSUMERS PRIMARY KEY (CONSUMER_ID),
    quality_rules AS GOVERNANCE.CONTRACT_REGISTRY.QUALITY_RULES PRIMARY KEY (RULE_ID),
    alerts AS GOVERNANCE.OBSERVABILITY.ALERTS PRIMARY KEY (ALERT_ID)
  )
  RELATIONSHIPS (
    consumers.CONTRACT_ID = contracts.CONTRACT_ID,
    quality_rules.CONTRACT_ID = contracts.CONTRACT_ID,
    alerts.CONTRACT_ID = contracts.CONTRACT_ID
  )
  FACTS (
    contracts.VERSION AS version
  )
  DIMENSIONS (
    contracts.CONTRACT_ID AS contract_id,
    contracts.CONTRACT_TYPE AS contract_type,
    contracts.STATUS AS contract_status,
    contracts.PRODUCER_SYSTEM AS producer_system,
    consumers.CONSUMER_SYSTEM AS consumer_system,
    consumers.USE_CASE AS use_case,
    quality_rules.RULE_NAME AS rule_name,
    quality_rules.SEVERITY AS rule_severity,
    quality_rules.ENABLED AS rule_enabled,
    alerts.ALERT_TYPE AS alert_type,
    alerts.SEVERITY AS alert_severity,
    alerts.STATUS AS alert_status,
    alerts.TITLE AS alert_title
  )
  METRICS (
    contract_count AS COUNT(contracts.CONTRACT_ID),
    consumer_count AS COUNT(consumers.CONSUMER_ID),
    rule_count AS COUNT(quality_rules.RULE_ID),
    alert_count AS COUNT(alerts.ALERT_ID),
    total_versions AS SUM(version)
  )
  COMMENT = 'Governance analytics semantic view for contract health monitoring';

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

SHOW SEMANTIC VIEWS IN DATABASE SEM_DEV;

-- ─────────────────────────────────────────────────────────────────────────────
-- NOTES FOR CORTEX ANALYST
-- ─────────────────────────────────────────────────────────────────────────────
/*
Available Semantic Views:
- SEM_DEV.SEM_SALES.SALES_ANALYTICS - Sales, revenue, orders
- SEM_DEV.SEM_CUSTOMER.CUSTOMER_ANALYTICS - Customer health, churn, LTV
- SEM_DEV.SEM_SALES.SUPPLIER_ANALYTICS - Supplier performance
- SEM_DEV.SEM_PRODUCT.PRODUCT_ANALYTICS - Product performance, inventory
- SEM_DEV.SEM_SALES.GOVERNANCE_ANALYTICS - Contract health, alerts
*/

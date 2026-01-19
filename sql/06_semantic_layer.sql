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
    orders(CUSTOMER_KEY) REFERENCES customers(CUSTOMER_KEY),
    line_items(ORDER_KEY) REFERENCES orders(ORDER_KEY),
    line_items(PART_KEY) REFERENCES parts(PART_KEY),
    line_items(SUPPLIER_KEY) REFERENCES suppliers(SUPPLIER_KEY),
    customers(NATION_KEY) REFERENCES geography(NATION_KEY),
    orders(ORDER_DATE_KEY) REFERENCES dates(DATE_KEY)
  )
  DIMENSIONS (
    -- Time dimensions
    dates.YEAR AS YEAR,
    dates.QUARTER AS QUARTER,
    dates.MONTH AS MONTH,
    dates.MONTH_NAME AS MONTH_NAME,
    dates.FULL_DATE AS ORDER_DATE,
    -- Geographic dimensions
    geography.REGION_NAME AS REGION_NAME,
    geography.NATION_NAME AS NATION_NAME,
    -- Customer dimensions
    customers.MARKET_SEGMENT AS MARKET_SEGMENT,
    customers.CUSTOMER_TIER AS CUSTOMER_TIER,
    -- Product dimensions
    parts.PART_NAME AS PART_NAME,
    parts.BRAND AS BRAND,
    parts.PART_TYPE AS PART_TYPE,
    parts.PRICE_TIER AS PRICE_TIER,
    -- Supplier dimensions
    suppliers.SUPPLIER_NAME AS SUPPLIER_NAME,
    suppliers.SUPPLIER_TIER AS SUPPLIER_TIER,
    -- Order dimensions
    orders.ORDER_STATUS_DESC AS ORDER_STATUS,
    orders.ORDER_PRIORITY AS ORDER_PRIORITY,
    -- Line item dimensions
    line_items.SHIP_MODE AS SHIP_MODE,
    line_items.RETURN_STATUS AS RETURN_STATUS,
    line_items.DELIVERY_STATUS AS DELIVERY_STATUS
  )
  METRICS (
    -- Table-scoped metrics
    line_items.total_revenue AS SUM(line_items.EXTENDED_PRICE),
    line_items.total_net_revenue AS SUM(line_items.DISCOUNTED_PRICE),
    line_items.total_discounts AS SUM(line_items.DISCOUNT_AMOUNT),
    line_items.total_tax AS SUM(line_items.TAX_AMOUNT),
    line_items.total_quantity AS SUM(line_items.QUANTITY),
    line_items.total_delivery_days AS SUM(line_items.DELIVERY_DAYS),
    orders.total_order_value AS SUM(orders.ORDER_TOTAL),
    orders.order_count AS COUNT(orders.ORDER_KEY),
    line_items.line_item_count AS COUNT(line_items.LINE_NUMBER),
    customers.customer_count AS COUNT(customers.CUSTOMER_KEY),
    -- Derived metrics
    average_order_value AS orders.total_order_value / NULLIF(orders.order_count, 0),
    average_delivery_days AS line_items.total_delivery_days / NULLIF(line_items.line_item_count, 0)
  )
  COMMENT = 'Sales analytics semantic view for Cortex Analyst - combines orders, line items, customers, and products';

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
  TABLES (
    customers AS CURATED_DEV.CURATED_DIMENSIONS.DIM_CUSTOMER PRIMARY KEY (CUSTOMER_KEY),
    customer_orders AS CURATED_DEV.CURATED_FACTS.FACT_CUSTOMER_ORDERS_SUMMARY PRIMARY KEY (CUSTOMER_KEY),
    geography AS CURATED_DEV.CURATED_DIMENSIONS.DIM_GEOGRAPHY PRIMARY KEY (NATION_KEY)
  )
  RELATIONSHIPS (
    customers(CUSTOMER_KEY) REFERENCES customer_orders(CUSTOMER_KEY),
    customers(NATION_KEY) REFERENCES geography(NATION_KEY)
  )
  DIMENSIONS (
    customers.MARKET_SEGMENT AS MARKET_SEGMENT,
    customers.CUSTOMER_TIER AS CUSTOMER_TIER,
    customers.BALANCE_STATUS AS BALANCE_STATUS,
    geography.REGION_NAME AS REGION_NAME,
    geography.NATION_NAME AS NATION_NAME,
    customer_orders.ACTIVITY_STATUS AS ACTIVITY_STATUS,
    customer_orders.FIRST_ORDER_DATE AS FIRST_ORDER_DATE,
    customer_orders.LAST_ORDER_DATE AS LAST_ORDER_DATE
  )
  METRICS (
    -- Table-scoped metrics
    customers.customer_count AS COUNT(customers.CUSTOMER_KEY),
    customer_orders.total_lifetime_value AS SUM(customer_orders.TOTAL_REVENUE),
    customer_orders.total_orders_all AS SUM(customer_orders.TOTAL_ORDERS),
    customer_orders.total_tenure_days AS SUM(customer_orders.CUSTOMER_TENURE_DAYS),
    customer_orders.total_recency_days AS SUM(customer_orders.DAYS_SINCE_LAST_ORDER),
    -- Derived metrics
    average_lifetime_value AS customer_orders.total_lifetime_value / NULLIF(customers.customer_count, 0),
    average_orders_per_customer AS customer_orders.total_orders_all / NULLIF(customers.customer_count, 0),
    average_recency AS customer_orders.total_recency_days / NULLIF(customers.customer_count, 0),
    average_tenure AS customer_orders.total_tenure_days / NULLIF(customers.customer_count, 0)
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
  TABLES (
    suppliers AS CURATED_DEV.CURATED_DIMENSIONS.DIM_SUPPLIER PRIMARY KEY (SUPPLIER_KEY),
    line_items AS CURATED_DEV.CURATED_FACTS.FACT_LINEITEM PRIMARY KEY (ORDER_KEY, LINE_NUMBER),
    partsupp AS CURATED_DEV.CURATED_FACTS.FACT_PARTSUPP PRIMARY KEY (PART_KEY, SUPPLIER_KEY)
  )
  RELATIONSHIPS (
    line_items(SUPPLIER_KEY) REFERENCES suppliers(SUPPLIER_KEY),
    partsupp(SUPPLIER_KEY) REFERENCES suppliers(SUPPLIER_KEY)
  )
  DIMENSIONS (
    suppliers.SUPPLIER_NAME AS SUPPLIER_NAME,
    suppliers.SUPPLIER_TIER AS SUPPLIER_TIER,
    suppliers.NATION_NAME AS NATION_NAME,
    suppliers.REGION_NAME AS REGION_NAME,
    line_items.DELIVERY_STATUS AS DELIVERY_STATUS,
    line_items.RETURN_STATUS AS RETURN_STATUS
  )
  METRICS (
    -- Table-scoped metrics
    suppliers.supplier_count AS COUNT(suppliers.SUPPLIER_KEY),
    line_items.total_revenue AS SUM(line_items.EXTENDED_PRICE),
    line_items.total_quantity AS SUM(line_items.QUANTITY),
    line_items.total_delivery_days AS SUM(line_items.DELIVERY_DAYS),
    line_items.line_item_count AS COUNT(line_items.LINE_NUMBER),
    partsupp.total_inventory AS SUM(partsupp.AVAILABLE_QUANTITY),
    partsupp.total_supply_cost AS SUM(partsupp.SUPPLY_COST),
    -- Derived metrics
    average_delivery_days AS line_items.total_delivery_days / NULLIF(line_items.line_item_count, 0),
    average_revenue_per_supplier AS line_items.total_revenue / NULLIF(suppliers.supplier_count, 0)
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
  TABLES (
    parts AS CURATED_DEV.CURATED_DIMENSIONS.DIM_PART PRIMARY KEY (PART_KEY),
    line_items AS CURATED_DEV.CURATED_FACTS.FACT_LINEITEM PRIMARY KEY (ORDER_KEY, LINE_NUMBER),
    partsupp AS CURATED_DEV.CURATED_FACTS.FACT_PARTSUPP PRIMARY KEY (PART_KEY, SUPPLIER_KEY)
  )
  RELATIONSHIPS (
    line_items(PART_KEY) REFERENCES parts(PART_KEY),
    partsupp(PART_KEY) REFERENCES parts(PART_KEY)
  )
  DIMENSIONS (
    parts.PART_NAME AS PART_NAME,
    parts.BRAND AS BRAND,
    parts.MANUFACTURER AS MANUFACTURER,
    parts.PART_TYPE AS PART_TYPE,
    parts.SIZE_CATEGORY AS SIZE_CATEGORY,
    parts.PRICE_TIER AS PRICE_TIER,
    parts.CONTAINER_TYPE AS CONTAINER_TYPE,
    line_items.RETURN_STATUS AS RETURN_STATUS
  )
  METRICS (
    -- Table-scoped metrics
    parts.product_count AS COUNT(parts.PART_KEY),
    parts.total_retail_value AS SUM(parts.RETAIL_PRICE),
    line_items.total_revenue AS SUM(line_items.EXTENDED_PRICE),
    line_items.total_net_revenue AS SUM(line_items.DISCOUNTED_PRICE),
    line_items.total_quantity_sold AS SUM(line_items.QUANTITY),
    partsupp.total_inventory AS SUM(partsupp.AVAILABLE_QUANTITY),
    partsupp.total_inventory_cost AS SUM(partsupp.SUPPLY_COST),
    -- Derived metrics
    average_retail_price AS parts.total_retail_value / NULLIF(parts.product_count, 0),
    average_supply_cost AS partsupp.total_inventory_cost / NULLIF(partsupp.total_inventory, 0)
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
  TABLES (
    contracts AS GOVERNANCE.CONTRACT_REGISTRY.CONTRACTS PRIMARY KEY (CONTRACT_ID),
    consumers AS GOVERNANCE.CONTRACT_REGISTRY.CONTRACT_CONSUMERS PRIMARY KEY (CONSUMER_ID),
    quality_rules AS GOVERNANCE.CONTRACT_REGISTRY.QUALITY_RULES PRIMARY KEY (RULE_ID),
    alerts AS GOVERNANCE.OBSERVABILITY.ALERTS PRIMARY KEY (ALERT_ID)
  )
  RELATIONSHIPS (
    consumers(CONTRACT_ID) REFERENCES contracts(CONTRACT_ID),
    quality_rules(CONTRACT_ID) REFERENCES contracts(CONTRACT_ID),
    alerts(CONTRACT_ID) REFERENCES contracts(CONTRACT_ID)
  )
  DIMENSIONS (
    contracts.CONTRACT_ID AS CONTRACT_ID,
    contracts.CONTRACT_TYPE AS CONTRACT_TYPE,
    contracts.STATUS AS CONTRACT_STATUS,
    contracts.PRODUCER_SYSTEM AS PRODUCER_SYSTEM,
    consumers.CONSUMER_SYSTEM AS CONSUMER_SYSTEM,
    consumers.USE_CASE AS USE_CASE,
    quality_rules.RULE_NAME AS RULE_NAME,
    quality_rules.SEVERITY AS RULE_SEVERITY,
    quality_rules.ENABLED AS RULE_ENABLED,
    alerts.ALERT_TYPE AS ALERT_TYPE,
    alerts.SEVERITY AS ALERT_SEVERITY,
    alerts.STATUS AS ALERT_STATUS,
    alerts.TITLE AS ALERT_TITLE
  )
  METRICS (
    -- Table-scoped metrics
    contracts.contract_count AS COUNT(contracts.CONTRACT_ID),
    contracts.total_versions AS SUM(contracts.VERSION),
    consumers.consumer_count AS COUNT(consumers.CONSUMER_ID),
    quality_rules.rule_count AS COUNT(quality_rules.RULE_ID),
    alerts.alert_count AS COUNT(alerts.ALERT_ID),
    -- Derived metrics
    average_consumers_per_contract AS consumers.consumer_count / NULLIF(contracts.contract_count, 0),
    average_rules_per_contract AS quality_rules.rule_count / NULLIF(contracts.contract_count, 0)
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

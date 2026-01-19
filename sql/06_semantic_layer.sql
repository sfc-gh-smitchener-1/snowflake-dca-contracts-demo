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
    orders AS CURATED_DEV.CURATED_FACTS.FACT_ORDERS PRIMARY KEY (ORDER_KEY),
    line_items AS CURATED_DEV.CURATED_FACTS.FACT_LINEITEM PRIMARY KEY (ORDER_KEY, LINE_NUMBER),
    customers AS CURATED_DEV.CURATED_DIMENSIONS.DIM_CUSTOMER PRIMARY KEY (CUSTOMER_KEY),
    parts AS CURATED_DEV.CURATED_DIMENSIONS.DIM_PART PRIMARY KEY (PART_KEY),
    suppliers AS CURATED_DEV.CURATED_DIMENSIONS.DIM_SUPPLIER PRIMARY KEY (SUPPLIER_KEY),
    geography AS CURATED_DEV.CURATED_DIMENSIONS.DIM_GEOGRAPHY PRIMARY KEY (NATION_KEY),
    dates AS CURATED_DEV.CURATED_DIMENSIONS.DIM_DATE PRIMARY KEY (DATE_KEY)
  )
  RELATIONSHIPS (
    orders.CUSTOMER_KEY REFERENCES customers,
    line_items.ORDER_KEY REFERENCES orders,
    line_items.PART_KEY REFERENCES parts,
    line_items.SUPPLIER_KEY REFERENCES suppliers,
    customers.NATION_KEY REFERENCES geography,
    orders.ORDER_DATE_KEY REFERENCES dates (DATE_KEY)
  )
  FACTS (
    line_items.EXTENDED_PRICE,
    line_items.DISCOUNTED_PRICE,
    line_items.DISCOUNT_AMOUNT,
    line_items.TAX_AMOUNT,
    line_items.QUANTITY,
    line_items.DELIVERY_DAYS,
    orders.ORDER_TOTAL
  )
  DIMENSIONS (
    dates.YEAR,
    dates.QUARTER,
    dates.MONTH,
    dates.MONTH_NAME,
    dates.FULL_DATE,
    geography.REGION_NAME,
    geography.NATION_NAME,
    customers.MARKET_SEGMENT,
    customers.CUSTOMER_TIER,
    parts.PART_NAME,
    parts.BRAND,
    parts.PART_TYPE,
    parts.PRICE_TIER,
    suppliers.SUPPLIER_NAME,
    suppliers.SUPPLIER_TIER,
    orders.ORDER_STATUS_DESC,
    orders.ORDER_PRIORITY,
    line_items.SHIP_MODE,
    line_items.RETURN_STATUS,
    line_items.DELIVERY_STATUS
  )
  METRICS (
    total_revenue AS SUM(line_items.EXTENDED_PRICE),
    total_net_revenue AS SUM(line_items.DISCOUNTED_PRICE),
    total_discounts AS SUM(line_items.DISCOUNT_AMOUNT),
    order_count AS COUNT(DISTINCT orders.ORDER_KEY),
    average_order_value AS AVG(orders.ORDER_TOTAL),
    customer_count AS COUNT(DISTINCT customers.CUSTOMER_KEY),
    total_quantity AS SUM(line_items.QUANTITY),
    average_quantity AS AVG(line_items.QUANTITY),
    average_delivery_days AS AVG(line_items.DELIVERY_DAYS),
    on_time_delivery_rate AS (COUNT_IF(line_items.DELIVERY_STATUS = 'ON_TIME') * 100.0 / NULLIF(COUNT(*), 0)),
    return_rate AS (COUNT_IF(line_items.RETURN_FLAG = 'R') * 100.0 / NULLIF(COUNT(*), 0))
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
    customers AS CURATED_DEV.CURATED_DIMENSIONS.DIM_CUSTOMER PRIMARY KEY (CUSTOMER_KEY),
    customer_orders AS CURATED_DEV.CURATED_FACTS.FACT_CUSTOMER_ORDERS_SUMMARY PRIMARY KEY (CUSTOMER_KEY),
    geography AS CURATED_DEV.CURATED_DIMENSIONS.DIM_GEOGRAPHY PRIMARY KEY (NATION_KEY)
  )
  RELATIONSHIPS (
    customers.CUSTOMER_KEY REFERENCES customer_orders,
    customers.NATION_KEY REFERENCES geography
  )
  FACTS (
    customer_orders.TOTAL_ORDERS,
    customer_orders.TOTAL_REVENUE,
    customer_orders.AVG_ORDER_VALUE,
    customer_orders.TOTAL_QUANTITY,
    customer_orders.DAYS_SINCE_LAST_ORDER,
    customer_orders.CUSTOMER_TENURE_DAYS
  )
  DIMENSIONS (
    customers.MARKET_SEGMENT,
    customers.CUSTOMER_TIER,
    customers.BALANCE_STATUS,
    geography.REGION_NAME,
    geography.NATION_NAME,
    customer_orders.ACTIVITY_STATUS,
    customer_orders.FIRST_ORDER_DATE,
    customer_orders.LAST_ORDER_DATE
  )
  METRICS (
    total_customers AS COUNT(DISTINCT customers.CUSTOMER_KEY),
    active_customers AS COUNT_IF(customer_orders.ACTIVITY_STATUS = 'ACTIVE'),
    at_risk_customers AS COUNT_IF(customer_orders.ACTIVITY_STATUS = 'AT_RISK'),
    churned_customers AS COUNT_IF(customer_orders.ACTIVITY_STATUS = 'CHURNED'),
    average_lifetime_value AS AVG(customer_orders.TOTAL_REVENUE),
    total_lifetime_value AS SUM(customer_orders.TOTAL_REVENUE),
    average_orders_per_customer AS AVG(customer_orders.TOTAL_ORDERS),
    average_recency AS AVG(customer_orders.DAYS_SINCE_LAST_ORDER)
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
    suppliers AS CURATED_DEV.CURATED_DIMENSIONS.DIM_SUPPLIER PRIMARY KEY (SUPPLIER_KEY),
    line_items AS CURATED_DEV.CURATED_FACTS.FACT_LINEITEM PRIMARY KEY (ORDER_KEY, LINE_NUMBER),
    partsupp AS CURATED_DEV.CURATED_FACTS.FACT_PARTSUPP PRIMARY KEY (PART_KEY, SUPPLIER_KEY)
  )
  RELATIONSHIPS (
    line_items.SUPPLIER_KEY REFERENCES suppliers,
    partsupp.SUPPLIER_KEY REFERENCES suppliers
  )
  FACTS (
    line_items.EXTENDED_PRICE,
    line_items.QUANTITY,
    line_items.DELIVERY_DAYS,
    partsupp.AVAILABLE_QUANTITY,
    partsupp.SUPPLY_COST
  )
  DIMENSIONS (
    suppliers.SUPPLIER_NAME,
    suppliers.SUPPLIER_TIER,
    suppliers.NATION_NAME,
    suppliers.REGION_NAME,
    line_items.DELIVERY_STATUS,
    line_items.RETURN_STATUS
  )
  METRICS (
    order_count AS COUNT(DISTINCT line_items.ORDER_KEY),
    total_revenue AS SUM(line_items.EXTENDED_PRICE),
    total_quantity AS SUM(line_items.QUANTITY),
    average_delivery_days AS AVG(line_items.DELIVERY_DAYS),
    on_time_rate AS (COUNT_IF(line_items.DELIVERY_STATUS = 'ON_TIME') * 100.0 / NULLIF(COUNT(*), 0)),
    late_delivery_rate AS (COUNT_IF(line_items.DELIVERY_STATUS = 'LATE') * 100.0 / NULLIF(COUNT(*), 0)),
    return_rate AS (COUNT_IF(line_items.RETURN_FLAG = 'R') * 100.0 / NULLIF(COUNT(*), 0)),
    parts_supplied AS COUNT(DISTINCT partsupp.PART_KEY),
    total_inventory AS SUM(partsupp.AVAILABLE_QUANTITY)
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
    parts AS CURATED_DEV.CURATED_DIMENSIONS.DIM_PART PRIMARY KEY (PART_KEY),
    line_items AS CURATED_DEV.CURATED_FACTS.FACT_LINEITEM PRIMARY KEY (ORDER_KEY, LINE_NUMBER),
    partsupp AS CURATED_DEV.CURATED_FACTS.FACT_PARTSUPP PRIMARY KEY (PART_KEY, SUPPLIER_KEY)
  )
  RELATIONSHIPS (
    line_items.PART_KEY REFERENCES parts,
    partsupp.PART_KEY REFERENCES parts
  )
  FACTS (
    line_items.EXTENDED_PRICE,
    line_items.DISCOUNTED_PRICE,
    line_items.QUANTITY,
    parts.RETAIL_PRICE,
    partsupp.SUPPLY_COST,
    partsupp.AVAILABLE_QUANTITY
  )
  DIMENSIONS (
    parts.PART_NAME,
    parts.BRAND,
    parts.MANUFACTURER,
    parts.PART_TYPE,
    parts.SIZE_CATEGORY,
    parts.PRICE_TIER,
    parts.CONTAINER_TYPE,
    line_items.RETURN_STATUS
  )
  METRICS (
    total_revenue AS SUM(line_items.EXTENDED_PRICE),
    total_quantity_sold AS SUM(line_items.QUANTITY),
    order_count AS COUNT(DISTINCT line_items.ORDER_KEY),
    gross_margin AS (AVG(parts.RETAIL_PRICE) - AVG(partsupp.SUPPLY_COST)),
    gross_margin_pct AS ((AVG(parts.RETAIL_PRICE) - AVG(partsupp.SUPPLY_COST)) * 100.0 / NULLIF(AVG(parts.RETAIL_PRICE), 0)),
    total_inventory AS SUM(partsupp.AVAILABLE_QUANTITY),
    supplier_count AS COUNT(DISTINCT partsupp.SUPPLIER_KEY),
    return_rate AS (COUNT_IF(line_items.RETURN_FLAG = 'R') * 100.0 / NULLIF(COUNT(*), 0))
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
    contracts AS GOVERNANCE.CONTRACT_REGISTRY.CONTRACTS PRIMARY KEY (CONTRACT_ID),
    consumers AS GOVERNANCE.CONTRACT_REGISTRY.CONTRACT_CONSUMERS PRIMARY KEY (CONSUMER_ID),
    quality_rules AS GOVERNANCE.CONTRACT_REGISTRY.QUALITY_RULES PRIMARY KEY (RULE_ID),
    alerts AS GOVERNANCE.OBSERVABILITY.ALERTS PRIMARY KEY (ALERT_ID)
  )
  RELATIONSHIPS (
    consumers.CONTRACT_ID REFERENCES contracts,
    quality_rules.CONTRACT_ID REFERENCES contracts,
    alerts.CONTRACT_ID REFERENCES contracts
  )
  FACTS (
    contracts.VERSION
  )
  DIMENSIONS (
    contracts.CONTRACT_ID,
    contracts.CONTRACT_TYPE,
    contracts.STATUS,
    contracts.PRODUCER_SYSTEM,
    consumers.CONSUMER_SYSTEM,
    consumers.USE_CASE,
    quality_rules.RULE_NAME,
    quality_rules.SEVERITY,
    quality_rules.ENABLED,
    alerts.ALERT_TYPE,
    alerts.SEVERITY,
    alerts.STATUS,
    alerts.TITLE
  )
  METRICS (
    total_contracts AS COUNT(DISTINCT contracts.CONTRACT_ID),
    active_contracts AS COUNT_IF(contracts.STATUS = 'active'),
    total_consumers AS COUNT(DISTINCT consumers.CONSUMER_ID),
    avg_consumers_per_contract AS (COUNT(DISTINCT consumers.CONSUMER_ID) * 1.0 / NULLIF(COUNT(DISTINCT contracts.CONTRACT_ID), 0)),
    total_rules AS COUNT(DISTINCT quality_rules.RULE_ID),
    enabled_rules AS COUNT_IF(quality_rules.ENABLED = TRUE),
    total_alerts AS COUNT(DISTINCT alerts.ALERT_ID),
    open_alerts AS COUNT_IF(alerts.STATUS = 'OPEN'),
    critical_alerts AS COUNT_IF(alerts.SEVERITY = 'CRITICAL')
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

3. Grant access to Cortex Analyst users:
   GRANT REFERENCES, SELECT ON SEMANTIC VIEW <view_name> TO ROLE <analyst_role>;

Available Semantic Views:
- SEM_DEV.SEM_SALES.SALES_ANALYTICS - Sales, revenue, orders
- SEM_DEV.SEM_CUSTOMER.CUSTOMER_ANALYTICS - Customer health, churn, LTV
- SEM_DEV.SEM_SALES.SUPPLIER_ANALYTICS - Supplier performance
- SEM_DEV.SEM_PRODUCT.PRODUCT_ANALYTICS - Product performance, inventory
- SEM_DEV.SEM_SALES.GOVERNANCE_ANALYTICS - Contract health, alerts
*/

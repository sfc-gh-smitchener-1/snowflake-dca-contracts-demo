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
    orders (CUSTOMER_KEY) REFERENCES customers,
    line_items (ORDER_KEY) REFERENCES orders,
    line_items (PART_KEY) REFERENCES parts,
    line_items (SUPPLIER_KEY) REFERENCES suppliers,
    customers (NATION_KEY) REFERENCES geography,
    orders (ORDER_DATE_KEY) REFERENCES dates (DATE_KEY)
  )
  FACTS (
    line_items.extended_price AS line_items.EXTENDED_PRICE,
    line_items.discounted_price AS line_items.DISCOUNTED_PRICE,
    line_items.discount_amount AS line_items.DISCOUNT_AMOUNT,
    line_items.tax_amount AS line_items.TAX_AMOUNT,
    line_items.quantity AS line_items.QUANTITY,
    line_items.delivery_days AS line_items.DELIVERY_DAYS,
    orders.order_total AS orders.ORDER_TOTAL
  )
  DIMENSIONS (
    dates.year AS dates.YEAR,
    dates.quarter AS dates.QUARTER,
    dates.month AS dates.MONTH,
    dates.month_name AS dates.MONTH_NAME,
    dates.full_date AS dates.FULL_DATE,
    geography.region_name AS geography.REGION_NAME,
    geography.nation_name AS geography.NATION_NAME,
    customers.market_segment AS customers.MARKET_SEGMENT,
    customers.customer_tier AS customers.CUSTOMER_TIER,
    parts.part_name AS parts.PART_NAME,
    parts.brand AS parts.BRAND,
    parts.part_type AS parts.PART_TYPE,
    parts.price_tier AS parts.PRICE_TIER,
    suppliers.supplier_name AS suppliers.SUPPLIER_NAME,
    suppliers.supplier_tier AS suppliers.SUPPLIER_TIER,
    orders.order_status_desc AS orders.ORDER_STATUS_DESC,
    orders.order_priority AS orders.ORDER_PRIORITY,
    line_items.ship_mode AS line_items.SHIP_MODE,
    line_items.return_status AS line_items.RETURN_STATUS,
    line_items.delivery_status AS line_items.DELIVERY_STATUS
  )
  METRICS (
    total_revenue AS SUM(line_items.EXTENDED_PRICE),
    total_net_revenue AS SUM(line_items.DISCOUNTED_PRICE),
    total_discounts AS SUM(line_items.DISCOUNT_AMOUNT),
    order_count AS COUNT(DISTINCT orders.ORDER_KEY),
    average_order_value AS AVG(orders.ORDER_TOTAL),
    customer_count AS COUNT(DISTINCT customers.CUSTOMER_KEY),
    total_quantity AS SUM(line_items.QUANTITY),
    average_delivery_days AS AVG(line_items.DELIVERY_DAYS)
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
  TABLES (
    customers AS CURATED_DEV.CURATED_DIMENSIONS.DIM_CUSTOMER PRIMARY KEY (CUSTOMER_KEY),
    customer_orders AS CURATED_DEV.CURATED_FACTS.FACT_CUSTOMER_ORDERS_SUMMARY PRIMARY KEY (CUSTOMER_KEY),
    geography AS CURATED_DEV.CURATED_DIMENSIONS.DIM_GEOGRAPHY PRIMARY KEY (NATION_KEY)
  )
  RELATIONSHIPS (
    customers (CUSTOMER_KEY) REFERENCES customer_orders,
    customers (NATION_KEY) REFERENCES geography
  )
  FACTS (
    customer_orders.total_orders AS customer_orders.TOTAL_ORDERS,
    customer_orders.total_revenue AS customer_orders.TOTAL_REVENUE,
    customer_orders.avg_order_value AS customer_orders.AVG_ORDER_VALUE,
    customer_orders.total_quantity AS customer_orders.TOTAL_QUANTITY,
    customer_orders.days_since_last_order AS customer_orders.DAYS_SINCE_LAST_ORDER,
    customer_orders.customer_tenure_days AS customer_orders.CUSTOMER_TENURE_DAYS
  )
  DIMENSIONS (
    customers.market_segment AS customers.MARKET_SEGMENT,
    customers.customer_tier AS customers.CUSTOMER_TIER,
    customers.balance_status AS customers.BALANCE_STATUS,
    geography.region_name AS geography.REGION_NAME,
    geography.nation_name AS geography.NATION_NAME,
    customer_orders.activity_status AS customer_orders.ACTIVITY_STATUS,
    customer_orders.first_order_date AS customer_orders.FIRST_ORDER_DATE,
    customer_orders.last_order_date AS customer_orders.LAST_ORDER_DATE
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
    line_items (SUPPLIER_KEY) REFERENCES suppliers,
    partsupp (SUPPLIER_KEY) REFERENCES suppliers
  )
  FACTS (
    line_items.extended_price AS line_items.EXTENDED_PRICE,
    line_items.quantity AS line_items.QUANTITY,
    line_items.delivery_days AS line_items.DELIVERY_DAYS,
    partsupp.available_quantity AS partsupp.AVAILABLE_QUANTITY,
    partsupp.supply_cost AS partsupp.SUPPLY_COST
  )
  DIMENSIONS (
    suppliers.supplier_name AS suppliers.SUPPLIER_NAME,
    suppliers.supplier_tier AS suppliers.SUPPLIER_TIER,
    suppliers.nation_name AS suppliers.NATION_NAME,
    suppliers.region_name AS suppliers.REGION_NAME,
    line_items.delivery_status AS line_items.DELIVERY_STATUS,
    line_items.return_status AS line_items.RETURN_STATUS
  )
  METRICS (
    order_count AS COUNT(DISTINCT line_items.ORDER_KEY),
    total_revenue AS SUM(line_items.EXTENDED_PRICE),
    total_quantity AS SUM(line_items.QUANTITY),
    average_delivery_days AS AVG(line_items.DELIVERY_DAYS),
    parts_supplied AS COUNT(DISTINCT partsupp.PART_KEY),
    total_inventory AS SUM(partsupp.AVAILABLE_QUANTITY)
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
    line_items (PART_KEY) REFERENCES parts,
    partsupp (PART_KEY) REFERENCES parts
  )
  FACTS (
    line_items.extended_price AS line_items.EXTENDED_PRICE,
    line_items.discounted_price AS line_items.DISCOUNTED_PRICE,
    line_items.quantity AS line_items.QUANTITY,
    parts.retail_price AS parts.RETAIL_PRICE,
    partsupp.supply_cost AS partsupp.SUPPLY_COST,
    partsupp.available_quantity AS partsupp.AVAILABLE_QUANTITY
  )
  DIMENSIONS (
    parts.part_name AS parts.PART_NAME,
    parts.brand AS parts.BRAND,
    parts.manufacturer AS parts.MANUFACTURER,
    parts.part_type AS parts.PART_TYPE,
    parts.size_category AS parts.SIZE_CATEGORY,
    parts.price_tier AS parts.PRICE_TIER,
    parts.container_type AS parts.CONTAINER_TYPE,
    line_items.return_status AS line_items.RETURN_STATUS
  )
  METRICS (
    total_revenue AS SUM(line_items.EXTENDED_PRICE),
    total_quantity_sold AS SUM(line_items.QUANTITY),
    order_count AS COUNT(DISTINCT line_items.ORDER_KEY),
    total_inventory AS SUM(partsupp.AVAILABLE_QUANTITY),
    supplier_count AS COUNT(DISTINCT partsupp.SUPPLIER_KEY)
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
    consumers (CONTRACT_ID) REFERENCES contracts,
    quality_rules (CONTRACT_ID) REFERENCES contracts,
    alerts (CONTRACT_ID) REFERENCES contracts
  )
  FACTS (
    contracts.version AS contracts.VERSION
  )
  DIMENSIONS (
    contracts.contract_id AS contracts.CONTRACT_ID,
    contracts.contract_type AS contracts.CONTRACT_TYPE,
    contracts.status AS contracts.STATUS,
    contracts.producer_system AS contracts.PRODUCER_SYSTEM,
    consumers.consumer_system AS consumers.CONSUMER_SYSTEM,
    consumers.use_case AS consumers.USE_CASE,
    quality_rules.rule_name AS quality_rules.RULE_NAME,
    quality_rules.severity AS quality_rules.SEVERITY,
    quality_rules.enabled AS quality_rules.ENABLED,
    alerts.alert_type AS alerts.ALERT_TYPE,
    alerts.severity AS alerts.SEVERITY,
    alerts.status AS alerts.STATUS,
    alerts.title AS alerts.TITLE
  )
  METRICS (
    total_contracts AS COUNT(DISTINCT contracts.CONTRACT_ID),
    active_contracts AS COUNT_IF(contracts.STATUS = 'active'),
    total_consumers AS COUNT(DISTINCT consumers.CONSUMER_ID),
    total_rules AS COUNT(DISTINCT quality_rules.RULE_ID),
    enabled_rules AS COUNT_IF(quality_rules.ENABLED = TRUE),
    total_alerts AS COUNT(DISTINCT alerts.ALERT_ID),
    open_alerts AS COUNT_IF(alerts.STATUS = 'OPEN'),
    critical_alerts AS COUNT_IF(alerts.SEVERITY = 'CRITICAL')
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

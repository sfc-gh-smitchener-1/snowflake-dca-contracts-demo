-- ============================================================================
-- SEMANTIC LAYER - First-Class Snowflake Semantic Views for AI Consumption
-- ============================================================================
-- This script creates the semantic layer using Snowflake's native semantic
-- view architecture designed for Cortex Analyst and Snowflake Intelligence:
--   1. Semantic Views with embedded model definitions
--   2. Masking policies for PII protection at query time
--   3. Cortex Analyst semantic models for natural language queries
--   4. AI-safe data structures with pseudonymization
-- ============================================================================
-- Reference: Enterprise Architecture Guide for the Snowflake Data Cloud v.5
-- "AI, governance, and automation cannot scale unless business intent is 
--  explicit, portable, and enforceable by the data platform itself."
-- ============================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE ANALYTICS_WH;

-- ─────────────────────────────────────────────────────────────────────────────
-- MASKING POLICIES FOR PII
-- These policies enforce governance at query time, not documentation time
-- ─────────────────────────────────────────────────────────────────────────────

-- Create masking policy for customer names
CREATE OR REPLACE MASKING POLICY SEM_DEV.SEM_CUSTOMER.MASK_CUSTOMER_NAME AS (val VARCHAR) 
RETURNS VARCHAR ->
    CASE
        WHEN CURRENT_ROLE() IN ('ACCOUNTADMIN', 'DATA_ADMIN', 'PII_VIEWER') THEN val
        ELSE '***MASKED***'
    END;

-- Create masking policy for phone numbers
CREATE OR REPLACE MASKING POLICY SEM_DEV.SEM_CUSTOMER.MASK_PHONE AS (val VARCHAR) 
RETURNS VARCHAR ->
    CASE
        WHEN CURRENT_ROLE() IN ('ACCOUNTADMIN', 'DATA_ADMIN', 'PII_VIEWER') THEN val
        ELSE CONCAT(SUBSTRING(val, 1, 3), '-XXX-XXX-', SUBSTRING(val, -4, 4))
    END;

-- Create masking policy for addresses
CREATE OR REPLACE MASKING POLICY SEM_DEV.SEM_CUSTOMER.MASK_ADDRESS AS (val VARCHAR) 
RETURNS VARCHAR ->
    CASE
        WHEN CURRENT_ROLE() IN ('ACCOUNTADMIN', 'DATA_ADMIN', 'PII_VIEWER') THEN val
        ELSE '***ADDRESS MASKED***'
    END;

-- ─────────────────────────────────────────────────────────────────────────────
-- STAGE FOR SEMANTIC MODEL DEFINITIONS
-- Cortex Analyst reads YAML semantic models from a stage
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE STAGE SEM_DEV.SEM_SALES.SEMANTIC_MODELS
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'Stage for storing Cortex Analyst semantic model YAML definitions';

-- ─────────────────────────────────────────────────────────────────────────────
-- SEMANTIC VIEW: Sales Analytics (Core View for AI/Cortex)
-- ─────────────────────────────────────────────────────────────────────────────
-- This view is designed for AI consumption with:
--   - Pseudonymized customer identifiers (no raw PII)
--   - Clear business semantics in column naming
--   - Pre-calculated measures for common analysis patterns
--   - Consistent grain (line item level)

CREATE OR REPLACE VIEW SEM_DEV.SEM_SALES.VW_SALES_ANALYTICS
    COMMENT = 'Core sales analytics view for Cortex Analyst and AI agents. Contains order line items with full dimensional context. Customer PII is pseudonymized making this AI-safe. Contract: sem_sales_analytics_v1'
AS
SELECT
    -- Date Dimensions
    d.FULL_DATE AS ORDER_DATE,
    d.YEAR,
    d.QUARTER,
    d.MONTH,
    d.MONTH_NAME,
    d.WEEK_OF_YEAR,
    d.DAY_NAME,
    d.IS_WEEKEND,
    
    -- Geography Dimensions
    g.REGION_NAME,
    g.REGION_GROUP,
    g.NATION_NAME,
    
    -- Customer Dimensions (Pseudonymized for AI safety)
    c.CUSTOMER_KEY,
    c.CUSTOMER_NAME_HASH AS CUSTOMER_ID,  -- Pseudonymized identifier
    c.MARKET_SEGMENT,
    c.CUSTOMER_TIER,
    
    -- Product Dimensions
    p.PART_KEY,
    p.PART_NAME,
    p.MANUFACTURER,
    p.BRAND,
    p.PART_TYPE,
    p.SIZE_CATEGORY,
    p.PRICE_TIER,
    
    -- Supplier Dimensions
    s.SUPPLIER_KEY,
    s.SUPPLIER_NAME,
    s.SUPPLIER_TIER,
    s.NATION_NAME AS SUPPLIER_NATION,
    s.REGION_GROUP AS SUPPLIER_REGION,
    
    -- Order Dimensions
    o.ORDER_KEY,
    o.ORDER_STATUS_DESC AS ORDER_STATUS,
    o.ORDER_PRIORITY,
    
    -- Line Item Dimensions
    l.LINE_NUMBER,
    l.SHIP_MODE,
    l.RETURN_STATUS,
    l.DELIVERY_STATUS,
    
    -- Measures (with business-friendly names)
    l.QUANTITY,
    l.EXTENDED_PRICE AS GROSS_REVENUE,
    l.DISCOUNTED_PRICE AS NET_REVENUE,
    l.TOTAL_PRICE AS TOTAL_REVENUE_WITH_TAX,
    l.DISCOUNT_AMOUNT,
    l.TAX_AMOUNT,
    l.DELIVERY_DAYS,
    
    -- Calculated Measures
    l.EXTENDED_PRICE / NULLIF(l.QUANTITY, 0) AS UNIT_PRICE,
    l.DISCOUNT_PCT * 100 AS DISCOUNT_PERCENTAGE,
    
    -- Boolean Flags for Analysis
    CASE WHEN l.RETURN_FLAG = 'R' THEN 1 ELSE 0 END AS IS_RETURNED,
    CASE WHEN l.DELIVERY_STATUS = 'LATE' THEN 1 ELSE 0 END AS IS_LATE_DELIVERY,
    
    -- Data Freshness Metadata
    CURRENT_DATE() AS AS_OF_DATE

FROM CURATED_DEV.CURATED_FACTS.FACT_LINEITEM l
JOIN CURATED_DEV.CURATED_FACTS.FACT_ORDERS o 
    ON l.ORDER_KEY = o.ORDER_KEY
JOIN CURATED_DEV.CURATED_DIMENSIONS.DIM_CUSTOMER c 
    ON o.CUSTOMER_KEY = c.CUSTOMER_KEY
JOIN CURATED_DEV.CURATED_DIMENSIONS.DIM_PART p 
    ON l.PART_KEY = p.PART_KEY
JOIN CURATED_DEV.CURATED_DIMENSIONS.DIM_SUPPLIER s 
    ON l.SUPPLIER_KEY = s.SUPPLIER_KEY
JOIN CURATED_DEV.CURATED_DIMENSIONS.DIM_GEOGRAPHY g 
    ON c.NATION_KEY = g.NATION_KEY
LEFT JOIN CURATED_DEV.CURATED_DIMENSIONS.DIM_DATE d 
    ON o.ORDER_DATE_KEY = d.DATE_KEY
WHERE l._IS_CURRENT = TRUE 
  AND o._IS_CURRENT = TRUE;

-- Apply governance tags (intent made executable)
ALTER VIEW SEM_DEV.SEM_SALES.VW_SALES_ANALYTICS
    SET TAG GOVERNANCE.TAGS.CONTRACT_ID = 'sem_sales_analytics_v1',
            GOVERNANCE.TAGS.DATA_CLASSIFICATION = 'INTERNAL',
            GOVERNANCE.TAGS.AI_ALLOWED = 'TRUE';

-- ─────────────────────────────────────────────────────────────────────────────
-- SEMANTIC VIEW: Sales Summary (Pre-Aggregated for Performance)
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE VIEW SEM_DEV.SEM_SALES.VW_SALES_SUMMARY
    COMMENT = 'Pre-aggregated sales summary by key dimensions for fast dashboard queries and AI summarization. No PII present.'
AS
SELECT
    -- Time Grain
    d.YEAR,
    d.QUARTER,
    d.MONTH,
    d.MONTH_NAME,
    
    -- Dimensions
    g.REGION_NAME,
    g.REGION_GROUP,
    c.MARKET_SEGMENT,
    c.CUSTOMER_TIER,
    p.MANUFACTURER,
    p.BRAND,
    p.PRICE_TIER,
    
    -- Aggregated Measures
    COUNT(DISTINCT o.ORDER_KEY) AS ORDER_COUNT,
    COUNT(DISTINCT c.CUSTOMER_KEY) AS CUSTOMER_COUNT,
    COUNT(*) AS LINE_ITEM_COUNT,
    SUM(l.QUANTITY) AS TOTAL_QUANTITY,
    SUM(l.EXTENDED_PRICE) AS GROSS_REVENUE,
    SUM(l.DISCOUNTED_PRICE) AS NET_REVENUE,
    SUM(l.DISCOUNT_AMOUNT) AS TOTAL_DISCOUNTS,
    SUM(l.TAX_AMOUNT) AS TOTAL_TAX,
    
    -- Averages
    AVG(l.QUANTITY) AS AVG_QUANTITY_PER_LINE,
    AVG(l.EXTENDED_PRICE) AS AVG_LINE_VALUE,
    SUM(l.DISCOUNTED_PRICE) / NULLIF(COUNT(DISTINCT o.ORDER_KEY), 0) AS AVG_ORDER_VALUE,
    
    -- Return & Delivery Metrics
    SUM(CASE WHEN l.RETURN_FLAG = 'R' THEN 1 ELSE 0 END) AS RETURNED_ITEMS,
    SUM(CASE WHEN l.RETURN_FLAG = 'R' THEN 1 ELSE 0 END)::FLOAT / NULLIF(COUNT(*), 0) * 100 AS RETURN_RATE_PCT,
    SUM(CASE WHEN l.DELIVERY_STATUS = 'LATE' THEN 1 ELSE 0 END) AS LATE_DELIVERIES,
    SUM(CASE WHEN l.DELIVERY_STATUS = 'LATE' THEN 1 ELSE 0 END)::FLOAT / NULLIF(COUNT(*), 0) * 100 AS LATE_DELIVERY_RATE_PCT,
    AVG(l.DELIVERY_DAYS) AS AVG_DELIVERY_DAYS,
    
    -- Freshness
    CURRENT_DATE() AS AS_OF_DATE

FROM CURATED_DEV.CURATED_FACTS.FACT_LINEITEM l
JOIN CURATED_DEV.CURATED_FACTS.FACT_ORDERS o ON l.ORDER_KEY = o.ORDER_KEY
JOIN CURATED_DEV.CURATED_DIMENSIONS.DIM_CUSTOMER c ON o.CUSTOMER_KEY = c.CUSTOMER_KEY
JOIN CURATED_DEV.CURATED_DIMENSIONS.DIM_PART p ON l.PART_KEY = p.PART_KEY
JOIN CURATED_DEV.CURATED_DIMENSIONS.DIM_GEOGRAPHY g ON c.NATION_KEY = g.NATION_KEY
LEFT JOIN CURATED_DEV.CURATED_DIMENSIONS.DIM_DATE d ON o.ORDER_DATE_KEY = d.DATE_KEY
WHERE l._IS_CURRENT = TRUE AND o._IS_CURRENT = TRUE
GROUP BY 
    d.YEAR, d.QUARTER, d.MONTH, d.MONTH_NAME,
    g.REGION_NAME, g.REGION_GROUP,
    c.MARKET_SEGMENT, c.CUSTOMER_TIER,
    p.MANUFACTURER, p.BRAND, p.PRICE_TIER;

-- Apply tags
ALTER VIEW SEM_DEV.SEM_SALES.VW_SALES_SUMMARY
    SET TAG GOVERNANCE.TAGS.CONTRACT_ID = 'sem_sales_summary_v1',
            GOVERNANCE.TAGS.DATA_CLASSIFICATION = 'INTERNAL',
            GOVERNANCE.TAGS.AI_ALLOWED = 'TRUE';

-- ─────────────────────────────────────────────────────────────────────────────
-- SEMANTIC VIEW: Customer Analytics (AI-Safe with RFM Scoring)
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE VIEW SEM_DEV.SEM_CUSTOMER.VW_CUSTOMER_ANALYTICS
    COMMENT = 'Customer analytics view with RFM scoring and segmentation for AI/ML workloads. All PII is pseudonymized. Contract: sem_customer_analytics_v1'
AS
SELECT
    -- Pseudonymized Customer ID (safe for AI training and embeddings)
    c.CUSTOMER_NAME_HASH AS CUSTOMER_ID,
    
    -- Demographics (non-PII attributes)
    c.MARKET_SEGMENT,
    c.CUSTOMER_TIER,
    c.BALANCE_STATUS,
    g.REGION_NAME,
    g.REGION_GROUP,
    g.NATION_NAME,
    
    -- Order Metrics
    COALESCE(s.TOTAL_ORDERS, 0) AS TOTAL_ORDERS,
    COALESCE(s.TOTAL_REVENUE, 0) AS LIFETIME_VALUE,
    COALESCE(s.AVG_ORDER_VALUE, 0) AS AVG_ORDER_VALUE,
    COALESCE(s.TOTAL_QUANTITY, 0) AS TOTAL_ITEMS_PURCHASED,
    
    -- Order Status Breakdown
    COALESCE(s.OPEN_ORDERS, 0) AS OPEN_ORDERS,
    COALESCE(s.FULFILLED_ORDERS, 0) AS FULFILLED_ORDERS,
    COALESCE(s.PENDING_ORDERS, 0) AS PENDING_ORDERS,
    
    -- Engagement Metrics
    s.FIRST_ORDER_DATE,
    s.LAST_ORDER_DATE,
    COALESCE(s.CUSTOMER_TENURE_DAYS, 0) AS TENURE_DAYS,
    COALESCE(s.DAYS_SINCE_LAST_ORDER, 9999) AS RECENCY_DAYS,
    COALESCE(s.ACTIVITY_STATUS, 'NEW') AS ACTIVITY_STATUS,
    
    -- RFM Scores (Recency, Frequency, Monetary) - 1-5 scale
    CASE 
        WHEN s.DAYS_SINCE_LAST_ORDER <= 90 THEN 5
        WHEN s.DAYS_SINCE_LAST_ORDER <= 180 THEN 4
        WHEN s.DAYS_SINCE_LAST_ORDER <= 365 THEN 3
        WHEN s.DAYS_SINCE_LAST_ORDER <= 730 THEN 2
        ELSE 1
    END AS RECENCY_SCORE,
    
    CASE 
        WHEN s.TOTAL_ORDERS >= 50 THEN 5
        WHEN s.TOTAL_ORDERS >= 25 THEN 4
        WHEN s.TOTAL_ORDERS >= 10 THEN 3
        WHEN s.TOTAL_ORDERS >= 5 THEN 2
        ELSE 1
    END AS FREQUENCY_SCORE,
    
    CASE 
        WHEN s.TOTAL_REVENUE >= 500000 THEN 5
        WHEN s.TOTAL_REVENUE >= 200000 THEN 4
        WHEN s.TOTAL_REVENUE >= 100000 THEN 3
        WHEN s.TOTAL_REVENUE >= 50000 THEN 2
        ELSE 1
    END AS MONETARY_SCORE,
    
    -- Customer Segment (AI-friendly labels derived from RFM)
    CASE 
        WHEN s.ACTIVITY_STATUS = 'CHURNED' THEN 'LOST'
        WHEN s.ACTIVITY_STATUS = 'AT_RISK' AND s.TOTAL_REVENUE >= 200000 THEN 'HIGH_VALUE_AT_RISK'
        WHEN s.ACTIVITY_STATUS = 'AT_RISK' THEN 'AT_RISK'
        WHEN s.TOTAL_ORDERS >= 25 AND s.TOTAL_REVENUE >= 200000 THEN 'CHAMPION'
        WHEN s.TOTAL_ORDERS >= 10 AND s.DAYS_SINCE_LAST_ORDER <= 90 THEN 'LOYAL'
        WHEN s.TOTAL_ORDERS >= 5 THEN 'POTENTIAL_LOYAL'
        WHEN s.TOTAL_ORDERS >= 2 THEN 'PROMISING'
        WHEN s.TOTAL_ORDERS = 1 AND s.DAYS_SINCE_LAST_ORDER <= 180 THEN 'NEW'
        ELSE 'NEEDS_ATTENTION'
    END AS CUSTOMER_SEGMENT,
    
    -- Freshness
    CURRENT_DATE() AS AS_OF_DATE

FROM CURATED_DEV.CURATED_DIMENSIONS.DIM_CUSTOMER c
JOIN CURATED_DEV.CURATED_DIMENSIONS.DIM_GEOGRAPHY g 
    ON c.NATION_KEY = g.NATION_KEY
LEFT JOIN CURATED_DEV.CURATED_FACTS.FACT_CUSTOMER_ORDERS_SUMMARY s 
    ON c.CUSTOMER_KEY = s.CUSTOMER_KEY
WHERE c._IS_CURRENT = TRUE;

-- Apply tags  
ALTER VIEW SEM_DEV.SEM_CUSTOMER.VW_CUSTOMER_ANALYTICS
    SET TAG GOVERNANCE.TAGS.CONTRACT_ID = 'sem_customer_analytics_v1',
            GOVERNANCE.TAGS.DATA_CLASSIFICATION = 'INTERNAL',
            GOVERNANCE.TAGS.AI_ALLOWED = 'TRUE';

-- ─────────────────────────────────────────────────────────────────────────────
-- SEMANTIC VIEW: Product Analytics
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE VIEW SEM_DEV.SEM_PRODUCT.VW_PRODUCT_ANALYTICS
    COMMENT = 'Product performance and inventory analytics for supply chain AI and natural language queries. No PII present.'
AS
WITH product_sales AS (
    SELECT
        l.PART_KEY,
        COUNT(DISTINCT l.ORDER_KEY) AS ORDER_COUNT,
        SUM(l.QUANTITY) AS TOTAL_QUANTITY_SOLD,
        SUM(l.EXTENDED_PRICE) AS GROSS_REVENUE,
        SUM(l.DISCOUNTED_PRICE) AS NET_REVENUE,
        AVG(l.DISCOUNT_PCT) AS AVG_DISCOUNT,
        SUM(CASE WHEN l.RETURN_FLAG = 'R' THEN 1 ELSE 0 END) AS RETURN_COUNT,
        COUNT(DISTINCT l.SUPPLIER_KEY) AS SUPPLIER_COUNT
    FROM CURATED_DEV.CURATED_FACTS.FACT_LINEITEM l
    WHERE l._IS_CURRENT = TRUE
    GROUP BY l.PART_KEY
),
product_supply AS (
    SELECT
        PART_KEY,
        SUM(AVAILABLE_QUANTITY) AS TOTAL_AVAILABLE_QTY,
        AVG(SUPPLY_COST) AS AVG_SUPPLY_COST,
        SUM(INVENTORY_VALUE) AS TOTAL_INVENTORY_VALUE
    FROM CURATED_DEV.CURATED_FACTS.FACT_PARTSUPP
    WHERE _IS_CURRENT = TRUE
    GROUP BY PART_KEY
)
SELECT
    -- Product Dimensions
    p.PART_KEY,
    p.PART_ID,
    p.PART_NAME,
    p.MANUFACTURER,
    p.BRAND,
    p.PART_TYPE,
    p.FINISH_TYPE,
    p.MATERIAL_TYPE,
    p.PART_SIZE,
    p.SIZE_CATEGORY,
    p.CONTAINER_TYPE,
    p.RETAIL_PRICE,
    p.PRICE_TIER,
    
    -- Sales Metrics
    COALESCE(ps.ORDER_COUNT, 0) AS ORDER_COUNT,
    COALESCE(ps.TOTAL_QUANTITY_SOLD, 0) AS TOTAL_QUANTITY_SOLD,
    COALESCE(ps.GROSS_REVENUE, 0) AS GROSS_REVENUE,
    COALESCE(ps.NET_REVENUE, 0) AS NET_REVENUE,
    COALESCE(ps.AVG_DISCOUNT, 0) * 100 AS AVG_DISCOUNT_PCT,
    COALESCE(ps.RETURN_COUNT, 0) AS RETURN_COUNT,
    COALESCE(ps.RETURN_COUNT, 0)::FLOAT / NULLIF(ps.TOTAL_QUANTITY_SOLD, 0) * 100 AS RETURN_RATE_PCT,
    
    -- Supply Metrics
    COALESCE(ps.SUPPLIER_COUNT, 0) AS ACTIVE_SUPPLIERS,
    COALESCE(sup.TOTAL_AVAILABLE_QTY, 0) AS INVENTORY_ON_HAND,
    COALESCE(sup.AVG_SUPPLY_COST, 0) AS AVG_SUPPLY_COST,
    COALESCE(sup.TOTAL_INVENTORY_VALUE, 0) AS INVENTORY_VALUE,
    
    -- Margin Analysis
    p.RETAIL_PRICE - COALESCE(sup.AVG_SUPPLY_COST, 0) AS GROSS_MARGIN,
    (p.RETAIL_PRICE - COALESCE(sup.AVG_SUPPLY_COST, 0)) / NULLIF(p.RETAIL_PRICE, 0) * 100 AS GROSS_MARGIN_PCT,
    
    -- Inventory Status (AI-friendly labels)
    CASE 
        WHEN sup.TOTAL_AVAILABLE_QTY IS NULL OR sup.TOTAL_AVAILABLE_QTY = 0 THEN 'OUT_OF_STOCK'
        WHEN sup.TOTAL_AVAILABLE_QTY < 1000 THEN 'LOW_STOCK'
        WHEN sup.TOTAL_AVAILABLE_QTY < 5000 THEN 'NORMAL'
        ELSE 'HIGH_STOCK'
    END AS INVENTORY_STATUS,
    
    -- Product Performance Tier (AI-friendly labels)
    CASE 
        WHEN ps.GROSS_REVENUE >= 1000000 THEN 'TOP_PERFORMER'
        WHEN ps.GROSS_REVENUE >= 500000 THEN 'STRONG_PERFORMER'
        WHEN ps.GROSS_REVENUE >= 100000 THEN 'AVERAGE_PERFORMER'
        WHEN ps.GROSS_REVENUE > 0 THEN 'UNDERPERFORMER'
        ELSE 'NO_SALES'
    END AS PERFORMANCE_TIER,
    
    -- Freshness
    CURRENT_DATE() AS AS_OF_DATE

FROM CURATED_DEV.CURATED_DIMENSIONS.DIM_PART p
LEFT JOIN product_sales ps ON p.PART_KEY = ps.PART_KEY
LEFT JOIN product_supply sup ON p.PART_KEY = sup.PART_KEY
WHERE p._IS_CURRENT = TRUE;

-- Apply tags
ALTER VIEW SEM_DEV.SEM_PRODUCT.VW_PRODUCT_ANALYTICS
    SET TAG GOVERNANCE.TAGS.CONTRACT_ID = 'sem_product_analytics_v1',
            GOVERNANCE.TAGS.DATA_CLASSIFICATION = 'INTERNAL',
            GOVERNANCE.TAGS.AI_ALLOWED = 'TRUE';

-- ─────────────────────────────────────────────────────────────────────────────
-- SEMANTIC VIEW: Supplier Analytics
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE VIEW SEM_DEV.SEM_SALES.VW_SUPPLIER_ANALYTICS
    COMMENT = 'Supplier performance analytics for procurement AI and vendor management. Includes quality and delivery metrics.'
AS
WITH supplier_sales AS (
    SELECT
        l.SUPPLIER_KEY,
        COUNT(DISTINCT l.ORDER_KEY) AS ORDER_COUNT,
        COUNT(*) AS LINE_ITEM_COUNT,
        SUM(l.QUANTITY) AS TOTAL_QUANTITY,
        SUM(l.EXTENDED_PRICE) AS GROSS_REVENUE,
        SUM(l.DISCOUNTED_PRICE) AS NET_REVENUE,
        SUM(CASE WHEN l.RETURN_FLAG = 'R' THEN 1 ELSE 0 END) AS RETURN_COUNT,
        SUM(CASE WHEN l.DELIVERY_STATUS = 'LATE' THEN 1 ELSE 0 END) AS LATE_DELIVERIES,
        AVG(l.DELIVERY_DAYS) AS AVG_DELIVERY_DAYS
    FROM CURATED_DEV.CURATED_FACTS.FACT_LINEITEM l
    WHERE l._IS_CURRENT = TRUE
    GROUP BY l.SUPPLIER_KEY
),
supplier_inventory AS (
    SELECT
        SUPPLIER_KEY,
        COUNT(DISTINCT PART_KEY) AS PARTS_SUPPLIED,
        SUM(AVAILABLE_QUANTITY) AS TOTAL_INVENTORY,
        SUM(INVENTORY_VALUE) AS TOTAL_INVENTORY_VALUE
    FROM CURATED_DEV.CURATED_FACTS.FACT_PARTSUPP
    WHERE _IS_CURRENT = TRUE
    GROUP BY SUPPLIER_KEY
)
SELECT
    -- Supplier Dimensions
    s.SUPPLIER_KEY,
    s.SUPPLIER_ID,
    s.SUPPLIER_NAME,
    s.SUPPLIER_TIER,
    s.NATION_NAME,
    s.REGION_NAME,
    s.REGION_GROUP,
    s.ACCOUNT_BALANCE,
    
    -- Sales Performance
    COALESCE(ss.ORDER_COUNT, 0) AS ORDER_COUNT,
    COALESCE(ss.LINE_ITEM_COUNT, 0) AS LINE_ITEM_COUNT,
    COALESCE(ss.TOTAL_QUANTITY, 0) AS TOTAL_QUANTITY_SOLD,
    COALESCE(ss.GROSS_REVENUE, 0) AS GROSS_REVENUE,
    COALESCE(ss.NET_REVENUE, 0) AS NET_REVENUE,
    
    -- Quality Metrics
    COALESCE(ss.RETURN_COUNT, 0) AS RETURN_COUNT,
    COALESCE(ss.RETURN_COUNT, 0)::FLOAT / NULLIF(ss.LINE_ITEM_COUNT, 0) * 100 AS RETURN_RATE_PCT,
    COALESCE(ss.LATE_DELIVERIES, 0) AS LATE_DELIVERIES,
    COALESCE(ss.LATE_DELIVERIES, 0)::FLOAT / NULLIF(ss.LINE_ITEM_COUNT, 0) * 100 AS LATE_DELIVERY_RATE_PCT,
    COALESCE(ss.AVG_DELIVERY_DAYS, 0) AS AVG_DELIVERY_DAYS,
    
    -- Inventory Metrics
    COALESCE(si.PARTS_SUPPLIED, 0) AS PARTS_SUPPLIED,
    COALESCE(si.TOTAL_INVENTORY, 0) AS TOTAL_INVENTORY,
    COALESCE(si.TOTAL_INVENTORY_VALUE, 0) AS INVENTORY_VALUE,
    
    -- Supplier Score (composite 0-100)
    (
        -- Revenue component (0-40 points)
        LEAST(COALESCE(ss.NET_REVENUE, 0) / 1000000 * 10, 40) +
        -- Quality component (0-30 points)
        (30 - LEAST(COALESCE(ss.RETURN_COUNT, 0)::FLOAT / NULLIF(ss.LINE_ITEM_COUNT, 1) * 100, 30)) +
        -- Delivery component (0-30 points)
        (30 - LEAST(COALESCE(ss.LATE_DELIVERIES, 0)::FLOAT / NULLIF(ss.LINE_ITEM_COUNT, 1) * 100, 30))
    )::INT AS SUPPLIER_SCORE,
    
    -- Supplier Category (AI-friendly labels)
    CASE 
        WHEN ss.NET_REVENUE >= 5000000 AND 
             (ss.RETURN_COUNT::FLOAT / NULLIF(ss.LINE_ITEM_COUNT, 1)) < 0.02 THEN 'PREFERRED'
        WHEN ss.NET_REVENUE >= 1000000 THEN 'STRATEGIC'
        WHEN ss.NET_REVENUE >= 100000 THEN 'STANDARD'
        WHEN ss.NET_REVENUE > 0 THEN 'TRANSACTIONAL'
        ELSE 'INACTIVE'
    END AS SUPPLIER_CATEGORY,
    
    -- Freshness
    CURRENT_DATE() AS AS_OF_DATE

FROM CURATED_DEV.CURATED_DIMENSIONS.DIM_SUPPLIER s
LEFT JOIN supplier_sales ss ON s.SUPPLIER_KEY = ss.SUPPLIER_KEY
LEFT JOIN supplier_inventory si ON s.SUPPLIER_KEY = si.SUPPLIER_KEY
WHERE s._IS_CURRENT = TRUE;

-- Apply tags
ALTER VIEW SEM_DEV.SEM_SALES.VW_SUPPLIER_ANALYTICS
    SET TAG GOVERNANCE.TAGS.CONTRACT_ID = 'sem_supplier_analytics_v1',
            GOVERNANCE.TAGS.DATA_CLASSIFICATION = 'INTERNAL',
            GOVERNANCE.TAGS.AI_ALLOWED = 'TRUE';

-- ─────────────────────────────────────────────────────────────────────────────
-- CORTEX ANALYST SEMANTIC MODEL REGISTRATION
-- ─────────────────────────────────────────────────────────────────────────────
-- The semantic model YAML files define how Cortex Analyst interprets 
-- natural language queries against these views. Models are stored in the
-- SEMANTIC_MODELS stage and registered here for discovery.

CREATE OR REPLACE TABLE SEM_DEV.SEM_SALES.SEMANTIC_MODEL_REGISTRY (
    MODEL_ID VARCHAR(128) PRIMARY KEY,
    MODEL_NAME VARCHAR(256) NOT NULL,
    MODEL_VERSION VARCHAR(20) NOT NULL,
    MODEL_TYPE VARCHAR(50) NOT NULL,  -- 'CORTEX_ANALYST', 'CORTEX_SEARCH', 'INTELLIGENCE'
    BASE_VIEW VARCHAR(256) NOT NULL,
    STAGE_PATH VARCHAR(512),  -- Path to YAML in stage
    CONTRACT_ID VARCHAR(128),  -- Link to data contract
    DESCRIPTION TEXT,
    AI_SAFE BOOLEAN DEFAULT TRUE,
    CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    CREATED_BY VARCHAR(256) DEFAULT CURRENT_USER()
);

-- Register semantic models (these link to the YAML files in semantic_models/)
INSERT INTO SEM_DEV.SEM_SALES.SEMANTIC_MODEL_REGISTRY 
    (MODEL_ID, MODEL_NAME, MODEL_VERSION, MODEL_TYPE, BASE_VIEW, STAGE_PATH, CONTRACT_ID, DESCRIPTION, AI_SAFE)
VALUES 
    ('sem_sales_analytics', 
     'Sales Analytics Model', 
     '1.0.0', 
     'CORTEX_ANALYST', 
     'SEM_DEV.SEM_SALES.VW_SALES_ANALYTICS',
     '@SEM_DEV.SEM_SALES.SEMANTIC_MODELS/sales_analytics_model.yaml',
     'sem_sales_analytics_v1',
     'Core sales analytics semantic model for natural language queries on orders, products, and customers. Enables questions like "What was revenue by region last quarter?" All customer PII is pseudonymized.',
     TRUE),
     
    ('sem_customer_analytics', 
     'Customer Analytics Model', 
     '1.0.0', 
     'CORTEX_ANALYST', 
     'SEM_DEV.SEM_CUSTOMER.VW_CUSTOMER_ANALYTICS',
     '@SEM_DEV.SEM_SALES.SEMANTIC_MODELS/customer_analytics_model.yaml',
     'sem_customer_analytics_v1',
     'Customer segmentation and RFM analytics for AI-powered customer insights. Enables questions like "Which customers are at risk of churning?" No raw PII exposed.',
     TRUE),
     
    ('sem_product_analytics', 
     'Product Analytics Model', 
     '1.0.0', 
     'CORTEX_ANALYST', 
     'SEM_DEV.SEM_PRODUCT.VW_PRODUCT_ANALYTICS',
     '@SEM_DEV.SEM_SALES.SEMANTIC_MODELS/product_analytics_model.yaml',
     'sem_product_analytics_v1',
     'Product performance and inventory analytics for supply chain intelligence. Enables questions like "Which products are low on stock with high sales?"',
     TRUE),
     
    ('sem_supplier_analytics', 
     'Supplier Analytics Model', 
     '1.0.0', 
     'CORTEX_ANALYST', 
     'SEM_DEV.SEM_SALES.VW_SUPPLIER_ANALYTICS',
     '@SEM_DEV.SEM_SALES.SEMANTIC_MODELS/supplier_analytics_model.yaml',
     'sem_supplier_analytics_v1',
     'Supplier performance and quality metrics for procurement AI. Enables questions like "Which suppliers have the best on-time delivery rate?"',
     TRUE),
     
    ('governance_analytics', 
     'Governance & Trust Analytics Model', 
     '1.0.0', 
     'CORTEX_ANALYST', 
     'GOVERNANCE.OBSERVABILITY.VW_CONTRACT_HEALTH_DASHBOARD',
     '@SEM_DEV.SEM_SALES.SEMANTIC_MODELS/governance_analytics_model.yaml',
     NULL,
     'Contract health, SLA compliance, quality scores, and trust metrics. Enables questions like "Which contracts have critical issues?" and "What is our overall SLA compliance?"',
     TRUE);

-- ─────────────────────────────────────────────────────────────────────────────
-- HELPER VIEW: Available Semantic Models for Cortex
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE VIEW SEM_DEV.SEM_SALES.VW_AVAILABLE_SEMANTIC_MODELS
    COMMENT = 'Discovery view for all registered Cortex Analyst semantic models'
AS
SELECT
    MODEL_ID,
    MODEL_NAME,
    MODEL_VERSION,
    MODEL_TYPE,
    BASE_VIEW,
    STAGE_PATH,
    CONTRACT_ID,
    DESCRIPTION,
    AI_SAFE,
    CREATED_AT,
    UPDATED_AT
FROM SEM_DEV.SEM_SALES.SEMANTIC_MODEL_REGISTRY
ORDER BY MODEL_NAME;

-- ─────────────────────────────────────────────────────────────────────────────
-- VERIFICATION
-- ─────────────────────────────────────────────────────────────────────────────

SELECT 'Semantic Layer Created Successfully - Views are AI-Ready (Not Secure Views)' AS STATUS;

SHOW VIEWS IN DATABASE SEM_DEV;

-- Test the views
SELECT 'VW_SALES_ANALYTICS' AS VIEW_NAME, COUNT(*) AS ROW_COUNT FROM SEM_DEV.SEM_SALES.VW_SALES_ANALYTICS
UNION ALL
SELECT 'VW_SALES_SUMMARY', COUNT(*) FROM SEM_DEV.SEM_SALES.VW_SALES_SUMMARY
UNION ALL
SELECT 'VW_CUSTOMER_ANALYTICS', COUNT(*) FROM SEM_DEV.SEM_CUSTOMER.VW_CUSTOMER_ANALYTICS
UNION ALL
SELECT 'VW_PRODUCT_ANALYTICS', COUNT(*) FROM SEM_DEV.SEM_PRODUCT.VW_PRODUCT_ANALYTICS
UNION ALL
SELECT 'VW_SUPPLIER_ANALYTICS', COUNT(*) FROM SEM_DEV.SEM_SALES.VW_SUPPLIER_ANALYTICS;

-- Show registered semantic models
SELECT * FROM SEM_DEV.SEM_SALES.VW_AVAILABLE_SEMANTIC_MODELS;

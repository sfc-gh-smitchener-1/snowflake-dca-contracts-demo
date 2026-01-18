-- ============================================================================
-- CURATED LAYER - Dynamic Tables for Transformation
-- ============================================================================
-- This script creates Dynamic Tables that:
--   1. Transform raw data into business-ready dimensions and facts
--   2. Automatically refresh based on upstream changes
--   3. Apply business rules and data quality transformations
--   4. Maintain contract adherence through the pipeline
-- ============================================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE CURATED_DEV;
USE WAREHOUSE TRANSFORM_WH;

-- ─────────────────────────────────────────────────────────────────────────────
-- DIMENSION: Geography (Region + Nation)
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE DYNAMIC TABLE CURATED_DEV.CURATED_DIMENSIONS.DIM_GEOGRAPHY
    TARGET_LAG = '1 hour'
    WAREHOUSE = TRANSFORM_WH
    COMMENT = 'Curated geography dimension combining region and nation'
AS
SELECT
    -- Surrogate Key
    n.N_NATIONKEY AS GEOGRAPHY_KEY,
    
    -- Nation Attributes
    n.N_NATIONKEY AS NATION_KEY,
    n.N_NAME AS NATION_NAME,
    
    -- Region Attributes
    r.R_REGIONKEY AS REGION_KEY,
    r.R_NAME AS REGION_NAME,
    
    -- Derived Region Grouping (for analytics)
    CASE r.R_NAME
        WHEN 'AMERICA' THEN 'AMER'
        WHEN 'EUROPE' THEN 'EMEA'
        WHEN 'MIDDLE EAST' THEN 'EMEA'
        WHEN 'AFRICA' THEN 'EMEA'
        WHEN 'ASIA' THEN 'APAC'
        ELSE 'OTHER'
    END AS REGION_GROUP,
    
    -- Metadata
    GREATEST(n._LOADED_AT, r._LOADED_AT) AS _LAST_UPDATED
    
FROM RAW_DEV.RAW_TPCH.NATION_RAW n
JOIN RAW_DEV.RAW_TPCH.REGION_RAW r 
    ON n.N_REGIONKEY = r.R_REGIONKEY
WHERE n._IS_CURRENT = TRUE 
  AND r._IS_CURRENT = TRUE;

-- Apply tags
ALTER DYNAMIC TABLE CURATED_DEV.CURATED_DIMENSIONS.DIM_GEOGRAPHY
    SET TAG GOVERNANCE.TAGS.CONTRACT_ID = 'curated_geography_dim_v1',
            GOVERNANCE.TAGS.DATA_CLASSIFICATION = 'PUBLIC';

-- ─────────────────────────────────────────────────────────────────────────────
-- DIMENSION: Customer
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE DYNAMIC TABLE CURATED_DEV.CURATED_DIMENSIONS.DIM_CUSTOMER
    TARGET_LAG = '1 hour'
    WAREHOUSE = TRANSFORM_WH
    COMMENT = 'Curated customer dimension with enriched attributes'
AS
SELECT
    -- Keys
    c.C_CUSTKEY AS CUSTOMER_KEY,
    c.C_CUSTKEY AS CUSTOMER_ID,
    
    -- Pseudonymized Name (for AI-safe consumption)
    SHA2(c.C_NAME, 256) AS CUSTOMER_NAME_HASH,
    
    -- Original PII (masked in semantic layer)
    c.C_NAME AS CUSTOMER_NAME,
    c.C_ADDRESS AS CUSTOMER_ADDRESS,
    c.C_PHONE AS CUSTOMER_PHONE,
    
    -- Geography
    c.C_NATIONKEY AS NATION_KEY,
    g.NATION_NAME,
    g.REGION_NAME,
    g.REGION_GROUP,
    
    -- Business Attributes
    c.C_MKTSEGMENT AS MARKET_SEGMENT,
    c.C_ACCTBAL AS ACCOUNT_BALANCE,
    
    -- Derived Segments
    CASE 
        WHEN c.C_ACCTBAL >= 8000 THEN 'PREMIUM'
        WHEN c.C_ACCTBAL >= 4000 THEN 'STANDARD'
        WHEN c.C_ACCTBAL >= 0 THEN 'BASIC'
        ELSE 'CREDIT_RISK'
    END AS CUSTOMER_TIER,
    
    -- Account Health Indicator
    CASE 
        WHEN c.C_ACCTBAL < 0 THEN 'NEGATIVE_BALANCE'
        WHEN c.C_ACCTBAL = 0 THEN 'ZERO_BALANCE'
        ELSE 'POSITIVE_BALANCE'
    END AS BALANCE_STATUS,
    
    -- Phone Country Code (derived from TPCH format)
    SUBSTRING(c.C_PHONE, 1, 2) AS PHONE_COUNTRY_CODE,
    
    -- Metadata
    c._LOADED_AT AS _SOURCE_LOADED_AT,
    c._ROW_HASH AS _SOURCE_HASH,
    c._IS_CURRENT
    
FROM RAW_DEV.RAW_TPCH.CUSTOMER_RAW c
LEFT JOIN CURATED_DEV.CURATED_DIMENSIONS.DIM_GEOGRAPHY g 
    ON c.C_NATIONKEY = g.NATION_KEY
WHERE c._IS_CURRENT = TRUE;

-- Apply tags
ALTER DYNAMIC TABLE CURATED_DEV.CURATED_DIMENSIONS.DIM_CUSTOMER
    SET TAG GOVERNANCE.TAGS.CONTRACT_ID = 'curated_customer_dim_v1',
            GOVERNANCE.TAGS.DATA_CLASSIFICATION = 'CONFIDENTIAL';

-- ─────────────────────────────────────────────────────────────────────────────
-- DIMENSION: Supplier
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE DYNAMIC TABLE CURATED_DEV.CURATED_DIMENSIONS.DIM_SUPPLIER
    TARGET_LAG = '1 hour'
    WAREHOUSE = TRANSFORM_WH
    COMMENT = 'Curated supplier dimension with enriched attributes'
AS
SELECT
    -- Keys
    s.S_SUPPKEY AS SUPPLIER_KEY,
    s.S_SUPPKEY AS SUPPLIER_ID,
    
    -- Supplier Attributes
    s.S_NAME AS SUPPLIER_NAME,
    s.S_ADDRESS AS SUPPLIER_ADDRESS,
    s.S_PHONE AS SUPPLIER_PHONE,
    
    -- Geography
    s.S_NATIONKEY AS NATION_KEY,
    g.NATION_NAME,
    g.REGION_NAME,
    g.REGION_GROUP,
    
    -- Financial
    s.S_ACCTBAL AS ACCOUNT_BALANCE,
    
    -- Derived Attributes
    CASE 
        WHEN s.S_ACCTBAL >= 7500 THEN 'TIER_1'
        WHEN s.S_ACCTBAL >= 5000 THEN 'TIER_2'
        WHEN s.S_ACCTBAL >= 2500 THEN 'TIER_3'
        ELSE 'TIER_4'
    END AS SUPPLIER_TIER,
    
    -- Metadata
    s._LOADED_AT AS _SOURCE_LOADED_AT,
    s._IS_CURRENT
    
FROM RAW_DEV.RAW_TPCH.SUPPLIER_RAW s
LEFT JOIN CURATED_DEV.CURATED_DIMENSIONS.DIM_GEOGRAPHY g 
    ON s.S_NATIONKEY = g.NATION_KEY
WHERE s._IS_CURRENT = TRUE;

-- Apply tags
ALTER DYNAMIC TABLE CURATED_DEV.CURATED_DIMENSIONS.DIM_SUPPLIER
    SET TAG GOVERNANCE.TAGS.CONTRACT_ID = 'curated_supplier_dim_v1',
            GOVERNANCE.TAGS.DATA_CLASSIFICATION = 'CONFIDENTIAL';

-- ─────────────────────────────────────────────────────────────────────────────
-- DIMENSION: Part (Product)
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE DYNAMIC TABLE CURATED_DEV.CURATED_DIMENSIONS.DIM_PART
    TARGET_LAG = '1 hour'
    WAREHOUSE = TRANSFORM_WH
    COMMENT = 'Curated part/product dimension'
AS
SELECT
    -- Keys
    p.P_PARTKEY AS PART_KEY,
    p.P_PARTKEY AS PART_ID,
    
    -- Part Attributes
    p.P_NAME AS PART_NAME,
    p.P_MFGR AS MANUFACTURER,
    p.P_BRAND AS BRAND,
    p.P_TYPE AS PART_TYPE,
    p.P_SIZE AS PART_SIZE,
    p.P_CONTAINER AS CONTAINER_TYPE,
    p.P_RETAILPRICE AS RETAIL_PRICE,
    
    -- Derived Categories (parse from TPCH part type)
    SPLIT_PART(p.P_TYPE, ' ', 1) AS FINISH_TYPE,
    SPLIT_PART(p.P_TYPE, ' ', -1) AS MATERIAL_TYPE,
    
    -- Size Categories
    CASE 
        WHEN p.P_SIZE <= 10 THEN 'SMALL'
        WHEN p.P_SIZE <= 25 THEN 'MEDIUM'
        WHEN p.P_SIZE <= 40 THEN 'LARGE'
        ELSE 'EXTRA_LARGE'
    END AS SIZE_CATEGORY,
    
    -- Price Tier
    CASE 
        WHEN p.P_RETAILPRICE >= 1500 THEN 'PREMIUM'
        WHEN p.P_RETAILPRICE >= 1000 THEN 'STANDARD'
        ELSE 'ECONOMY'
    END AS PRICE_TIER,
    
    -- Metadata
    p._LOADED_AT AS _SOURCE_LOADED_AT,
    p._IS_CURRENT
    
FROM RAW_DEV.RAW_TPCH.PART_RAW p
WHERE p._IS_CURRENT = TRUE;

-- Apply tags
ALTER DYNAMIC TABLE CURATED_DEV.CURATED_DIMENSIONS.DIM_PART
    SET TAG GOVERNANCE.TAGS.CONTRACT_ID = 'curated_part_dim_v1',
            GOVERNANCE.TAGS.DATA_CLASSIFICATION = 'INTERNAL';

-- ─────────────────────────────────────────────────────────────────────────────
-- DIMENSION: Date (Generated)
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE TABLE CURATED_DEV.CURATED_DIMENSIONS.DIM_DATE AS
WITH date_spine AS (
    SELECT DATEADD(DAY, SEQ4(), '1992-01-01')::DATE AS DATE_KEY
    FROM TABLE(GENERATOR(ROWCOUNT => 10000))
)
SELECT
    DATE_KEY,
    DATE_KEY AS FULL_DATE,
    YEAR(DATE_KEY) AS YEAR,
    QUARTER(DATE_KEY) AS QUARTER,
    MONTH(DATE_KEY) AS MONTH,
    MONTHNAME(DATE_KEY) AS MONTH_NAME,
    WEEK(DATE_KEY) AS WEEK_OF_YEAR,
    DAYOFWEEK(DATE_KEY) AS DAY_OF_WEEK,
    DAYNAME(DATE_KEY) AS DAY_NAME,
    DAYOFMONTH(DATE_KEY) AS DAY_OF_MONTH,
    DAYOFYEAR(DATE_KEY) AS DAY_OF_YEAR,
    
    -- Fiscal Year (assuming Jan start)
    YEAR(DATE_KEY) AS FISCAL_YEAR,
    QUARTER(DATE_KEY) AS FISCAL_QUARTER,
    
    -- Flags
    CASE WHEN DAYOFWEEK(DATE_KEY) IN (0, 6) THEN TRUE ELSE FALSE END AS IS_WEEKEND,
    CASE WHEN MONTH(DATE_KEY) = 12 AND DAYOFMONTH(DATE_KEY) = 25 THEN TRUE ELSE FALSE END AS IS_HOLIDAY,
    
    -- Period Keys for aggregation
    TO_CHAR(DATE_KEY, 'YYYYMM')::INT AS YEAR_MONTH_KEY,
    TO_CHAR(DATE_KEY, 'YYYYQ')::VARCHAR AS YEAR_QUARTER_KEY
FROM date_spine
WHERE DATE_KEY <= '2020-12-31';

-- Apply tags
ALTER TABLE CURATED_DEV.CURATED_DIMENSIONS.DIM_DATE
    SET TAG GOVERNANCE.TAGS.DATA_CLASSIFICATION = 'PUBLIC';

-- ─────────────────────────────────────────────────────────────────────────────
-- FACT: Orders
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE DYNAMIC TABLE CURATED_DEV.CURATED_FACTS.FACT_ORDERS
    TARGET_LAG = '30 minutes'
    WAREHOUSE = TRANSFORM_WH
    COMMENT = 'Curated orders fact table'
AS
SELECT
    -- Keys
    o.O_ORDERKEY AS ORDER_KEY,
    o.O_CUSTKEY AS CUSTOMER_KEY,
    o.O_ORDERDATE AS ORDER_DATE_KEY,
    
    -- Order Attributes
    o.O_ORDERSTATUS AS ORDER_STATUS,
    CASE o.O_ORDERSTATUS
        WHEN 'O' THEN 'OPEN'
        WHEN 'F' THEN 'FULFILLED'
        WHEN 'P' THEN 'PENDING'
        ELSE 'UNKNOWN'
    END AS ORDER_STATUS_DESC,
    
    o.O_ORDERPRIORITY AS ORDER_PRIORITY,
    CASE o.O_ORDERPRIORITY
        WHEN '1-URGENT' THEN 1
        WHEN '2-HIGH' THEN 2
        WHEN '3-MEDIUM' THEN 3
        WHEN '4-NOT SPECIFIED' THEN 4
        WHEN '5-LOW' THEN 5
        ELSE 6
    END AS PRIORITY_RANK,
    
    o.O_CLERK AS CLERK_ID,
    o.O_SHIPPRIORITY AS SHIP_PRIORITY,
    
    -- Measures
    o.O_TOTALPRICE AS ORDER_TOTAL,
    
    -- Aggregated Line Item Metrics (will be computed via join or subquery in semantic layer)
    NULL::NUMBER AS LINE_ITEM_COUNT,
    
    -- Metadata
    o._LOADED_AT AS _SOURCE_LOADED_AT,
    o._IS_CURRENT
    
FROM RAW_DEV.RAW_TPCH.ORDERS_RAW o
WHERE o._IS_CURRENT = TRUE;

-- Apply tags
ALTER DYNAMIC TABLE CURATED_DEV.CURATED_FACTS.FACT_ORDERS
    SET TAG GOVERNANCE.TAGS.CONTRACT_ID = 'curated_orders_fact_v1',
            GOVERNANCE.TAGS.DATA_CLASSIFICATION = 'CONFIDENTIAL';

-- ─────────────────────────────────────────────────────────────────────────────
-- FACT: Line Items (Sales Detail)
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE DYNAMIC TABLE CURATED_DEV.CURATED_FACTS.FACT_LINEITEM
    TARGET_LAG = '30 minutes'
    WAREHOUSE = TRANSFORM_WH
    COMMENT = 'Curated line item fact table - sales detail'
AS
SELECT
    -- Keys (Composite)
    l.L_ORDERKEY AS ORDER_KEY,
    l.L_LINENUMBER AS LINE_NUMBER,
    l.L_PARTKEY AS PART_KEY,
    l.L_SUPPKEY AS SUPPLIER_KEY,
    
    -- Date Keys
    l.L_SHIPDATE AS SHIP_DATE_KEY,
    l.L_COMMITDATE AS COMMIT_DATE_KEY,
    l.L_RECEIPTDATE AS RECEIPT_DATE_KEY,
    
    -- Line Item Attributes
    l.L_RETURNFLAG AS RETURN_FLAG,
    CASE l.L_RETURNFLAG
        WHEN 'R' THEN 'RETURNED'
        WHEN 'A' THEN 'ACCEPTED'
        WHEN 'N' THEN 'NONE'
        ELSE 'UNKNOWN'
    END AS RETURN_STATUS,
    
    l.L_LINESTATUS AS LINE_STATUS,
    CASE l.L_LINESTATUS
        WHEN 'O' THEN 'OPEN'
        WHEN 'F' THEN 'FULFILLED'
        ELSE 'UNKNOWN'
    END AS LINE_STATUS_DESC,
    
    l.L_SHIPINSTRUCT AS SHIP_INSTRUCTION,
    l.L_SHIPMODE AS SHIP_MODE,
    
    -- Measures
    l.L_QUANTITY AS QUANTITY,
    l.L_EXTENDEDPRICE AS EXTENDED_PRICE,
    l.L_DISCOUNT AS DISCOUNT_PCT,
    l.L_TAX AS TAX_PCT,
    
    -- Calculated Measures
    l.L_EXTENDEDPRICE * (1 - l.L_DISCOUNT) AS DISCOUNTED_PRICE,
    l.L_EXTENDEDPRICE * (1 - l.L_DISCOUNT) * (1 + l.L_TAX) AS TOTAL_PRICE,
    l.L_EXTENDEDPRICE * l.L_DISCOUNT AS DISCOUNT_AMOUNT,
    l.L_EXTENDEDPRICE * (1 - l.L_DISCOUNT) * l.L_TAX AS TAX_AMOUNT,
    
    -- Delivery Metrics
    DATEDIFF('day', l.L_SHIPDATE, l.L_RECEIPTDATE) AS DELIVERY_DAYS,
    DATEDIFF('day', l.L_COMMITDATE, l.L_RECEIPTDATE) AS DAYS_FROM_COMMIT,
    CASE 
        WHEN l.L_RECEIPTDATE <= l.L_COMMITDATE THEN 'ON_TIME'
        ELSE 'LATE'
    END AS DELIVERY_STATUS,
    
    -- Metadata
    l._LOADED_AT AS _SOURCE_LOADED_AT,
    l._IS_CURRENT
    
FROM RAW_DEV.RAW_TPCH.LINEITEM_RAW l
WHERE l._IS_CURRENT = TRUE;

-- Apply tags
ALTER DYNAMIC TABLE CURATED_DEV.CURATED_FACTS.FACT_LINEITEM
    SET TAG GOVERNANCE.TAGS.CONTRACT_ID = 'curated_lineitem_fact_v1',
            GOVERNANCE.TAGS.DATA_CLASSIFICATION = 'CONFIDENTIAL';

-- ─────────────────────────────────────────────────────────────────────────────
-- FACT: Part-Supplier (Inventory/Supply)
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE DYNAMIC TABLE CURATED_DEV.CURATED_FACTS.FACT_PARTSUPP
    TARGET_LAG = '1 hour'
    WAREHOUSE = TRANSFORM_WH
    COMMENT = 'Curated part-supplier inventory fact'
AS
SELECT
    -- Keys
    ps.PS_PARTKEY AS PART_KEY,
    ps.PS_SUPPKEY AS SUPPLIER_KEY,
    
    -- Measures
    ps.PS_AVAILQTY AS AVAILABLE_QUANTITY,
    ps.PS_SUPPLYCOST AS SUPPLY_COST,
    
    -- Calculated
    ps.PS_AVAILQTY * ps.PS_SUPPLYCOST AS INVENTORY_VALUE,
    
    -- Metadata
    ps._LOADED_AT AS _SOURCE_LOADED_AT,
    ps._IS_CURRENT
    
FROM RAW_DEV.RAW_TPCH.PARTSUPP_RAW ps
WHERE ps._IS_CURRENT = TRUE;

-- Apply tags
ALTER DYNAMIC TABLE CURATED_DEV.CURATED_FACTS.FACT_PARTSUPP
    SET TAG GOVERNANCE.TAGS.CONTRACT_ID = 'curated_partsupp_fact_v1',
            GOVERNANCE.TAGS.DATA_CLASSIFICATION = 'INTERNAL';

-- ─────────────────────────────────────────────────────────────────────────────
-- AGGREGATED FACT: Customer Order Summary
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE DYNAMIC TABLE CURATED_DEV.CURATED_FACTS.FACT_CUSTOMER_ORDERS_SUMMARY
    TARGET_LAG = '1 hour'
    WAREHOUSE = TRANSFORM_WH
    COMMENT = 'Aggregated customer order metrics'
AS
SELECT
    -- Key
    o.CUSTOMER_KEY,
    
    -- Order Metrics
    COUNT(DISTINCT o.ORDER_KEY) AS TOTAL_ORDERS,
    SUM(o.ORDER_TOTAL) AS TOTAL_REVENUE,
    AVG(o.ORDER_TOTAL) AS AVG_ORDER_VALUE,
    MIN(o.ORDER_DATE_KEY) AS FIRST_ORDER_DATE,
    MAX(o.ORDER_DATE_KEY) AS LAST_ORDER_DATE,
    
    -- Status Breakdown
    COUNT(CASE WHEN o.ORDER_STATUS = 'O' THEN 1 END) AS OPEN_ORDERS,
    COUNT(CASE WHEN o.ORDER_STATUS = 'F' THEN 1 END) AS FULFILLED_ORDERS,
    COUNT(CASE WHEN o.ORDER_STATUS = 'P' THEN 1 END) AS PENDING_ORDERS,
    
    -- Priority Breakdown  
    COUNT(CASE WHEN o.PRIORITY_RANK <= 2 THEN 1 END) AS HIGH_PRIORITY_ORDERS,
    
    -- Line Item Metrics (from detailed fact)
    SUM(l.LINE_COUNT) AS TOTAL_LINE_ITEMS,
    SUM(l.TOTAL_QUANTITY) AS TOTAL_QUANTITY,
    SUM(l.TOTAL_DISCOUNT) AS TOTAL_DISCOUNTS,
    
    -- Tenure
    DATEDIFF('day', MIN(o.ORDER_DATE_KEY), CURRENT_DATE()) AS CUSTOMER_TENURE_DAYS,
    
    -- Recency Score (days since last order)
    DATEDIFF('day', MAX(o.ORDER_DATE_KEY), CURRENT_DATE()) AS DAYS_SINCE_LAST_ORDER,
    
    -- Activity Status
    CASE 
        WHEN DATEDIFF('day', MAX(o.ORDER_DATE_KEY), CURRENT_DATE()) <= 365 THEN 'ACTIVE'
        WHEN DATEDIFF('day', MAX(o.ORDER_DATE_KEY), CURRENT_DATE()) <= 730 THEN 'AT_RISK'
        ELSE 'CHURNED'
    END AS ACTIVITY_STATUS
    
FROM CURATED_DEV.CURATED_FACTS.FACT_ORDERS o
LEFT JOIN (
    SELECT 
        ORDER_KEY,
        COUNT(*) AS LINE_COUNT,
        SUM(QUANTITY) AS TOTAL_QUANTITY,
        SUM(DISCOUNT_AMOUNT) AS TOTAL_DISCOUNT
    FROM CURATED_DEV.CURATED_FACTS.FACT_LINEITEM
    WHERE _IS_CURRENT = TRUE
    GROUP BY ORDER_KEY
) l ON o.ORDER_KEY = l.ORDER_KEY
WHERE o._IS_CURRENT = TRUE
GROUP BY o.CUSTOMER_KEY;

-- Apply tags
ALTER DYNAMIC TABLE CURATED_DEV.CURATED_FACTS.FACT_CUSTOMER_ORDERS_SUMMARY
    SET TAG GOVERNANCE.TAGS.CONTRACT_ID = 'curated_customer_summary_v1',
            GOVERNANCE.TAGS.DATA_CLASSIFICATION = 'CONFIDENTIAL';

-- ─────────────────────────────────────────────────────────────────────────────
-- VERIFICATION
-- ─────────────────────────────────────────────────────────────────────────────

SELECT 'Curated Layer Dynamic Tables Created Successfully' AS STATUS;

SHOW DYNAMIC TABLES IN DATABASE CURATED_DEV;

-- Check refresh status
SELECT 
    NAME,
    SCHEMA_NAME,
    TARGET_LAG,
    REFRESH_MODE,
    SCHEDULING_STATE
FROM INFORMATION_SCHEMA.DYNAMIC_TABLES
WHERE DATABASE_NAME = 'CURATED_DEV';

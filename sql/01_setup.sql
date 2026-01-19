-- ============================================================================
-- DATA CONTRACTS DEMO - INITIAL SETUP
-- ============================================================================
-- This script creates ALL foundational objects for the demo:
--   1. Roles and role hierarchy
--   2. Warehouses
--   3. Databases and schemas
--   4. Governance tags
--
-- OWNERSHIP: DATA_ADMIN owns all objects (not ACCOUNTADMIN)
-- RUN AS: ACCOUNTADMIN (only script that needs this)
-- ============================================================================

-- ═══════════════════════════════════════════════════════════════════════════
-- PART 1: ROLES AND HIERARCHY
-- ═══════════════════════════════════════════════════════════════════════════

USE ROLE ACCOUNTADMIN;

-- ─────────────────────────────────────────────────────────────────────────────
-- ROLE HIERARCHY
-- ─────────────────────────────────────────────────────────────────────────────
-- 
--                        ACCOUNTADMIN
--                             │
--                        DATA_ADMIN  ◄── Owns all demo objects
--                             │
--         ┌───────────────────┼───────────────────┐
--         │                   │                   │
--    DATA_ENGINEER      DATA_STEWARD        PII_VIEWER
--         │                   │                   │
--         │              ┌────┴────┐              │
--         │              │         │              │
--         └──────►  DATA_ANALYST  AI_AGENT  ◄─────┘
--                        │         │
--                        └────┬────┘
--                             │
--                        BI_VIEWER
--
-- ─────────────────────────────────────────────────────────────────────────────

-- DATA_ADMIN: Full administrative access - OWNS ALL DEMO OBJECTS
CREATE ROLE IF NOT EXISTS DATA_ADMIN
    COMMENT = 'Full administrative access to all data layers and governance objects. Owns all demo objects.';

-- DATA_ENGINEER: Manages RAW and CURATED layers, creates pipelines
CREATE ROLE IF NOT EXISTS DATA_ENGINEER
    COMMENT = 'Manages data pipelines, RAW and CURATED layers. Can modify tables and create dynamic tables.';

-- DATA_STEWARD: Manages contracts, governance, and observability
CREATE ROLE IF NOT EXISTS DATA_STEWARD
    COMMENT = 'Manages data contracts, governance tags, quality rules, and monitors SLA compliance.';

-- PII_VIEWER: Special role that can see unmasked PII
CREATE ROLE IF NOT EXISTS PII_VIEWER
    COMMENT = 'Privileged role that can view unmasked PII data. Requires special approval.';

-- DATA_ANALYST: Consumes semantic layer for BI and analytics
CREATE ROLE IF NOT EXISTS DATA_ANALYST
    COMMENT = 'Consumes semantic views for BI and analytics. PII is masked. Can use Cortex Analyst.';

-- AI_AGENT: Machine/service account role for AI workloads
CREATE ROLE IF NOT EXISTS AI_AGENT
    COMMENT = 'Service account role for AI/ML workloads. Only accesses AI-eligible data with pseudonymized PII.';

-- BI_VIEWER: Read-only access to dashboards and pre-built reports
CREATE ROLE IF NOT EXISTS BI_VIEWER
    COMMENT = 'Read-only access to semantic views and dashboards. Most restricted data access.';

-- ─────────────────────────────────────────────────────────────────────────────
-- ROLE HIERARCHY GRANTS
-- ─────────────────────────────────────────────────────────────────────────────

GRANT ROLE DATA_ADMIN TO ROLE ACCOUNTADMIN;
GRANT ROLE DATA_ENGINEER TO ROLE DATA_ADMIN;
GRANT ROLE DATA_STEWARD TO ROLE DATA_ADMIN;
GRANT ROLE PII_VIEWER TO ROLE DATA_ADMIN;
GRANT ROLE DATA_ANALYST TO ROLE DATA_STEWARD;
GRANT ROLE AI_AGENT TO ROLE DATA_STEWARD;
GRANT ROLE BI_VIEWER TO ROLE DATA_ANALYST;

-- Grant CREATE privileges to DATA_ADMIN so it can own objects
GRANT CREATE DATABASE ON ACCOUNT TO ROLE DATA_ADMIN;
GRANT CREATE WAREHOUSE ON ACCOUNT TO ROLE DATA_ADMIN;

-- ═══════════════════════════════════════════════════════════════════════════
-- PART 2: WAREHOUSES (Created by DATA_ADMIN)
-- ═══════════════════════════════════════════════════════════════════════════

USE ROLE DATA_ADMIN;

CREATE WAREHOUSE IF NOT EXISTS INGEST_WH
    WAREHOUSE_SIZE = 'SMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    COMMENT = 'Warehouse for data ingestion workloads';

CREATE WAREHOUSE IF NOT EXISTS TRANSFORM_WH
    WAREHOUSE_SIZE = 'SMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    COMMENT = 'Warehouse for transformation workloads';

CREATE WAREHOUSE IF NOT EXISTS ANALYTICS_WH
    WAREHOUSE_SIZE = 'SMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    COMMENT = 'Warehouse for analytics queries';

-- Grant warehouse access to roles
GRANT USAGE ON WAREHOUSE INGEST_WH TO ROLE DATA_ENGINEER;
GRANT USAGE ON WAREHOUSE TRANSFORM_WH TO ROLE DATA_ENGINEER;
GRANT USAGE ON WAREHOUSE ANALYTICS_WH TO ROLE DATA_ENGINEER;
GRANT USAGE ON WAREHOUSE ANALYTICS_WH TO ROLE DATA_STEWARD;
GRANT USAGE ON WAREHOUSE ANALYTICS_WH TO ROLE PII_VIEWER;
GRANT USAGE ON WAREHOUSE ANALYTICS_WH TO ROLE DATA_ANALYST;
GRANT USAGE ON WAREHOUSE ANALYTICS_WH TO ROLE AI_AGENT;
GRANT USAGE ON WAREHOUSE ANALYTICS_WH TO ROLE BI_VIEWER;

-- Use transform warehouse for setup
USE WAREHOUSE TRANSFORM_WH;

-- ═══════════════════════════════════════════════════════════════════════════
-- PART 3: DATABASES (Created/Owned by DATA_ADMIN)
-- ═══════════════════════════════════════════════════════════════════════════

-- GOVERNANCE database - contracts, observability, tags
CREATE DATABASE IF NOT EXISTS GOVERNANCE
    COMMENT = 'Data governance: contracts, observability, and policy tags';

-- RAW layer - ingestion and current record management
CREATE DATABASE IF NOT EXISTS RAW_DEV
    COMMENT = 'Raw data layer - ingestion and current record management';

-- CURATED layer - transformed and business-ready data
CREATE DATABASE IF NOT EXISTS CURATED_DEV
    COMMENT = 'Curated layer - transformed and business-ready data using Dynamic Tables';

-- SEMANTIC layer - consumer-facing views and Cortex models
CREATE DATABASE IF NOT EXISTS SEM_DEV
    COMMENT = 'Semantic layer - consumer-facing views and Cortex models';

-- ═══════════════════════════════════════════════════════════════════════════
-- PART 4: SCHEMAS
-- ═══════════════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────────────────────
-- GOVERNANCE SCHEMAS
-- ─────────────────────────────────────────────────────────────────────────────

CREATE SCHEMA IF NOT EXISTS GOVERNANCE.CONTRACT_REGISTRY
    COMMENT = 'Contract definitions, versions, and metadata';

CREATE SCHEMA IF NOT EXISTS GOVERNANCE.OBSERVABILITY
    COMMENT = 'Monitoring views and dashboards for contract health';

CREATE SCHEMA IF NOT EXISTS GOVERNANCE.TAGS
    COMMENT = 'Governance tag definitions';

-- ─────────────────────────────────────────────────────────────────────────────
-- RAW LAYER SCHEMAS
-- ─────────────────────────────────────────────────────────────────────────────

CREATE SCHEMA IF NOT EXISTS RAW_DEV.RAW_TPCH
    COMMENT = 'TPCH raw data from Snowflake sample database';

CREATE SCHEMA IF NOT EXISTS RAW_DEV.RAW_TPCH_HISTORY
    COMMENT = 'TPCH historical records for SCD Type 2';

-- ─────────────────────────────────────────────────────────────────────────────
-- CURATED LAYER SCHEMAS
-- ─────────────────────────────────────────────────────────────────────────────

CREATE SCHEMA IF NOT EXISTS CURATED_DEV.CURATED_DIMENSIONS
    COMMENT = 'Curated dimension tables';

CREATE SCHEMA IF NOT EXISTS CURATED_DEV.CURATED_FACTS
    COMMENT = 'Curated fact tables';

-- ─────────────────────────────────────────────────────────────────────────────
-- SEMANTIC LAYER SCHEMAS
-- ─────────────────────────────────────────────────────────────────────────────

CREATE SCHEMA IF NOT EXISTS SEM_DEV.SEM_SALES
    COMMENT = 'Sales analytics semantic models';

CREATE SCHEMA IF NOT EXISTS SEM_DEV.SEM_CUSTOMER
    COMMENT = 'Customer analytics semantic models';

CREATE SCHEMA IF NOT EXISTS SEM_DEV.SEM_PRODUCT
    COMMENT = 'Product analytics semantic models';

-- ═══════════════════════════════════════════════════════════════════════════
-- PART 5: GOVERNANCE TAGS
-- ═══════════════════════════════════════════════════════════════════════════

USE SCHEMA GOVERNANCE.TAGS;

-- Data Classification - Sensitivity level
CREATE TAG IF NOT EXISTS DATA_CLASSIFICATION
    ALLOWED_VALUES 'PUBLIC', 'INTERNAL', 'CONFIDENTIAL', 'RESTRICTED'
    COMMENT = 'Data classification level for sensitivity';

-- PII Type - Personal information level
CREATE TAG IF NOT EXISTS PII_TYPE
    ALLOWED_VALUES 'NONE', 'LOW', 'MODERATE', 'HIGH'
    COMMENT = 'Level of personally identifiable information';

-- AI Allowed - AI/ML eligibility
CREATE TAG IF NOT EXISTS AI_ALLOWED
    ALLOWED_VALUES 'TRUE', 'FALSE', 'PSEUDONYMIZED_ONLY', 'AGGREGATED_ONLY'
    COMMENT = 'Whether data can be used for AI/ML workloads';

-- Residency Region - Data residency requirements
CREATE TAG IF NOT EXISTS RESIDENCY_REGION
    ALLOWED_VALUES 'GLOBAL', 'ORIGIN', 'EU_ONLY', 'US_ONLY'
    COMMENT = 'Data residency requirements';

-- Contract ID - Links objects to contracts
CREATE TAG IF NOT EXISTS CONTRACT_ID
    COMMENT = 'Data contract identifier associated with this object';

-- Contract Version
CREATE TAG IF NOT EXISTS CONTRACT_VERSION
    COMMENT = 'Data contract version associated with this object';

-- ═══════════════════════════════════════════════════════════════════════════
-- PART 6: SCHEMA-LEVEL GRANTS
-- ═══════════════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────────────────────
-- DATA_ENGINEER GRANTS
-- ─────────────────────────────────────────────────────────────────────────────

GRANT USAGE ON ALL SCHEMAS IN DATABASE RAW_DEV TO ROLE DATA_ENGINEER;
GRANT USAGE ON ALL SCHEMAS IN DATABASE CURATED_DEV TO ROLE DATA_ENGINEER;
GRANT USAGE ON ALL SCHEMAS IN DATABASE SEM_DEV TO ROLE DATA_ENGINEER;
GRANT CREATE TABLE ON ALL SCHEMAS IN DATABASE RAW_DEV TO ROLE DATA_ENGINEER;
GRANT CREATE DYNAMIC TABLE ON ALL SCHEMAS IN DATABASE CURATED_DEV TO ROLE DATA_ENGINEER;
GRANT CREATE VIEW ON ALL SCHEMAS IN DATABASE SEM_DEV TO ROLE DATA_ENGINEER;

-- ─────────────────────────────────────────────────────────────────────────────
-- DATA_STEWARD GRANTS
-- ─────────────────────────────────────────────────────────────────────────────

GRANT USAGE ON ALL SCHEMAS IN DATABASE GOVERNANCE TO ROLE DATA_STEWARD;
GRANT USAGE ON ALL SCHEMAS IN DATABASE RAW_DEV TO ROLE DATA_STEWARD;
GRANT USAGE ON ALL SCHEMAS IN DATABASE CURATED_DEV TO ROLE DATA_STEWARD;
GRANT USAGE ON ALL SCHEMAS IN DATABASE SEM_DEV TO ROLE DATA_STEWARD;

-- ─────────────────────────────────────────────────────────────────────────────
-- DATA_ANALYST GRANTS
-- ─────────────────────────────────────────────────────────────────────────────

GRANT USAGE ON SCHEMA SEM_DEV.SEM_SALES TO ROLE DATA_ANALYST;
GRANT USAGE ON SCHEMA SEM_DEV.SEM_CUSTOMER TO ROLE DATA_ANALYST;
GRANT USAGE ON SCHEMA SEM_DEV.SEM_PRODUCT TO ROLE DATA_ANALYST;
GRANT USAGE ON SCHEMA GOVERNANCE.OBSERVABILITY TO ROLE DATA_ANALYST;

-- ─────────────────────────────────────────────────────────────────────────────
-- AI_AGENT GRANTS
-- ─────────────────────────────────────────────────────────────────────────────

GRANT USAGE ON SCHEMA SEM_DEV.SEM_SALES TO ROLE AI_AGENT;
GRANT USAGE ON SCHEMA SEM_DEV.SEM_CUSTOMER TO ROLE AI_AGENT;
GRANT USAGE ON SCHEMA SEM_DEV.SEM_PRODUCT TO ROLE AI_AGENT;

-- ─────────────────────────────────────────────────────────────────────────────
-- BI_VIEWER GRANTS
-- ─────────────────────────────────────────────────────────────────────────────

GRANT USAGE ON SCHEMA SEM_DEV.SEM_SALES TO ROLE BI_VIEWER;
GRANT USAGE ON SCHEMA GOVERNANCE.OBSERVABILITY TO ROLE BI_VIEWER;

-- ═══════════════════════════════════════════════════════════════════════════
-- PART 7: FUTURE GRANTS (Objects created later will auto-inherit)
-- ═══════════════════════════════════════════════════════════════════════════

-- DATA_ENGINEER future grants
GRANT SELECT, INSERT, UPDATE, DELETE ON FUTURE TABLES IN DATABASE RAW_DEV TO ROLE DATA_ENGINEER;
GRANT SELECT ON FUTURE TABLES IN DATABASE CURATED_DEV TO ROLE DATA_ENGINEER;
GRANT SELECT ON FUTURE DYNAMIC TABLES IN DATABASE CURATED_DEV TO ROLE DATA_ENGINEER;
GRANT SELECT ON FUTURE VIEWS IN DATABASE SEM_DEV TO ROLE DATA_ENGINEER;

-- DATA_STEWARD future grants
GRANT SELECT ON FUTURE TABLES IN DATABASE GOVERNANCE TO ROLE DATA_STEWARD;
GRANT SELECT, INSERT, UPDATE, DELETE ON FUTURE TABLES IN SCHEMA GOVERNANCE.CONTRACT_REGISTRY TO ROLE DATA_STEWARD;
GRANT SELECT ON FUTURE VIEWS IN DATABASE GOVERNANCE TO ROLE DATA_STEWARD;
GRANT SELECT ON FUTURE TABLES IN DATABASE RAW_DEV TO ROLE DATA_STEWARD;
GRANT SELECT ON FUTURE TABLES IN DATABASE CURATED_DEV TO ROLE DATA_STEWARD;
GRANT SELECT ON FUTURE VIEWS IN DATABASE SEM_DEV TO ROLE DATA_STEWARD;

-- DATA_ANALYST future grants
GRANT SELECT ON FUTURE VIEWS IN DATABASE SEM_DEV TO ROLE DATA_ANALYST;
GRANT SELECT ON FUTURE TABLES IN DATABASE SEM_DEV TO ROLE DATA_ANALYST;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA GOVERNANCE.OBSERVABILITY TO ROLE DATA_ANALYST;

-- AI_AGENT future grants (specific views only - granted per-object in semantic layer script)
GRANT SELECT ON FUTURE VIEWS IN SCHEMA SEM_DEV.SEM_SALES TO ROLE AI_AGENT;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA SEM_DEV.SEM_CUSTOMER TO ROLE AI_AGENT;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA SEM_DEV.SEM_PRODUCT TO ROLE AI_AGENT;

-- BI_VIEWER future grants (limited)
GRANT SELECT ON FUTURE VIEWS IN SCHEMA GOVERNANCE.OBSERVABILITY TO ROLE BI_VIEWER;

-- ═══════════════════════════════════════════════════════════════════════════
-- PART 8: DEMO USERS (Optional - Uncomment and set passwords)
-- ═══════════════════════════════════════════════════════════════════════════

/*
-- Set your demo password before uncommenting user creation
-- SET demo_password = 'YourSecurePassword123!';

USE ROLE ACCOUNTADMIN;

CREATE USER IF NOT EXISTS DEMO_DATA_ADMIN
    PASSWORD = $demo_password
    DEFAULT_ROLE = DATA_ADMIN
    DEFAULT_WAREHOUSE = ANALYTICS_WH
    MUST_CHANGE_PASSWORD = TRUE
    COMMENT = 'Demo data administrator';
GRANT ROLE DATA_ADMIN TO USER DEMO_DATA_ADMIN;

CREATE USER IF NOT EXISTS DEMO_DATA_ENGINEER
    PASSWORD = $demo_password
    DEFAULT_ROLE = DATA_ENGINEER
    DEFAULT_WAREHOUSE = TRANSFORM_WH
    MUST_CHANGE_PASSWORD = TRUE
    COMMENT = 'Demo data engineer';
GRANT ROLE DATA_ENGINEER TO USER DEMO_DATA_ENGINEER;

CREATE USER IF NOT EXISTS DEMO_DATA_STEWARD
    PASSWORD = $demo_password
    DEFAULT_ROLE = DATA_STEWARD
    DEFAULT_WAREHOUSE = ANALYTICS_WH
    MUST_CHANGE_PASSWORD = TRUE
    COMMENT = 'Demo data steward';
GRANT ROLE DATA_STEWARD TO USER DEMO_DATA_STEWARD;

CREATE USER IF NOT EXISTS DEMO_DATA_ANALYST
    PASSWORD = $demo_password
    DEFAULT_ROLE = DATA_ANALYST
    DEFAULT_WAREHOUSE = ANALYTICS_WH
    MUST_CHANGE_PASSWORD = TRUE
    COMMENT = 'Demo data analyst';
GRANT ROLE DATA_ANALYST TO USER DEMO_DATA_ANALYST;

CREATE USER IF NOT EXISTS DEMO_AI_AGENT
    PASSWORD = $demo_password
    DEFAULT_ROLE = AI_AGENT
    DEFAULT_WAREHOUSE = ANALYTICS_WH
    MUST_CHANGE_PASSWORD = TRUE
    COMMENT = 'Demo AI service account';
GRANT ROLE AI_AGENT TO USER DEMO_AI_AGENT;

CREATE USER IF NOT EXISTS DEMO_BI_VIEWER
    PASSWORD = $demo_password
    DEFAULT_ROLE = BI_VIEWER
    DEFAULT_WAREHOUSE = ANALYTICS_WH
    MUST_CHANGE_PASSWORD = TRUE
    COMMENT = 'Demo BI viewer';
GRANT ROLE BI_VIEWER TO USER DEMO_BI_VIEWER;

CREATE USER IF NOT EXISTS DEMO_PII_VIEWER
    PASSWORD = $demo_password
    DEFAULT_ROLE = PII_VIEWER
    DEFAULT_WAREHOUSE = ANALYTICS_WH
    MUST_CHANGE_PASSWORD = TRUE
    COMMENT = 'Demo PII viewer';
GRANT ROLE PII_VIEWER TO USER DEMO_PII_VIEWER;
GRANT ROLE DATA_ANALYST TO USER DEMO_PII_VIEWER;
*/

-- ═══════════════════════════════════════════════════════════════════════════
-- VERIFICATION
-- ═══════════════════════════════════════════════════════════════════════════

USE ROLE DATA_ADMIN;

SELECT '✓ Initial Setup Complete' AS STATUS;
SELECT '  All objects owned by DATA_ADMIN' AS NOTE;

-- Show what was created
SHOW ROLES LIKE 'DATA_%';
SHOW ROLES LIKE 'AI_%';
SHOW ROLES LIKE 'BI_%';
SHOW ROLES LIKE 'PII_%';
SHOW WAREHOUSES;
SHOW DATABASES LIKE '%DEV' ;
SHOW DATABASES LIKE 'GOVERNANCE';
SHOW TAGS IN SCHEMA GOVERNANCE.TAGS;

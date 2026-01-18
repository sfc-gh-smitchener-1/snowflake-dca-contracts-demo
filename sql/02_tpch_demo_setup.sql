-- ============================================================================
-- TPCH DATA CONTRACTS DEMO - ENVIRONMENT SETUP
-- ============================================================================
-- This script sets up the complete demo environment for TPCH data contracts.
-- Run as ACCOUNTADMIN or a role with appropriate privileges.
--
-- LAYERS:
--   RAW_DEV     - Raw ingestion layer with current record management
--   CURATED_DEV - Curated layer using Dynamic Tables
--   SEM_DEV     - Semantic layer for consumption (views + Cortex models)
-- ============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- CONFIGURATION
-- ─────────────────────────────────────────────────────────────────────────────

SET ENV = 'DEV';
SET WAREHOUSE = 'COMPUTE_WH';

-- ─────────────────────────────────────────────────────────────────────────────
-- DATABASE SETUP
-- ─────────────────────────────────────────────────────────────────────────────

USE ROLE ACCOUNTADMIN;

-- Create the three-layer architecture databases
CREATE DATABASE IF NOT EXISTS RAW_DEV 
    COMMENT = 'Raw data layer - ingestion and current record management';
    
CREATE DATABASE IF NOT EXISTS CURATED_DEV 
    COMMENT = 'Curated layer - transformed and business-ready data using Dynamic Tables';
    
CREATE DATABASE IF NOT EXISTS SEM_DEV 
    COMMENT = 'Semantic layer - consumer-facing views and Cortex models';

-- ─────────────────────────────────────────────────────────────────────────────
-- SCHEMA SETUP - RAW LAYER
-- ─────────────────────────────────────────────────────────────────────────────

CREATE SCHEMA IF NOT EXISTS RAW_DEV.RAW_TPCH
    COMMENT = 'TPCH raw data from Snowflake sample database';

CREATE SCHEMA IF NOT EXISTS RAW_DEV.RAW_TPCH_HISTORY
    COMMENT = 'TPCH historical records for SCD Type 2';

-- ─────────────────────────────────────────────────────────────────────────────
-- SCHEMA SETUP - CURATED LAYER
-- ─────────────────────────────────────────────────────────────────────────────

CREATE SCHEMA IF NOT EXISTS CURATED_DEV.CURATED_DIMENSIONS
    COMMENT = 'Curated dimension tables';
    
CREATE SCHEMA IF NOT EXISTS CURATED_DEV.CURATED_FACTS
    COMMENT = 'Curated fact tables';

-- ─────────────────────────────────────────────────────────────────────────────
-- SCHEMA SETUP - SEMANTIC LAYER
-- ─────────────────────────────────────────────────────────────────────────────

CREATE SCHEMA IF NOT EXISTS SEM_DEV.SEM_SALES
    COMMENT = 'Sales analytics semantic models';
    
CREATE SCHEMA IF NOT EXISTS SEM_DEV.SEM_CUSTOMER
    COMMENT = 'Customer analytics semantic models';
    
CREATE SCHEMA IF NOT EXISTS SEM_DEV.SEM_PRODUCT
    COMMENT = 'Product analytics semantic models';

-- ─────────────────────────────────────────────────────────────────────────────
-- GOVERNANCE TAGS SETUP
-- ─────────────────────────────────────────────────────────────────────────────

-- Create tag database if not exists
CREATE DATABASE IF NOT EXISTS GOVERNANCE;
CREATE SCHEMA IF NOT EXISTS GOVERNANCE.TAGS;

-- Data Classification Tags
CREATE TAG IF NOT EXISTS GOVERNANCE.TAGS.DATA_CLASSIFICATION
    ALLOWED_VALUES 'PUBLIC', 'INTERNAL', 'CONFIDENTIAL', 'RESTRICTED'
    COMMENT = 'Data classification level for sensitivity';

-- PII Type Tags
CREATE TAG IF NOT EXISTS GOVERNANCE.TAGS.PII_TYPE
    ALLOWED_VALUES 'NONE', 'LOW', 'MODERATE', 'HIGH'
    COMMENT = 'Level of personally identifiable information';

-- AI Allowed Tags
CREATE TAG IF NOT EXISTS GOVERNANCE.TAGS.AI_ALLOWED
    ALLOWED_VALUES 'TRUE', 'FALSE', 'PSEUDONYMIZED_ONLY', 'AGGREGATED_ONLY'
    COMMENT = 'Whether data can be used for AI/ML workloads';

-- Residency Region Tags
CREATE TAG IF NOT EXISTS GOVERNANCE.TAGS.RESIDENCY_REGION
    ALLOWED_VALUES 'GLOBAL', 'ORIGIN', 'EU_ONLY', 'US_ONLY'
    COMMENT = 'Data residency requirements';

-- Contract ID Tag (for linking objects to contracts)
CREATE TAG IF NOT EXISTS GOVERNANCE.TAGS.CONTRACT_ID
    COMMENT = 'Data contract identifier associated with this object';

-- Contract Version Tag
CREATE TAG IF NOT EXISTS GOVERNANCE.TAGS.CONTRACT_VERSION
    COMMENT = 'Data contract version associated with this object';

-- ─────────────────────────────────────────────────────────────────────────────
-- WAREHOUSE SETUP
-- ─────────────────────────────────────────────────────────────────────────────

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

-- ─────────────────────────────────────────────────────────────────────────────
-- VERIFICATION
-- ─────────────────────────────────────────────────────────────────────────────

SELECT 'TPCH Demo Environment Setup Complete' AS STATUS;

SHOW DATABASES LIKE '%_DEV';
SHOW SCHEMAS IN DATABASE RAW_DEV;
SHOW SCHEMAS IN DATABASE CURATED_DEV;
SHOW SCHEMAS IN DATABASE SEM_DEV;
SHOW TAGS IN SCHEMA GOVERNANCE.TAGS;

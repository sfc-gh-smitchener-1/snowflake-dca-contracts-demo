-- ============================================================================
-- SNOWFLAKE DATA CONTRACTS DEMO - FULL SETUP SCRIPT
-- ============================================================================
-- 
-- This is the master script to set up the complete Data Contracts demo.
-- Run this script in Snowflake as ACCOUNTADMIN to deploy the full solution.
--
-- WHAT THIS DEMO INCLUDES:
-- ========================
-- 1. Three-layer architecture (RAW → CURATED → SEMANTIC)
-- 2. Data contracts with governance tags
-- 3. Contract validation and enforcement
-- 4. Dynamic tables for automated transformation
-- 5. Semantic models for Cortex and AI workloads
-- 6. Observability dashboard for contract adherence
-- 7. Generic contract generator for any dataset
--
-- DEMO DATA:
-- ==========
-- Uses TPCH sample data from SNOWFLAKE_SAMPLE_DATA database
-- (Available in all Snowflake accounts)
--
-- EXECUTION ORDER:
-- ================
-- Run scripts in numbered order, or execute this file to run all
--
-- ============================================================================

-- ═══════════════════════════════════════════════════════════════════════════
-- PRE-FLIGHT CHECKS
-- ═══════════════════════════════════════════════════════════════════════════

USE ROLE ACCOUNTADMIN;

-- Verify sample data access
SELECT 'TPCH Sample Data Check' AS CHECK_NAME,
       COUNT(*) AS ROW_COUNT,
       CASE WHEN COUNT(*) > 0 THEN '✅ PASS' ELSE '❌ FAIL' END AS STATUS
FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.CUSTOMER
LIMIT 1;

-- ═══════════════════════════════════════════════════════════════════════════
-- STEP 1: Contract Registry Setup (from 01_contract_registry_setup.sql)
-- ═══════════════════════════════════════════════════════════════════════════

!print '=== STEP 1: Setting up Contract Registry ===';

-- Run the contract registry setup
-- NOTE: In actual execution, you would run each script file

-- ═══════════════════════════════════════════════════════════════════════════
-- STEP 2: TPCH Demo Environment Setup (from 02_tpch_demo_setup.sql)
-- ═══════════════════════════════════════════════════════════════════════════

!print '=== STEP 2: Creating Demo Environment ===';

-- Create databases for three-layer architecture
CREATE DATABASE IF NOT EXISTS RAW_DEV COMMENT = 'Raw data layer';
CREATE DATABASE IF NOT EXISTS CURATED_DEV COMMENT = 'Curated data layer';
CREATE DATABASE IF NOT EXISTS SEM_DEV COMMENT = 'Semantic layer';
CREATE DATABASE IF NOT EXISTS GOVERNANCE COMMENT = 'Governance and contracts';

-- Create schemas
CREATE SCHEMA IF NOT EXISTS RAW_DEV.RAW_TPCH;
CREATE SCHEMA IF NOT EXISTS CURATED_DEV.CURATED_DIMENSIONS;
CREATE SCHEMA IF NOT EXISTS CURATED_DEV.CURATED_FACTS;
CREATE SCHEMA IF NOT EXISTS SEM_DEV.SEM_SALES;
CREATE SCHEMA IF NOT EXISTS SEM_DEV.SEM_CUSTOMER;
CREATE SCHEMA IF NOT EXISTS SEM_DEV.SEM_PRODUCT;
CREATE SCHEMA IF NOT EXISTS GOVERNANCE.CONTRACT_REGISTRY;
CREATE SCHEMA IF NOT EXISTS GOVERNANCE.OBSERVABILITY;
CREATE SCHEMA IF NOT EXISTS GOVERNANCE.TAGS;

-- Create governance tags
CREATE TAG IF NOT EXISTS GOVERNANCE.TAGS.DATA_CLASSIFICATION
    ALLOWED_VALUES 'PUBLIC', 'INTERNAL', 'CONFIDENTIAL', 'RESTRICTED';
CREATE TAG IF NOT EXISTS GOVERNANCE.TAGS.PII_TYPE
    ALLOWED_VALUES 'NONE', 'LOW', 'MODERATE', 'HIGH';
CREATE TAG IF NOT EXISTS GOVERNANCE.TAGS.AI_ALLOWED
    ALLOWED_VALUES 'TRUE', 'FALSE', 'PSEUDONYMIZED_ONLY', 'AGGREGATED_ONLY';
CREATE TAG IF NOT EXISTS GOVERNANCE.TAGS.RESIDENCY_REGION
    ALLOWED_VALUES 'GLOBAL', 'ORIGIN', 'EU_ONLY', 'US_ONLY';
CREATE TAG IF NOT EXISTS GOVERNANCE.TAGS.CONTRACT_ID;
CREATE TAG IF NOT EXISTS GOVERNANCE.TAGS.CONTRACT_VERSION;

-- Create warehouses
CREATE WAREHOUSE IF NOT EXISTS TRANSFORM_WH WAREHOUSE_SIZE = 'SMALL' AUTO_SUSPEND = 60 AUTO_RESUME = TRUE;
CREATE WAREHOUSE IF NOT EXISTS ANALYTICS_WH WAREHOUSE_SIZE = 'SMALL' AUTO_SUSPEND = 60 AUTO_RESUME = TRUE;

-- ═══════════════════════════════════════════════════════════════════════════
-- STEP 3: Execute remaining setup scripts
-- ═══════════════════════════════════════════════════════════════════════════

!print '=== STEP 3: Run the following scripts in order ===';
!print '';
!print '  1. 03_raw_layer_tables.sql      - Create RAW layer tables';
!print '  2. 04_direct_load_tpch.sql      - Load TPCH data';
!print '  3. 05_curated_layer_dynamic_tables.sql - Create Dynamic Tables';
!print '  4. 06_semantic_layer.sql        - Create Semantic Views';
!print '  5. 07_contract_validation.sql   - Validation Procedures';
!print '  6. 08_observability_dashboard.sql - Observability Views';
!print '  7. 09_contract_generator_proc.sql - Contract Generator';
!print '  8. 10_roles_and_users.sql       - Access Control Setup';
!print '';

-- ═══════════════════════════════════════════════════════════════════════════
-- QUICK VERIFICATION QUERIES
-- ═══════════════════════════════════════════════════════════════════════════

-- Check databases created
SELECT 'Databases' AS CHECK_TYPE, DATABASE_NAME 
FROM INFORMATION_SCHEMA.DATABASES 
WHERE DATABASE_NAME IN ('RAW_DEV', 'CURATED_DEV', 'SEM_DEV', 'GOVERNANCE');

-- Check tags created
SHOW TAGS IN SCHEMA GOVERNANCE.TAGS;

!print '=== Demo Environment Base Setup Complete ===';
!print '';
!print 'Next Steps:';
!print '1. Run each SQL script in this folder in numbered order (01-09)';
!print '2. Register contracts from ../contracts/data/*.yml files';
!print '3. Validate contracts using the validation procedures';
!print '4. Query observability views for contract health';

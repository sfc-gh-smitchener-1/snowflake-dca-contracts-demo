-- ============================================================================
-- SNOWFLAKE DATA CONTRACTS DEMO - EXECUTION GUIDE
-- ============================================================================
-- 
-- This file documents the execution order for the complete demo.
-- Run scripts individually in the order shown below.
--
-- DEMO OVERVIEW:
-- ==============
-- 1. Three-layer architecture (RAW → CURATED → SEMANTIC)
-- 2. Data contracts with governance tags
-- 3. Contract validation and enforcement
-- 4. Dynamic tables for automated transformation
-- 5. Semantic models for Cortex Analyst
-- 6. Observability dashboard for contract adherence
-- 7. Role-based access control
--
-- DEMO DATA:
-- ==========
-- Uses TPCH sample data from SNOWFLAKE_SAMPLE_DATA database
--
-- ============================================================================

-- ═══════════════════════════════════════════════════════════════════════════
-- EXECUTION ORDER
-- ═══════════════════════════════════════════════════════════════════════════

/*
SCRIPT EXECUTION ORDER:
=======================

Step 1: 01_setup.sql (RUN AS ACCOUNTADMIN)
        - Creates roles (DATA_ADMIN, DATA_ENGINEER, etc.)
        - Creates warehouses (owned by DATA_ADMIN)
        - Creates databases and schemas
        - Creates governance tags
        - Sets up future grants
        
Step 2: 02_contract_registry.sql (RUN AS DATA_ADMIN)
        - Creates contract registry tables
        - Creates views and procedures
        
Step 3: 03_raw_layer_tables.sql (RUN AS DATA_ADMIN)
        - Creates RAW layer tables with contract-enforced schemas
        - Applies governance tags
        
Step 4: 04_direct_load_tpch.sql (RUN AS DATA_ADMIN)
        - Creates load procedures
        - Loads TPCH data from sample database
        
Step 5: 05_curated_layer_dynamic_tables.sql (RUN AS DATA_ADMIN)
        - Creates dynamic tables for dimensions and facts
        - Automated transformation pipeline
        
Step 6: 06_semantic_layer.sql (RUN AS DATA_ADMIN)
        - Creates semantic views
        - Sets up Cortex Analyst stage
        
Step 7: 07_contract_validation.sql (RUN AS DATA_ADMIN)
        - Creates validation procedures
        - SLA monitoring
        
Step 8: 08_observability_dashboard.sql (RUN AS DATA_ADMIN)
        - Creates monitoring views
        - Dashboard KPIs
        
Step 9: 09_contract_generator_proc.sql (RUN AS DATA_ADMIN)
        - Utility to generate contracts from existing tables
        
Step 10: 11_demo_sample_data.sql (RUN AS DATA_ADMIN)
         - Loads sample data for observability demo
         
CLEANUP:
========
99_cleanup_demo.sql - Removes all demo objects (RUN AS ACCOUNTADMIN)

*/

-- ═══════════════════════════════════════════════════════════════════════════
-- PRE-FLIGHT CHECK
-- ═══════════════════════════════════════════════════════════════════════════

USE ROLE ACCOUNTADMIN;

-- Verify sample data access
SELECT 'TPCH Sample Data Check' AS CHECK_NAME,
       COUNT(*) AS ROW_COUNT,
       CASE WHEN COUNT(*) > 0 THEN '✓ PASS' ELSE '✗ FAIL' END AS STATUS
FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.CUSTOMER
LIMIT 1;

-- ═══════════════════════════════════════════════════════════════════════════
-- QUICK REFERENCE - ROLE HIERARCHY
-- ═══════════════════════════════════════════════════════════════════════════

/*
                        ACCOUNTADMIN
                             │
                        DATA_ADMIN  ◄── Owns all demo objects
                             │
         ┌───────────────────┼───────────────────┐
         │                   │                   │
    DATA_ENGINEER      DATA_STEWARD        PII_VIEWER
         │                   │                   │
         │              ┌────┴────┐              │
         │              │         │              │
         └──────►  DATA_ANALYST  AI_AGENT  ◄─────┘
                        │         │
                        └────┬────┘
                             │
                        BI_VIEWER

ROLE DESCRIPTIONS:
==================
DATA_ADMIN     - Full access, owns all objects
DATA_ENGINEER  - RAW/CURATED read/write, creates pipelines
DATA_STEWARD   - Governance management, contract validation
PII_VIEWER     - Can see unmasked PII (special privilege)
DATA_ANALYST   - Semantic layer access, BI queries
AI_AGENT       - AI-safe views only, for ML workloads
BI_VIEWER      - Summary views only, most restricted

*/

SELECT 'Run scripts 01-11 in order. Start with: 01_setup.sql' AS NEXT_STEP;

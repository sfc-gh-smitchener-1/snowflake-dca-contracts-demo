-- ============================================================================
-- CLEANUP SCRIPT - Remove All Demo Objects
-- ============================================================================
-- This script removes all objects created by the demo.
-- Run this to reset your environment before re-running the setup.
--
-- WARNING: This will permanently delete all demo databases and objects!
-- ============================================================================

USE ROLE ACCOUNTADMIN;

-- ─────────────────────────────────────────────────────────────────────────────
-- CONFIRM CLEANUP (Comment out this section to run automatically)
-- ─────────────────────────────────────────────────────────────────────────────

SELECT '⚠️  WARNING: This will delete all demo databases and objects!' AS MESSAGE;
SELECT 'To proceed, comment out lines 14-17 and re-run this script.' AS INSTRUCTION;

-- Uncomment the line below to skip the safety check
-- SET CONFIRM_CLEANUP = TRUE;

-- ─────────────────────────────────────────────────────────────────────────────
-- DROP TASKS (Must be done before dropping schemas)
-- ─────────────────────────────────────────────────────────────────────────────

-- Suspend tasks first to avoid errors
ALTER TASK IF EXISTS GOVERNANCE.OBSERVABILITY.TASK_GENERATE_ALERTS SUSPEND;
ALTER TASK IF EXISTS GOVERNANCE.CONTRACT_REGISTRY.TASK_HOURLY_VALIDATION SUSPEND;

-- Drop tasks
DROP TASK IF EXISTS GOVERNANCE.OBSERVABILITY.TASK_GENERATE_ALERTS;
DROP TASK IF EXISTS GOVERNANCE.CONTRACT_REGISTRY.TASK_HOURLY_VALIDATION;

-- ─────────────────────────────────────────────────────────────────────────────
-- DROP DEMO USERS (Created by 10_roles_and_users.sql)
-- ─────────────────────────────────────────────────────────────────────────────

DROP USER IF EXISTS DEMO_DATA_ADMIN;
DROP USER IF EXISTS DEMO_DATA_ENGINEER;
DROP USER IF EXISTS DEMO_DATA_STEWARD;
DROP USER IF EXISTS DEMO_DATA_ANALYST;
DROP USER IF EXISTS DEMO_BI_VIEWER;
DROP USER IF EXISTS DEMO_AI_AGENT;
DROP USER IF EXISTS DEMO_PII_VIEWER;

-- ─────────────────────────────────────────────────────────────────────────────
-- DROP DEMO ROLES (Created in 01_setup.sql)
-- ─────────────────────────────────────────────────────────────────────────────

-- Drop roles (Snowflake handles hierarchy automatically)
DROP ROLE IF EXISTS BI_VIEWER;
DROP ROLE IF EXISTS AI_AGENT;
DROP ROLE IF EXISTS DATA_ANALYST;
DROP ROLE IF EXISTS PII_VIEWER;
DROP ROLE IF EXISTS DATA_STEWARD;
DROP ROLE IF EXISTS DATA_ENGINEER;
DROP ROLE IF EXISTS DATA_ADMIN;

-- ─────────────────────────────────────────────────────────────────────────────
-- DROP WAREHOUSES
-- ─────────────────────────────────────────────────────────────────────────────

DROP WAREHOUSE IF EXISTS INGEST_WH;
DROP WAREHOUSE IF EXISTS TRANSFORM_WH;
DROP WAREHOUSE IF EXISTS ANALYTICS_WH;

-- ─────────────────────────────────────────────────────────────────────────────
-- DROP DATABASES (This removes all schemas, tables, views, stages, etc.)
-- ─────────────────────────────────────────────────────────────────────────────

-- Drop demo databases
DROP DATABASE IF EXISTS RAW_DEV CASCADE;
DROP DATABASE IF EXISTS CURATED_DEV CASCADE;
DROP DATABASE IF EXISTS SEM_DEV CASCADE;
DROP DATABASE IF EXISTS GOVERNANCE CASCADE;

-- ─────────────────────────────────────────────────────────────────────────────
-- VERIFICATION
-- ─────────────────────────────────────────────────────────────────────────────

SELECT '✓ Cleanup Complete!' AS STATUS;

-- Verify databases are gone (use SHOW instead of INFORMATION_SCHEMA since no current database)
SHOW DATABASES LIKE 'RAW_DEV';
SHOW DATABASES LIKE 'CURATED_DEV';
SHOW DATABASES LIKE 'SEM_DEV';
SHOW DATABASES LIKE 'GOVERNANCE';

-- Verify warehouses are gone
SHOW WAREHOUSES LIKE '%_WH';

-- Verify roles are gone
SHOW ROLES LIKE 'DATA_%';
SHOW ROLES LIKE 'BI_%';
SHOW ROLES LIKE 'AI_%';
SHOW ROLES LIKE 'PII_%';

SELECT 'Demo environment has been reset. You can now re-run the setup scripts.' AS NEXT_STEPS;

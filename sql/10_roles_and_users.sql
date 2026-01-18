-- ============================================================================
-- ROLES AND USERS - Access Control for Data Contracts Demo
-- ============================================================================
-- This script creates roles and users to demonstrate the complete governance
-- flow with proper access control based on the Enterprise Architecture Guide:
--
-- "Allowed Use: Who may use this data and for what purpose?"
-- "Risk Class: What protections apply?"
-- "AI Eligibility: May automation or AI consume this data?"
-- ============================================================================

USE ROLE ACCOUNTADMIN;

-- ─────────────────────────────────────────────────────────────────────────────
-- ROLE HIERARCHY
-- ─────────────────────────────────────────────────────────────────────────────
-- 
--                        ACCOUNTADMIN
--                             │
--                        DATA_ADMIN
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

-- ═══════════════════════════════════════════════════════════════════════════
-- PART 1: CREATE ROLES
-- ═══════════════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────────────────────
-- DATA_ADMIN: Full administrative access to all data and governance
-- ─────────────────────────────────────────────────────────────────────────────
CREATE ROLE IF NOT EXISTS DATA_ADMIN
    COMMENT = 'Full administrative access to all data layers and governance objects. Can view all PII.';

-- ─────────────────────────────────────────────────────────────────────────────
-- DATA_ENGINEER: Manages RAW and CURATED layers, creates pipelines
-- ─────────────────────────────────────────────────────────────────────────────
CREATE ROLE IF NOT EXISTS DATA_ENGINEER
    COMMENT = 'Manages data pipelines, RAW and CURATED layers. Can modify tables and create dynamic tables.';

-- ─────────────────────────────────────────────────────────────────────────────
-- DATA_STEWARD: Manages contracts, governance, and observability
-- ─────────────────────────────────────────────────────────────────────────────
CREATE ROLE IF NOT EXISTS DATA_STEWARD
    COMMENT = 'Manages data contracts, governance tags, quality rules, and monitors SLA compliance.';

-- ─────────────────────────────────────────────────────────────────────────────
-- PII_VIEWER: Special role that can see unmasked PII
-- ─────────────────────────────────────────────────────────────────────────────
CREATE ROLE IF NOT EXISTS PII_VIEWER
    COMMENT = 'Privileged role that can view unmasked PII data. Requires special approval.';

-- ─────────────────────────────────────────────────────────────────────────────
-- DATA_ANALYST: Consumes semantic layer for BI and analytics
-- ─────────────────────────────────────────────────────────────────────────────
CREATE ROLE IF NOT EXISTS DATA_ANALYST
    COMMENT = 'Consumes semantic views for BI and analytics. PII is masked. Can use Cortex Analyst.';

-- ─────────────────────────────────────────────────────────────────────────────
-- AI_AGENT: Machine/service account role for AI workloads
-- ─────────────────────────────────────────────────────────────────────────────
CREATE ROLE IF NOT EXISTS AI_AGENT
    COMMENT = 'Service account role for AI/ML workloads. Only accesses AI-eligible data with pseudonymized PII.';

-- ─────────────────────────────────────────────────────────────────────────────
-- BI_VIEWER: Read-only access to dashboards and pre-built reports
-- ─────────────────────────────────────────────────────────────────────────────
CREATE ROLE IF NOT EXISTS BI_VIEWER
    COMMENT = 'Read-only access to semantic views and dashboards. Most restricted data access.';

-- ═══════════════════════════════════════════════════════════════════════════
-- PART 2: ESTABLISH ROLE HIERARCHY
-- ═══════════════════════════════════════════════════════════════════════════

-- DATA_ADMIN is granted to ACCOUNTADMIN
GRANT ROLE DATA_ADMIN TO ROLE ACCOUNTADMIN;

-- DATA_ENGINEER, DATA_STEWARD, and PII_VIEWER report to DATA_ADMIN
GRANT ROLE DATA_ENGINEER TO ROLE DATA_ADMIN;
GRANT ROLE DATA_STEWARD TO ROLE DATA_ADMIN;
GRANT ROLE PII_VIEWER TO ROLE DATA_ADMIN;

-- DATA_ANALYST and AI_AGENT get privileges from DATA_STEWARD
GRANT ROLE DATA_ANALYST TO ROLE DATA_STEWARD;
GRANT ROLE AI_AGENT TO ROLE DATA_STEWARD;

-- BI_VIEWER is the most restricted, gets from DATA_ANALYST
GRANT ROLE BI_VIEWER TO ROLE DATA_ANALYST;

-- ═══════════════════════════════════════════════════════════════════════════
-- PART 3: GRANT WAREHOUSE ACCESS
-- ═══════════════════════════════════════════════════════════════════════════

-- All roles can use the analytics warehouse
GRANT USAGE ON WAREHOUSE ANALYTICS_WH TO ROLE DATA_ADMIN;
GRANT USAGE ON WAREHOUSE ANALYTICS_WH TO ROLE DATA_ENGINEER;
GRANT USAGE ON WAREHOUSE ANALYTICS_WH TO ROLE DATA_STEWARD;
GRANT USAGE ON WAREHOUSE ANALYTICS_WH TO ROLE PII_VIEWER;
GRANT USAGE ON WAREHOUSE ANALYTICS_WH TO ROLE DATA_ANALYST;
GRANT USAGE ON WAREHOUSE ANALYTICS_WH TO ROLE AI_AGENT;
GRANT USAGE ON WAREHOUSE ANALYTICS_WH TO ROLE BI_VIEWER;

-- ═══════════════════════════════════════════════════════════════════════════
-- PART 4: GRANT DATABASE AND SCHEMA ACCESS
-- ═══════════════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────────────────────
-- GOVERNANCE DATABASE (Contract Registry & Observability)
-- ─────────────────────────────────────────────────────────────────────────────

-- DATA_ADMIN: Full access
GRANT ALL ON DATABASE GOVERNANCE TO ROLE DATA_ADMIN;
GRANT ALL ON ALL SCHEMAS IN DATABASE GOVERNANCE TO ROLE DATA_ADMIN;
GRANT ALL ON ALL TABLES IN DATABASE GOVERNANCE TO ROLE DATA_ADMIN;
GRANT ALL ON ALL VIEWS IN DATABASE GOVERNANCE TO ROLE DATA_ADMIN;
GRANT ALL ON FUTURE TABLES IN DATABASE GOVERNANCE TO ROLE DATA_ADMIN;
GRANT ALL ON FUTURE VIEWS IN DATABASE GOVERNANCE TO ROLE DATA_ADMIN;

-- DATA_STEWARD: Manage contracts and governance
GRANT USAGE ON DATABASE GOVERNANCE TO ROLE DATA_STEWARD;
GRANT USAGE ON ALL SCHEMAS IN DATABASE GOVERNANCE TO ROLE DATA_STEWARD;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA GOVERNANCE.CONTRACT_REGISTRY TO ROLE DATA_STEWARD;
GRANT SELECT ON ALL VIEWS IN SCHEMA GOVERNANCE.OBSERVABILITY TO ROLE DATA_STEWARD;
GRANT USAGE ON ALL PROCEDURES IN SCHEMA GOVERNANCE.CONTRACT_REGISTRY TO ROLE DATA_STEWARD;

-- DATA_ANALYST: Read observability dashboards
GRANT USAGE ON DATABASE GOVERNANCE TO ROLE DATA_ANALYST;
GRANT USAGE ON SCHEMA GOVERNANCE.OBSERVABILITY TO ROLE DATA_ANALYST;
GRANT SELECT ON ALL VIEWS IN SCHEMA GOVERNANCE.OBSERVABILITY TO ROLE DATA_ANALYST;

-- BI_VIEWER: Read observability KPIs
GRANT USAGE ON DATABASE GOVERNANCE TO ROLE BI_VIEWER;
GRANT USAGE ON SCHEMA GOVERNANCE.OBSERVABILITY TO ROLE BI_VIEWER;
GRANT SELECT ON VIEW GOVERNANCE.OBSERVABILITY.VW_DASHBOARD_KPIS TO ROLE BI_VIEWER;
GRANT SELECT ON VIEW GOVERNANCE.OBSERVABILITY.VW_CONTRACT_HEALTH_DASHBOARD TO ROLE BI_VIEWER;

-- ─────────────────────────────────────────────────────────────────────────────
-- RAW_DEV DATABASE (Raw Data Layer)
-- ─────────────────────────────────────────────────────────────────────────────

-- DATA_ADMIN: Full access
GRANT ALL ON DATABASE RAW_DEV TO ROLE DATA_ADMIN;
GRANT ALL ON ALL SCHEMAS IN DATABASE RAW_DEV TO ROLE DATA_ADMIN;
GRANT ALL ON ALL TABLES IN DATABASE RAW_DEV TO ROLE DATA_ADMIN;
GRANT ALL ON FUTURE TABLES IN DATABASE RAW_DEV TO ROLE DATA_ADMIN;

-- DATA_ENGINEER: Manage raw tables and load data
GRANT USAGE ON DATABASE RAW_DEV TO ROLE DATA_ENGINEER;
GRANT USAGE ON ALL SCHEMAS IN DATABASE RAW_DEV TO ROLE DATA_ENGINEER;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN DATABASE RAW_DEV TO ROLE DATA_ENGINEER;
GRANT SELECT, INSERT, UPDATE, DELETE ON FUTURE TABLES IN DATABASE RAW_DEV TO ROLE DATA_ENGINEER;

-- DATA_STEWARD: Read access for validation
GRANT USAGE ON DATABASE RAW_DEV TO ROLE DATA_STEWARD;
GRANT USAGE ON ALL SCHEMAS IN DATABASE RAW_DEV TO ROLE DATA_STEWARD;
GRANT SELECT ON ALL TABLES IN DATABASE RAW_DEV TO ROLE DATA_STEWARD;

-- No direct RAW access for DATA_ANALYST, AI_AGENT, or BI_VIEWER (must use SEMANTIC layer)

-- ─────────────────────────────────────────────────────────────────────────────
-- CURATED_DEV DATABASE (Curated/Transformed Layer)
-- ─────────────────────────────────────────────────────────────────────────────

-- DATA_ADMIN: Full access
GRANT ALL ON DATABASE CURATED_DEV TO ROLE DATA_ADMIN;
GRANT ALL ON ALL SCHEMAS IN DATABASE CURATED_DEV TO ROLE DATA_ADMIN;
GRANT ALL ON ALL TABLES IN DATABASE CURATED_DEV TO ROLE DATA_ADMIN;
GRANT ALL ON ALL DYNAMIC TABLES IN DATABASE CURATED_DEV TO ROLE DATA_ADMIN;
GRANT ALL ON FUTURE TABLES IN DATABASE CURATED_DEV TO ROLE DATA_ADMIN;

-- DATA_ENGINEER: Create and manage dynamic tables
GRANT USAGE ON DATABASE CURATED_DEV TO ROLE DATA_ENGINEER;
GRANT USAGE ON ALL SCHEMAS IN DATABASE CURATED_DEV TO ROLE DATA_ENGINEER;
GRANT SELECT ON ALL TABLES IN DATABASE CURATED_DEV TO ROLE DATA_ENGINEER;
GRANT SELECT ON ALL DYNAMIC TABLES IN DATABASE CURATED_DEV TO ROLE DATA_ENGINEER;
GRANT CREATE DYNAMIC TABLE ON ALL SCHEMAS IN DATABASE CURATED_DEV TO ROLE DATA_ENGINEER;

-- DATA_STEWARD: Read access for validation
GRANT USAGE ON DATABASE CURATED_DEV TO ROLE DATA_STEWARD;
GRANT USAGE ON ALL SCHEMAS IN DATABASE CURATED_DEV TO ROLE DATA_STEWARD;
GRANT SELECT ON ALL TABLES IN DATABASE CURATED_DEV TO ROLE DATA_STEWARD;
GRANT SELECT ON ALL DYNAMIC TABLES IN DATABASE CURATED_DEV TO ROLE DATA_STEWARD;

-- No direct CURATED access for DATA_ANALYST, AI_AGENT, or BI_VIEWER (must use SEMANTIC layer)

-- ─────────────────────────────────────────────────────────────────────────────
-- SEM_DEV DATABASE (Semantic Layer - Primary Consumer Interface)
-- ─────────────────────────────────────────────────────────────────────────────

-- DATA_ADMIN: Full access
GRANT ALL ON DATABASE SEM_DEV TO ROLE DATA_ADMIN;
GRANT ALL ON ALL SCHEMAS IN DATABASE SEM_DEV TO ROLE DATA_ADMIN;
GRANT ALL ON ALL VIEWS IN DATABASE SEM_DEV TO ROLE DATA_ADMIN;
GRANT ALL ON ALL TABLES IN DATABASE SEM_DEV TO ROLE DATA_ADMIN;
GRANT ALL ON FUTURE VIEWS IN DATABASE SEM_DEV TO ROLE DATA_ADMIN;

-- DATA_ENGINEER: Create semantic views
GRANT USAGE ON DATABASE SEM_DEV TO ROLE DATA_ENGINEER;
GRANT USAGE ON ALL SCHEMAS IN DATABASE SEM_DEV TO ROLE DATA_ENGINEER;
GRANT CREATE VIEW ON ALL SCHEMAS IN DATABASE SEM_DEV TO ROLE DATA_ENGINEER;
GRANT SELECT ON ALL VIEWS IN DATABASE SEM_DEV TO ROLE DATA_ENGINEER;

-- DATA_STEWARD: Read and document semantic layer
GRANT USAGE ON DATABASE SEM_DEV TO ROLE DATA_STEWARD;
GRANT USAGE ON ALL SCHEMAS IN DATABASE SEM_DEV TO ROLE DATA_STEWARD;
GRANT SELECT ON ALL VIEWS IN DATABASE SEM_DEV TO ROLE DATA_STEWARD;
GRANT SELECT ON ALL TABLES IN DATABASE SEM_DEV TO ROLE DATA_STEWARD;

-- DATA_ANALYST: Full read access to semantic layer (primary interface)
GRANT USAGE ON DATABASE SEM_DEV TO ROLE DATA_ANALYST;
GRANT USAGE ON ALL SCHEMAS IN DATABASE SEM_DEV TO ROLE DATA_ANALYST;
GRANT SELECT ON ALL VIEWS IN DATABASE SEM_DEV TO ROLE DATA_ANALYST;
GRANT SELECT ON ALL TABLES IN DATABASE SEM_DEV TO ROLE DATA_ANALYST;
GRANT READ ON STAGE SEM_DEV.SEM_SALES.SEMANTIC_MODELS TO ROLE DATA_ANALYST;

-- AI_AGENT: Read access to AI-safe semantic views only
GRANT USAGE ON DATABASE SEM_DEV TO ROLE AI_AGENT;
GRANT USAGE ON SCHEMA SEM_DEV.SEM_SALES TO ROLE AI_AGENT;
GRANT USAGE ON SCHEMA SEM_DEV.SEM_CUSTOMER TO ROLE AI_AGENT;
GRANT USAGE ON SCHEMA SEM_DEV.SEM_PRODUCT TO ROLE AI_AGENT;
GRANT SELECT ON VIEW SEM_DEV.SEM_SALES.VW_SALES_ANALYTICS TO ROLE AI_AGENT;
GRANT SELECT ON VIEW SEM_DEV.SEM_SALES.VW_SALES_SUMMARY TO ROLE AI_AGENT;
GRANT SELECT ON VIEW SEM_DEV.SEM_SALES.VW_SUPPLIER_ANALYTICS TO ROLE AI_AGENT;
GRANT SELECT ON VIEW SEM_DEV.SEM_CUSTOMER.VW_CUSTOMER_ANALYTICS TO ROLE AI_AGENT;
GRANT SELECT ON VIEW SEM_DEV.SEM_PRODUCT.VW_PRODUCT_ANALYTICS TO ROLE AI_AGENT;
GRANT SELECT ON TABLE SEM_DEV.SEM_SALES.VW_AVAILABLE_SEMANTIC_MODELS TO ROLE AI_AGENT;
GRANT READ ON STAGE SEM_DEV.SEM_SALES.SEMANTIC_MODELS TO ROLE AI_AGENT;

-- BI_VIEWER: Limited read access to summary views
GRANT USAGE ON DATABASE SEM_DEV TO ROLE BI_VIEWER;
GRANT USAGE ON SCHEMA SEM_DEV.SEM_SALES TO ROLE BI_VIEWER;
GRANT SELECT ON VIEW SEM_DEV.SEM_SALES.VW_SALES_SUMMARY TO ROLE BI_VIEWER;

-- ═══════════════════════════════════════════════════════════════════════════
-- PART 5: CREATE DEMO USERS
-- ═══════════════════════════════════════════════════════════════════════════

-- Note: In production, use proper password management and SSO
-- These are demo users with simple passwords for testing

-- ─────────────────────────────────────────────────────────────────────────────
-- ADMIN USER
-- ─────────────────────────────────────────────────────────────────────────────
CREATE USER IF NOT EXISTS DEMO_DATA_ADMIN
    PASSWORD = 'DemoAdmin123!'
    DEFAULT_ROLE = DATA_ADMIN
    DEFAULT_WAREHOUSE = ANALYTICS_WH
    MUST_CHANGE_PASSWORD = FALSE
    COMMENT = 'Demo data administrator with full access';

GRANT ROLE DATA_ADMIN TO USER DEMO_DATA_ADMIN;

-- ─────────────────────────────────────────────────────────────────────────────
-- DATA ENGINEER USER
-- ─────────────────────────────────────────────────────────────────────────────
CREATE USER IF NOT EXISTS DEMO_DATA_ENGINEER
    PASSWORD = 'DemoEngineer123!'
    DEFAULT_ROLE = DATA_ENGINEER
    DEFAULT_WAREHOUSE = ANALYTICS_WH
    MUST_CHANGE_PASSWORD = FALSE
    COMMENT = 'Demo data engineer for pipeline management';

GRANT ROLE DATA_ENGINEER TO USER DEMO_DATA_ENGINEER;

-- ─────────────────────────────────────────────────────────────────────────────
-- DATA STEWARD USER
-- ─────────────────────────────────────────────────────────────────────────────
CREATE USER IF NOT EXISTS DEMO_DATA_STEWARD
    PASSWORD = 'DemoSteward123!'
    DEFAULT_ROLE = DATA_STEWARD
    DEFAULT_WAREHOUSE = ANALYTICS_WH
    MUST_CHANGE_PASSWORD = FALSE
    COMMENT = 'Demo data steward for governance management';

GRANT ROLE DATA_STEWARD TO USER DEMO_DATA_STEWARD;

-- ─────────────────────────────────────────────────────────────────────────────
-- DATA ANALYST USERS (Multiple to show team access)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE USER IF NOT EXISTS DEMO_ANALYST_SALES
    PASSWORD = 'DemoAnalyst123!'
    DEFAULT_ROLE = DATA_ANALYST
    DEFAULT_WAREHOUSE = ANALYTICS_WH
    MUST_CHANGE_PASSWORD = FALSE
    COMMENT = 'Demo sales analyst';

GRANT ROLE DATA_ANALYST TO USER DEMO_ANALYST_SALES;

CREATE USER IF NOT EXISTS DEMO_ANALYST_MARKETING
    PASSWORD = 'DemoAnalyst123!'
    DEFAULT_ROLE = DATA_ANALYST
    DEFAULT_WAREHOUSE = ANALYTICS_WH
    MUST_CHANGE_PASSWORD = FALSE
    COMMENT = 'Demo marketing analyst';

GRANT ROLE DATA_ANALYST TO USER DEMO_ANALYST_MARKETING;

-- ─────────────────────────────────────────────────────────────────────────────
-- AI AGENT SERVICE ACCOUNT
-- ─────────────────────────────────────────────────────────────────────────────
CREATE USER IF NOT EXISTS DEMO_AI_AGENT
    PASSWORD = 'DemoAIAgent123!'
    DEFAULT_ROLE = AI_AGENT
    DEFAULT_WAREHOUSE = ANALYTICS_WH
    MUST_CHANGE_PASSWORD = FALSE
    COMMENT = 'Demo AI/ML service account for Cortex and ML workloads';

GRANT ROLE AI_AGENT TO USER DEMO_AI_AGENT;

-- ─────────────────────────────────────────────────────────────────────────────
-- BI VIEWER USER (Executive Dashboard Access)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE USER IF NOT EXISTS DEMO_BI_VIEWER
    PASSWORD = 'DemoBIViewer123!'
    DEFAULT_ROLE = BI_VIEWER
    DEFAULT_WAREHOUSE = ANALYTICS_WH
    MUST_CHANGE_PASSWORD = FALSE
    COMMENT = 'Demo BI viewer for dashboard consumption';

GRANT ROLE BI_VIEWER TO USER DEMO_BI_VIEWER;

-- ─────────────────────────────────────────────────────────────────────────────
-- PII VIEWER USER (Privileged Access)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE USER IF NOT EXISTS DEMO_PII_VIEWER
    PASSWORD = 'DemoPIIViewer123!'
    DEFAULT_ROLE = PII_VIEWER
    DEFAULT_WAREHOUSE = ANALYTICS_WH
    MUST_CHANGE_PASSWORD = FALSE
    COMMENT = 'Demo user with PII access for compliance/legal';

GRANT ROLE PII_VIEWER TO USER DEMO_PII_VIEWER;
-- Also grant DATA_ANALYST so they can access semantic layer
GRANT ROLE DATA_ANALYST TO USER DEMO_PII_VIEWER;

-- ═══════════════════════════════════════════════════════════════════════════
-- PART 6: ROLE ACCESS SUMMARY VIEW
-- ═══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE VIEW GOVERNANCE.OBSERVABILITY.VW_ROLE_ACCESS_SUMMARY AS
SELECT
    'DATA_ADMIN' AS ROLE_NAME,
    'Full administrative access' AS DESCRIPTION,
    'ALL' AS RAW_ACCESS,
    'ALL' AS CURATED_ACCESS,
    'ALL' AS SEMANTIC_ACCESS,
    'ALL' AS GOVERNANCE_ACCESS,
    'YES' AS PII_ACCESS,
    'YES' AS AI_ELIGIBLE
UNION ALL
SELECT
    'DATA_ENGINEER',
    'Pipeline and transformation management',
    'READ/WRITE',
    'READ + CREATE DT',
    'READ + CREATE VIEW',
    'NONE',
    'NO',
    'NO'
UNION ALL
SELECT
    'DATA_STEWARD',
    'Governance and contract management',
    'READ',
    'READ',
    'READ',
    'ALL',
    'NO',
    'NO'
UNION ALL
SELECT
    'PII_VIEWER',
    'Privileged PII access',
    'NONE',
    'NONE',
    'READ (UNMASKED)',
    'READ',
    'YES',
    'NO'
UNION ALL
SELECT
    'DATA_ANALYST',
    'BI and analytics consumption',
    'NONE',
    'NONE',
    'READ (MASKED)',
    'READ (Observability)',
    'NO',
    'YES'
UNION ALL
SELECT
    'AI_AGENT',
    'AI/ML workloads and Cortex',
    'NONE',
    'NONE',
    'READ (AI-SAFE ONLY)',
    'NONE',
    'NO',
    'YES'
UNION ALL
SELECT
    'BI_VIEWER',
    'Dashboard consumption only',
    'NONE',
    'NONE',
    'READ (SUMMARY ONLY)',
    'READ (KPIs)',
    'NO',
    'NO';

COMMENT ON VIEW GOVERNANCE.OBSERVABILITY.VW_ROLE_ACCESS_SUMMARY IS 
'Summary of role access levels across data layers. Demonstrates least-privilege access control.';

-- ═══════════════════════════════════════════════════════════════════════════
-- PART 7: USER DIRECTORY VIEW
-- ═══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE VIEW GOVERNANCE.OBSERVABILITY.VW_USER_DIRECTORY AS
SELECT
    'DEMO_DATA_ADMIN' AS USERNAME,
    'DATA_ADMIN' AS PRIMARY_ROLE,
    'Demo Data Administrator' AS DESCRIPTION,
    'data-admin@company.com' AS EMAIL
UNION ALL
SELECT
    'DEMO_DATA_ENGINEER',
    'DATA_ENGINEER',
    'Demo Data Engineer',
    'data-engineer@company.com'
UNION ALL
SELECT
    'DEMO_DATA_STEWARD',
    'DATA_STEWARD',
    'Demo Data Steward',
    'data-steward@company.com'
UNION ALL
SELECT
    'DEMO_ANALYST_SALES',
    'DATA_ANALYST',
    'Demo Sales Analyst',
    'analyst-sales@company.com'
UNION ALL
SELECT
    'DEMO_ANALYST_MARKETING',
    'DATA_ANALYST',
    'Demo Marketing Analyst',
    'analyst-marketing@company.com'
UNION ALL
SELECT
    'DEMO_AI_AGENT',
    'AI_AGENT',
    'Demo AI Service Account',
    'ai-agent@company.com'
UNION ALL
SELECT
    'DEMO_BI_VIEWER',
    'BI_VIEWER',
    'Demo BI Viewer',
    'bi-viewer@company.com'
UNION ALL
SELECT
    'DEMO_PII_VIEWER',
    'PII_VIEWER',
    'Demo PII Viewer (Compliance)',
    'compliance@company.com';

COMMENT ON VIEW GOVERNANCE.OBSERVABILITY.VW_USER_DIRECTORY IS 
'Directory of demo users and their primary roles for testing access control.';

-- ═══════════════════════════════════════════════════════════════════════════
-- VERIFICATION
-- ═══════════════════════════════════════════════════════════════════════════

SELECT 'Roles and Users Created Successfully' AS STATUS;

-- Show role hierarchy
SHOW ROLES;

-- Show users
SHOW USERS LIKE 'DEMO_%';

-- Show role access summary
SELECT * FROM GOVERNANCE.OBSERVABILITY.VW_ROLE_ACCESS_SUMMARY;

-- Show user directory
SELECT * FROM GOVERNANCE.OBSERVABILITY.VW_USER_DIRECTORY;

-- ═══════════════════════════════════════════════════════════════════════════
-- DEMO SCENARIOS
-- ═══════════════════════════════════════════════════════════════════════════
/*
-- TEST 1: Data Analyst can access semantic layer but not RAW
USE ROLE DATA_ANALYST;
SELECT * FROM SEM_DEV.SEM_SALES.VW_SALES_ANALYTICS LIMIT 10;  -- ✓ Works
SELECT * FROM RAW_DEV.RAW_TPCH.CUSTOMER_RAW LIMIT 10;          -- ✗ Access Denied

-- TEST 2: AI Agent can only access AI-eligible views
USE ROLE AI_AGENT;
SELECT * FROM SEM_DEV.SEM_CUSTOMER.VW_CUSTOMER_ANALYTICS LIMIT 10;  -- ✓ Works (pseudonymized)
SELECT * FROM RAW_DEV.RAW_TPCH.CUSTOMER_RAW LIMIT 10;                -- ✗ Access Denied

-- TEST 3: BI Viewer has limited access
USE ROLE BI_VIEWER;
SELECT * FROM SEM_DEV.SEM_SALES.VW_SALES_SUMMARY LIMIT 10;     -- ✓ Works
SELECT * FROM SEM_DEV.SEM_SALES.VW_SALES_ANALYTICS LIMIT 10;   -- ✗ Access Denied

-- TEST 4: PII Viewer can see unmasked data
USE ROLE PII_VIEWER;
USE ROLE DATA_ANALYST;  -- Need analyst role to access views
-- When querying, masking policies will allow unmasked data for PII_VIEWER role

-- TEST 5: Data Steward can manage contracts
USE ROLE DATA_STEWARD;
CALL GOVERNANCE.CONTRACT_REGISTRY.VALIDATE_CONTRACT('tpch_customer_v1');  -- ✓ Works
SELECT * FROM GOVERNANCE.OBSERVABILITY.VW_CONTRACT_HEALTH_DASHBOARD;      -- ✓ Works
*/

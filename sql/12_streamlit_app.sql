-- ============================================================================
-- STREAMLIT APP DEPLOYMENT
-- ============================================================================
-- This script deploys the Data Contracts Demo Streamlit app to Snowflake.
-- Run this AFTER all other setup scripts.
-- ============================================================================

USE ROLE DATA_ADMIN;
USE DATABASE SEM_DEV;
USE SCHEMA SEM_SALES;
USE WAREHOUSE ANALYTICS_WH;

-- ─────────────────────────────────────────────────────────────────────────────
-- CREATE STAGE FOR STREAMLIT APP
-- ─────────────────────────────────────────────────────────────────────────────

CREATE STAGE IF NOT EXISTS STREAMLIT_STAGE
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'Stage for Streamlit application files';

-- ─────────────────────────────────────────────────────────────────────────────
-- UPLOAD INSTRUCTIONS
-- ─────────────────────────────────────────────────────────────────────────────
/*
Upload the Streamlit app file to the stage using one of these methods:

METHOD 1: SnowSQL CLI
----------------------
snowsql -a <account> -u <user> -q "PUT file://streamlit/data_contracts_app.py @SEM_DEV.SEM_SALES.STREAMLIT_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE"

METHOD 2: Snowsight UI
-----------------------
1. Navigate to Data → Databases → SEM_DEV → SEM_SALES → Stages → STREAMLIT_STAGE
2. Click "Upload Files"
3. Select streamlit/data_contracts_app.py
4. Upload

METHOD 3: Python (from local environment)
-----------------------------------------
from snowflake.connector import connect
conn = connect(account='<account>', user='<user>', password='<password>')
conn.cursor().execute("PUT file://streamlit/data_contracts_app.py @SEM_DEV.SEM_SALES.STREAMLIT_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE")
*/

-- ─────────────────────────────────────────────────────────────────────────────
-- CREATE STREAMLIT APPLICATION
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE STREAMLIT DATA_CONTRACTS_APP
    ROOT_LOCATION = '@SEM_DEV.SEM_SALES.STREAMLIT_STAGE'
    MAIN_FILE = 'data_contracts_app.py'
    QUERY_WAREHOUSE = 'ANALYTICS_WH'
    COMMENT = 'Data Contracts Demo - Cortex Analyst & Horizon Governance Dashboard';

-- ─────────────────────────────────────────────────────────────────────────────
-- GRANT ACCESS TO ROLES
-- ─────────────────────────────────────────────────────────────────────────────

-- All roles can view the Streamlit app
GRANT USAGE ON STREAMLIT DATA_CONTRACTS_APP TO ROLE DATA_ENGINEER;
GRANT USAGE ON STREAMLIT DATA_CONTRACTS_APP TO ROLE DATA_STEWARD;
GRANT USAGE ON STREAMLIT DATA_CONTRACTS_APP TO ROLE DATA_ANALYST;
GRANT USAGE ON STREAMLIT DATA_CONTRACTS_APP TO ROLE AI_AGENT;
GRANT USAGE ON STREAMLIT DATA_CONTRACTS_APP TO ROLE BI_VIEWER;

-- ─────────────────────────────────────────────────────────────────────────────
-- VERIFICATION
-- ─────────────────────────────────────────────────────────────────────────────

SELECT '✓ Streamlit App Created Successfully' AS STATUS;

-- Show the app
SHOW STREAMLITS IN SCHEMA SEM_DEV.SEM_SALES;

-- Get the app URL
SELECT CONCAT('https://app.snowflake.com/', CURRENT_ACCOUNT(), '/streamlit-apps/', 'DATA_CONTRACTS_APP') AS APP_URL;

-- ─────────────────────────────────────────────────────────────────────────────
-- INSTRUCTIONS
-- ─────────────────────────────────────────────────────────────────────────────
/*
TO ACCESS THE APP:
==================

1. In Snowsight, go to Projects → Streamlit
2. Find "DATA_CONTRACTS_APP"
3. Click to open

OR

Navigate directly to: 
https://app.snowflake.com/<account>/streamlit-apps/DATA_CONTRACTS_APP

APP FEATURES:
=============

🤖 CORTEX ANALYST
- Natural language queries on semantic models
- Sales, Customer, Product, Governance analytics
- Sample questions to get started

🔮 HORIZON DASHBOARD
- Real-time governance health indicators
- SLA compliance trends
- Tag coverage analysis
- Active alerts with severity indicators

📊 CONTRACT DETAILS
- Individual contract exploration
- Consumer registry
- Quality rules

ℹ️ ABOUT
- Architecture overview
- Resource links
*/

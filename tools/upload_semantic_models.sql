-- ============================================================================
-- UPLOAD SEMANTIC MODELS TO SNOWFLAKE STAGE
-- ============================================================================
-- Run this script using SnowSQL CLI from the project root directory:
--
--   cd /path/to/snowflake-dca-contracts-demo
--   snowsql -a <account> -u <user> -f tools/upload_semantic_models.sql
--
-- Or connect to SnowSQL first and then run:
--   !source tools/upload_semantic_models.sql
-- ============================================================================

-- Set context
USE ROLE ACCOUNTADMIN;
USE DATABASE SEM_DEV;
USE SCHEMA SEM_SALES;
USE WAREHOUSE ANALYTICS_WH;

-- Verify stage exists
SHOW STAGES LIKE 'SEMANTIC_MODELS' IN SCHEMA SEM_DEV.SEM_SALES;

-- Upload semantic model files
-- Note: These PUT commands only work in SnowSQL, not in Snowflake worksheets

PUT file://semantic_models/sales_analytics_model.yaml @SEMANTIC_MODELS AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
PUT file://semantic_models/customer_analytics_model.yaml @SEMANTIC_MODELS AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
PUT file://semantic_models/product_analytics_model.yaml @SEMANTIC_MODELS AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
PUT file://semantic_models/supplier_analytics_model.yaml @SEMANTIC_MODELS AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
PUT file://semantic_models/governance_analytics_model.yaml @SEMANTIC_MODELS AUTO_COMPRESS=FALSE OVERWRITE=TRUE;

-- Verify files were uploaded
SELECT 'Verifying uploaded files...' AS STATUS;
LIST @SEMANTIC_MODELS;

-- Show file details
SELECT 
    REGEXP_SUBSTR("name", '[^/]+$') AS FILE_NAME,
    "size" AS SIZE_BYTES,
    "md5" AS MD5_HASH,
    "last_modified" AS LAST_MODIFIED
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

-- Verify semantic model registry
SELECT 'Registered Semantic Models:' AS STATUS;
SELECT 
    MODEL_NAME,
    MODEL_VERSION,
    STAGE_PATH,
    AI_SAFE
FROM SEM_DEV.SEM_SALES.SEMANTIC_MODEL_REGISTRY
ORDER BY MODEL_NAME;

SELECT '✓ Semantic models uploaded successfully!' AS STATUS;

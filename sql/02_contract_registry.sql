-- ============================================================================
-- CONTRACT REGISTRY - Tables, Views, and Procedures
-- ============================================================================
-- Creates the contract registry infrastructure for managing data contracts.
-- RUN AS: DATA_ADMIN (set in 01_setup.sql)
-- ============================================================================

USE ROLE DATA_ADMIN;
USE WAREHOUSE TRANSFORM_WH;
USE DATABASE GOVERNANCE;
USE SCHEMA CONTRACT_REGISTRY;

-- ═══════════════════════════════════════════════════════════════════════════
-- CORE TABLES
-- ═══════════════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────────────────────
-- CONTRACTS - Master contract table
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS CONTRACTS (
    CONTRACT_ID VARCHAR(128) NOT NULL,
    CONTRACT_TYPE VARCHAR(20) NOT NULL,  -- 'data' or 'product'
    VERSION VARCHAR(20) NOT NULL,
    STATUS VARCHAR(20) DEFAULT 'draft',  -- draft, active, deprecated, retired
    PRODUCER_SYSTEM VARCHAR(256),
    PRODUCER_EMAIL VARCHAR(256),
    DESCRIPTION VARCHAR(4000),
    YAML_DEFINITION VARIANT,
    CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    CREATED_BY VARCHAR(256) DEFAULT CURRENT_USER(),
    UPDATED_BY VARCHAR(256) DEFAULT CURRENT_USER(),
    PRIMARY KEY (CONTRACT_ID, VERSION)
);

COMMENT ON TABLE CONTRACTS IS 
'Master table for all data and product contracts. Stores contract metadata and full YAML definition.';

-- ─────────────────────────────────────────────────────────────────────────────
-- CONTRACT_VERSIONS - Version history
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS CONTRACT_VERSIONS (
    VERSION_ID VARCHAR(64) NOT NULL PRIMARY KEY DEFAULT UUID_STRING(),
    CONTRACT_ID VARCHAR(128) NOT NULL,
    VERSION VARCHAR(20) NOT NULL,
    PREVIOUS_VERSION VARCHAR(20),
    CHANGE_TYPE VARCHAR(20),  -- major, minor, patch
    CHANGE_SUMMARY VARCHAR(4000),
    BREAKING_CHANGES BOOLEAN DEFAULT FALSE,
    CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    CREATED_BY VARCHAR(256) DEFAULT CURRENT_USER()
);

COMMENT ON TABLE CONTRACT_VERSIONS IS 
'Tracks version history and changes for each contract.';

-- ─────────────────────────────────────────────────────────────────────────────
-- CONTRACT_COLUMNS - Column definitions per contract
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS CONTRACT_COLUMNS (
    COLUMN_ID VARCHAR(64) NOT NULL PRIMARY KEY DEFAULT UUID_STRING(),
    CONTRACT_ID VARCHAR(128) NOT NULL,
    VERSION VARCHAR(20) NOT NULL,
    COLUMN_NAME VARCHAR(256) NOT NULL,
    DATA_TYPE VARCHAR(128) NOT NULL,
    IS_NULLABLE BOOLEAN DEFAULT TRUE,
    IS_PRIMARY_KEY BOOLEAN DEFAULT FALSE,
    IS_SYSTEM_MANAGED BOOLEAN DEFAULT FALSE,
    DESCRIPTION VARCHAR(4000),
    BUSINESS_NAME VARCHAR(256),
    CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

COMMENT ON TABLE CONTRACT_COLUMNS IS 
'Column definitions for each contract version. Used for schema validation.';

-- ─────────────────────────────────────────────────────────────────────────────
-- COLUMN_TAGS - Tags applied to columns
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS COLUMN_TAGS (
    TAG_ID VARCHAR(64) NOT NULL PRIMARY KEY DEFAULT UUID_STRING(),
    CONTRACT_ID VARCHAR(128) NOT NULL,
    VERSION VARCHAR(20) NOT NULL,
    COLUMN_NAME VARCHAR(256) NOT NULL,
    TAG_NAME VARCHAR(128) NOT NULL,
    TAG_VALUE VARCHAR(256) NOT NULL,
    CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

COMMENT ON TABLE COLUMN_TAGS IS 
'Governance tags applied to contract columns (DATA_CLASSIFICATION, PII_TYPE, AI_ALLOWED, etc.).';

-- ─────────────────────────────────────────────────────────────────────────────
-- CONTRACT_CONSUMERS - Who consumes each contract
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS CONTRACT_CONSUMERS (
    CONSUMER_ID VARCHAR(64) NOT NULL PRIMARY KEY DEFAULT UUID_STRING(),
    CONTRACT_ID VARCHAR(128) NOT NULL,
    CONSUMER_SYSTEM VARCHAR(256) NOT NULL,
    CONSUMER_TEAM VARCHAR(256),
    CONSUMER_EMAIL VARCHAR(256),
    USE_CASE VARCHAR(4000),
    NOTIFY_BREAKING BOOLEAN DEFAULT TRUE,
    REGISTERED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    REGISTERED_BY VARCHAR(256) DEFAULT CURRENT_USER()
);

COMMENT ON TABLE CONTRACT_CONSUMERS IS 
'Registry of systems/teams consuming each contract. Used for breaking change notifications.';

-- ─────────────────────────────────────────────────────────────────────────────
-- CONTRACT_SLAS - SLA definitions
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS CONTRACT_SLAS (
    SLA_ID VARCHAR(64) NOT NULL PRIMARY KEY DEFAULT UUID_STRING(),
    CONTRACT_ID VARCHAR(128) NOT NULL,
    VERSION VARCHAR(20) NOT NULL,
    SLA_TYPE VARCHAR(50) NOT NULL,  -- freshness, availability, completeness
    THRESHOLD_VALUE FLOAT NOT NULL,
    THRESHOLD_UNIT VARCHAR(20),  -- minutes, percent, count
    MEASUREMENT_WINDOW VARCHAR(20),  -- hourly, daily, weekly
    SEVERITY VARCHAR(20) DEFAULT 'error',  -- warning, error, critical
    CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

COMMENT ON TABLE CONTRACT_SLAS IS 
'SLA definitions for each contract (freshness, availability, completeness thresholds).';

-- ─────────────────────────────────────────────────────────────────────────────
-- QUALITY_RULES - Quality rule definitions
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS QUALITY_RULES (
    RULE_ID VARCHAR(64) NOT NULL PRIMARY KEY DEFAULT UUID_STRING(),
    CONTRACT_ID VARCHAR(128) NOT NULL,
    VERSION VARCHAR(20) NOT NULL,
    RULE_NAME VARCHAR(256) NOT NULL,
    RULE_TYPE VARCHAR(50) NOT NULL,  -- not_null, unique, range, regex, custom
    COLUMN_NAME VARCHAR(256),
    RULE_DEFINITION VARIANT,  -- JSON with rule parameters
    SEVERITY VARCHAR(20) DEFAULT 'error',
    ENABLED BOOLEAN DEFAULT TRUE,
    CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

COMMENT ON TABLE QUALITY_RULES IS 
'Data quality rule definitions for each contract.';

-- ─────────────────────────────────────────────────────────────────────────────
-- QUALITY_RULE_RESULTS - Quality check results
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS QUALITY_RULE_RESULTS (
    RESULT_ID VARCHAR(64) NOT NULL PRIMARY KEY DEFAULT UUID_STRING(),
    RULE_ID VARCHAR(64) NOT NULL,
    CONTRACT_ID VARCHAR(128) NOT NULL,
    EXECUTION_TIME TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    PASSED BOOLEAN NOT NULL,
    RESULT_VALUE VARIANT,
    ROWS_CHECKED INT,
    ROWS_FAILED INT,
    ERROR_MESSAGE VARCHAR(4000)
);

COMMENT ON TABLE QUALITY_RULE_RESULTS IS 
'Execution results for quality rule checks.';

-- ─────────────────────────────────────────────────────────────────────────────
-- SLA_METRICS - SLA measurement results
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS SLA_METRICS (
    METRIC_ID VARCHAR(64) NOT NULL PRIMARY KEY DEFAULT UUID_STRING(),
    CONTRACT_ID VARCHAR(128) NOT NULL,
    SLA_ID VARCHAR(64),
    MEASURED_VALUE FLOAT,
    THRESHOLD_VALUE FLOAT,
    IS_VIOLATION BOOLEAN DEFAULT FALSE,
    VIOLATION_SEVERITY VARCHAR(20),
    MEASURED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

COMMENT ON TABLE SLA_METRICS IS 
'SLA measurement results over time. Used for compliance trending.';

-- ─────────────────────────────────────────────────────────────────────────────
-- BREAKING_CHANGE_APPROVALS - Breaking change workflow
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS BREAKING_CHANGE_APPROVALS (
    APPROVAL_ID VARCHAR(64) NOT NULL PRIMARY KEY DEFAULT UUID_STRING(),
    CONTRACT_ID VARCHAR(128) NOT NULL,
    FROM_VERSION VARCHAR(20) NOT NULL,
    TO_VERSION VARCHAR(20) NOT NULL,
    CONSUMER_ID VARCHAR(64) NOT NULL,
    STATUS VARCHAR(20) DEFAULT 'pending',  -- pending, approved, rejected
    REVIEWED_BY VARCHAR(256),
    REVIEWED_AT TIMESTAMP_NTZ,
    DEADLINE_AT TIMESTAMP_NTZ,
    NOTES VARCHAR(4000),
    CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

COMMENT ON TABLE BREAKING_CHANGE_APPROVALS IS 
'Tracks consumer approvals for breaking contract changes.';

-- ═══════════════════════════════════════════════════════════════════════════
-- VIEWS
-- ═══════════════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────────────────────
-- VW_ACTIVE_CONTRACTS - Currently active contracts
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE VIEW VW_ACTIVE_CONTRACTS AS
SELECT 
    c.CONTRACT_ID,
    c.CONTRACT_TYPE,
    c.VERSION,
    c.PRODUCER_SYSTEM,
    c.PRODUCER_EMAIL,
    c.DESCRIPTION,
    c.CREATED_AT,
    c.UPDATED_AT,
    COUNT(DISTINCT cc.CONSUMER_ID) AS CONSUMER_COUNT,
    COUNT(DISTINCT qr.RULE_ID) AS QUALITY_RULE_COUNT
FROM CONTRACTS c
LEFT JOIN CONTRACT_CONSUMERS cc ON c.CONTRACT_ID = cc.CONTRACT_ID
LEFT JOIN QUALITY_RULES qr ON c.CONTRACT_ID = qr.CONTRACT_ID AND c.VERSION = qr.VERSION
WHERE c.STATUS = 'active'
GROUP BY c.CONTRACT_ID, c.CONTRACT_TYPE, c.VERSION, c.PRODUCER_SYSTEM, 
         c.PRODUCER_EMAIL, c.DESCRIPTION, c.CREATED_AT, c.UPDATED_AT;

COMMENT ON VIEW VW_ACTIVE_CONTRACTS IS 
'Active contracts with consumer and quality rule counts.';

-- ─────────────────────────────────────────────────────────────────────────────
-- VW_CONTRACT_TAG_COVERAGE - Tag compliance check
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE VIEW VW_CONTRACT_TAG_COVERAGE AS
SELECT 
    cc.CONTRACT_ID,
    cc.VERSION,
    cc.COLUMN_NAME,
    MAX(CASE WHEN ct.TAG_NAME = 'DATA_CLASSIFICATION' THEN ct.TAG_VALUE END) AS DATA_CLASSIFICATION,
    MAX(CASE WHEN ct.TAG_NAME = 'PII_TYPE' THEN ct.TAG_VALUE END) AS PII_TYPE,
    MAX(CASE WHEN ct.TAG_NAME = 'AI_ALLOWED' THEN ct.TAG_VALUE END) AS AI_ALLOWED,
    CASE WHEN MAX(CASE WHEN ct.TAG_NAME = 'DATA_CLASSIFICATION' THEN 1 ELSE 0 END) = 0 
         THEN TRUE ELSE FALSE END AS MISSING_DATA_CLASSIFICATION,
    CASE WHEN MAX(CASE WHEN ct.TAG_NAME = 'PII_TYPE' THEN 1 ELSE 0 END) = 0 
         THEN TRUE ELSE FALSE END AS MISSING_PII_TYPE,
    CASE WHEN MAX(CASE WHEN ct.TAG_NAME = 'AI_ALLOWED' THEN 1 ELSE 0 END) = 0 
         THEN TRUE ELSE FALSE END AS MISSING_AI_ALLOWED
FROM CONTRACT_COLUMNS cc
LEFT JOIN COLUMN_TAGS ct 
    ON cc.CONTRACT_ID = ct.CONTRACT_ID 
    AND cc.VERSION = ct.VERSION 
    AND cc.COLUMN_NAME = ct.COLUMN_NAME
WHERE cc.IS_SYSTEM_MANAGED = FALSE
GROUP BY cc.CONTRACT_ID, cc.VERSION, cc.COLUMN_NAME
HAVING MISSING_DATA_CLASSIFICATION OR MISSING_PII_TYPE OR MISSING_AI_ALLOWED;

COMMENT ON VIEW VW_CONTRACT_TAG_COVERAGE IS 
'Identifies columns missing required governance tags.';

-- ═══════════════════════════════════════════════════════════════════════════
-- STORED PROCEDURES
-- ═══════════════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────────────────────
-- REGISTER_CONTRACT - Register a contract from JSON
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE PROCEDURE REGISTER_CONTRACT(P_CONTRACT_JSON TEXT)
RETURNS VARCHAR
LANGUAGE JAVASCRIPT
AS
$$
    var parsed = JSON.parse(P_CONTRACT_JSON);
    var contract_id, version, contract_type;
    
    if (parsed.contract) {
        contract_type = 'data';
        contract_id = parsed.contract.id;
        version = parsed.contract.version;
    } else if (parsed.product) {
        contract_type = 'product';
        contract_id = parsed.product.id;
        version = parsed.product.version;
    } else {
        return 'ERROR: Invalid contract format - missing contract or product key';
    }
    
    var merge_sql = `
        MERGE INTO GOVERNANCE.CONTRACT_REGISTRY.CONTRACTS tgt
        USING (SELECT ? AS cid, ? AS ver) src
        ON tgt.CONTRACT_ID = src.cid AND tgt.VERSION = src.ver
        WHEN MATCHED THEN
            UPDATE SET 
                YAML_DEFINITION = PARSE_JSON(?),
                UPDATED_AT = CURRENT_TIMESTAMP(),
                UPDATED_BY = CURRENT_USER()
        WHEN NOT MATCHED THEN
            INSERT (CONTRACT_ID, CONTRACT_TYPE, VERSION, STATUS, YAML_DEFINITION)
            VALUES (?, ?, ?, 'draft', PARSE_JSON(?))
    `;
    
    var stmt = snowflake.createStatement({
        sqlText: merge_sql,
        binds: [contract_id, version, P_CONTRACT_JSON, contract_id, contract_type, version, P_CONTRACT_JSON]
    });
    stmt.execute();
    
    return 'Contract registered: ' + contract_id + ' v' + version;
$$;

COMMENT ON PROCEDURE REGISTER_CONTRACT(TEXT) IS 
'Registers a new contract from JSON/YAML definition.';

-- ─────────────────────────────────────────────────────────────────────────────
-- NOTIFY_BREAKING_CHANGE - Notify consumers of breaking changes
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE PROCEDURE NOTIFY_BREAKING_CHANGE(
    P_CONTRACT_ID VARCHAR,
    P_FROM_VERSION VARCHAR,
    P_TO_VERSION VARCHAR,
    P_DEADLINE_DAYS FLOAT DEFAULT 14
)
RETURNS VARCHAR
LANGUAGE JAVASCRIPT
AS
$$
    // Get consumers who want notifications
    var count_sql = `
        SELECT COUNT(*) AS CNT 
        FROM GOVERNANCE.CONTRACT_REGISTRY.CONTRACT_CONSUMERS
        WHERE CONTRACT_ID = ? AND NOTIFY_BREAKING = TRUE
    `;
    var count_stmt = snowflake.createStatement({sqlText: count_sql, binds: [P_CONTRACT_ID]});
    var count_result = count_stmt.execute();
    count_result.next();
    var consumer_count = count_result.getColumnValue(1);
    
    // Insert approval requests
    var insert_sql = `
        INSERT INTO GOVERNANCE.CONTRACT_REGISTRY.BREAKING_CHANGE_APPROVALS
            (APPROVAL_ID, CONTRACT_ID, FROM_VERSION, TO_VERSION, CONSUMER_ID, STATUS, DEADLINE_AT)
        SELECT 
            UUID_STRING(), ?, ?, ?, CONSUMER_ID, 'pending',
            DATEADD('day', ?, CURRENT_TIMESTAMP())
        FROM GOVERNANCE.CONTRACT_REGISTRY.CONTRACT_CONSUMERS
        WHERE CONTRACT_ID = ? AND NOTIFY_BREAKING = TRUE
    `;
    var insert_stmt = snowflake.createStatement({
        sqlText: insert_sql, 
        binds: [P_CONTRACT_ID, P_FROM_VERSION, P_TO_VERSION, P_DEADLINE_DAYS, P_CONTRACT_ID]
    });
    insert_stmt.execute();
    
    return 'Created ' + consumer_count + ' approval requests for contract ' + P_CONTRACT_ID;
$$;

COMMENT ON PROCEDURE NOTIFY_BREAKING_CHANGE(VARCHAR, VARCHAR, VARCHAR, FLOAT) IS 
'Creates approval requests for all consumers when a breaking change is introduced.';

-- ═══════════════════════════════════════════════════════════════════════════
-- VERIFICATION
-- ═══════════════════════════════════════════════════════════════════════════

SELECT '✓ Contract Registry Setup Complete' AS STATUS;

SHOW TABLES IN SCHEMA GOVERNANCE.CONTRACT_REGISTRY;
SHOW VIEWS IN SCHEMA GOVERNANCE.CONTRACT_REGISTRY;

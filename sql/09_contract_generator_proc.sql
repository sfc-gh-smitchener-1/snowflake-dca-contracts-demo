-- ============================================================================
-- GENERIC CONTRACT GENERATOR - Snowflake Stored Procedure
-- ============================================================================
-- This script creates a stored procedure that can generate data contracts
-- directly from any Snowflake table schema.
-- ============================================================================

USE ROLE DATA_ADMIN;
USE DATABASE GOVERNANCE;
USE SCHEMA CONTRACT_REGISTRY;
USE WAREHOUSE TRANSFORM_WH;

-- ─────────────────────────────────────────────────────────────────────────────
-- FUNCTION: Infer PII Type from Column Name
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION GOVERNANCE.CONTRACT_REGISTRY.INFER_PII_TYPE(column_name VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
    CASE 
        -- HIGH PII
        WHEN LOWER(column_name) REGEXP '.*ssn.*|.*social_security.*|.*tax_id.*|.*passport.*|.*driver.*license.*|.*credit_card.*|.*bank_account.*'
            THEN 'HIGH'
        -- MODERATE PII
        WHEN LOWER(column_name) REGEXP '.*email.*|.*phone.*|.*address.*|.*dob.*|.*birth.*date.*|.*salary.*|.*income.*'
            THEN 'MODERATE'
        WHEN LOWER(column_name) REGEXP '.*name.*' AND LOWER(column_name) NOT REGEXP '.*key.*|.*_name$'
            THEN 'MODERATE'
        -- LOW PII
        WHEN LOWER(column_name) REGEXP '.*ip_address.*|.*device_id.*|.*user_agent.*|.*location.*|.*zip.*|.*postal.*'
            THEN 'LOW'
        ELSE 'NONE'
    END
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- FUNCTION: Infer Data Classification
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION GOVERNANCE.CONTRACT_REGISTRY.INFER_CLASSIFICATION(
    column_name VARCHAR, 
    pii_type VARCHAR
)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
    CASE 
        WHEN pii_type IN ('HIGH', 'MODERATE') THEN 'CONFIDENTIAL'
        WHEN LOWER(column_name) REGEXP '.*price.*|.*cost.*|.*revenue.*|.*profit.*|.*balance.*|.*amount.*|.*salary.*|.*wage.*'
            THEN 'CONFIDENTIAL'
        WHEN LOWER(column_name) REGEXP '.*_id$|.*_key$|^id_.*|^key_.*'
            THEN 'INTERNAL'
        ELSE 'INTERNAL'
    END
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- FUNCTION: Infer AI Allowed
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION GOVERNANCE.CONTRACT_REGISTRY.INFER_AI_ALLOWED(
    pii_type VARCHAR, 
    classification VARCHAR
)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
    CASE 
        WHEN pii_type = 'HIGH' THEN 'FALSE'
        WHEN pii_type = 'MODERATE' THEN 'PSEUDONYMIZED_ONLY'
        WHEN classification = 'RESTRICTED' THEN 'FALSE'
        ELSE 'TRUE'
    END
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- VIEW: Generate Contract Columns with Tags
-- This view provides column info with inferred governance tags
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE VIEW GOVERNANCE.CONTRACT_REGISTRY.VW_COLUMN_INFERENCE AS
SELECT
    TABLE_CATALOG AS DATABASE_NAME,
    TABLE_SCHEMA AS SCHEMA_NAME,
    TABLE_NAME,
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE,
    COMMENT AS COLUMN_COMMENT,
    ORDINAL_POSITION,
    GOVERNANCE.CONTRACT_REGISTRY.INFER_PII_TYPE(COLUMN_NAME) AS INFERRED_PII_TYPE,
    GOVERNANCE.CONTRACT_REGISTRY.INFER_CLASSIFICATION(
        COLUMN_NAME, 
        GOVERNANCE.CONTRACT_REGISTRY.INFER_PII_TYPE(COLUMN_NAME)
    ) AS INFERRED_CLASSIFICATION,
    GOVERNANCE.CONTRACT_REGISTRY.INFER_AI_ALLOWED(
        GOVERNANCE.CONTRACT_REGISTRY.INFER_PII_TYPE(COLUMN_NAME),
        GOVERNANCE.CONTRACT_REGISTRY.INFER_CLASSIFICATION(
            COLUMN_NAME, 
            GOVERNANCE.CONTRACT_REGISTRY.INFER_PII_TYPE(COLUMN_NAME)
        )
    ) AS INFERRED_AI_ALLOWED
FROM RAW_DEV.INFORMATION_SCHEMA.COLUMNS
UNION ALL
SELECT
    TABLE_CATALOG,
    TABLE_SCHEMA,
    TABLE_NAME,
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE,
    COMMENT,
    ORDINAL_POSITION,
    GOVERNANCE.CONTRACT_REGISTRY.INFER_PII_TYPE(COLUMN_NAME),
    GOVERNANCE.CONTRACT_REGISTRY.INFER_CLASSIFICATION(
        COLUMN_NAME, 
        GOVERNANCE.CONTRACT_REGISTRY.INFER_PII_TYPE(COLUMN_NAME)
    ),
    GOVERNANCE.CONTRACT_REGISTRY.INFER_AI_ALLOWED(
        GOVERNANCE.CONTRACT_REGISTRY.INFER_PII_TYPE(COLUMN_NAME),
        GOVERNANCE.CONTRACT_REGISTRY.INFER_CLASSIFICATION(
            COLUMN_NAME, 
            GOVERNANCE.CONTRACT_REGISTRY.INFER_PII_TYPE(COLUMN_NAME)
        )
    )
FROM CURATED_DEV.INFORMATION_SCHEMA.COLUMNS;

-- ─────────────────────────────────────────────────────────────────────────────
-- PROCEDURE: Generate Contract from Table (Simplified)
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE PROCEDURE GOVERNANCE.CONTRACT_REGISTRY.GENERATE_CONTRACT_FROM_TABLE(
    P_DATABASE VARCHAR,
    P_SCHEMA VARCHAR,
    P_TABLE VARCHAR,
    P_SYSTEM_NAME VARCHAR DEFAULT 'CUSTOM',
    P_PRODUCER_TEAM VARCHAR DEFAULT 'Data Engineering',
    P_PRODUCER_EMAIL VARCHAR DEFAULT 'data-eng@company.com',
    P_SLA_FRESHNESS_MINUTES INT DEFAULT 60,
    P_REGISTER_CONTRACT BOOLEAN DEFAULT FALSE
)
RETURNS VARIANT
LANGUAGE SQL
AS
$$
DECLARE
    v_contract_id VARCHAR;
    v_column_count INT DEFAULT 0;
    v_pii_count INT DEFAULT 0;
    v_has_confidential BOOLEAN DEFAULT FALSE;
    v_overall_classification VARCHAR DEFAULT 'INTERNAL';
    v_ai_eligibility VARCHAR DEFAULT 'TRUE';
    v_contract VARIANT;
BEGIN
    -- Generate contract ID
    v_contract_id := LOWER(:P_SYSTEM_NAME) || '_' || 
                     LOWER(REGEXP_REPLACE(:P_TABLE, '[^a-zA-Z0-9]', '_')) || '_v1';
    
    -- Get column counts and classification info
    SELECT 
        COUNT(*),
        SUM(CASE WHEN GOVERNANCE.CONTRACT_REGISTRY.INFER_PII_TYPE(COLUMN_NAME) IN ('HIGH', 'MODERATE') THEN 1 ELSE 0 END),
        MAX(CASE WHEN GOVERNANCE.CONTRACT_REGISTRY.INFER_CLASSIFICATION(
            COLUMN_NAME, 
            GOVERNANCE.CONTRACT_REGISTRY.INFER_PII_TYPE(COLUMN_NAME)
        ) = 'CONFIDENTIAL' THEN 1 ELSE 0 END) = 1
    INTO v_column_count, v_pii_count, v_has_confidential
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_CATALOG = :P_DATABASE
      AND TABLE_SCHEMA = :P_SCHEMA
      AND TABLE_NAME = :P_TABLE;
    
    -- Determine overall classification
    IF (:v_has_confidential) THEN
        v_overall_classification := 'CONFIDENTIAL';
    END IF;
    
    -- Determine AI eligibility based on PII
    IF (:v_pii_count > 0) THEN
        v_ai_eligibility := 'PSEUDONYMIZED_ONLY';
    END IF;
    
    -- Build the contract as a VARIANT object
    v_contract := OBJECT_CONSTRUCT(
        'contract', OBJECT_CONSTRUCT(
            'id', :v_contract_id,
            'version', '1.0.0',
            'status', 'draft',
            'generated_at', CURRENT_TIMESTAMP(),
            'source', OBJECT_CONSTRUCT(
                'database', :P_DATABASE,
                'schema', :P_SCHEMA,
                'table', :P_TABLE,
                'column_count', :v_column_count,
                'pii_column_count', :v_pii_count
            ),
            'producer', OBJECT_CONSTRUCT(
                'system', :P_SYSTEM_NAME,
                'team', :P_PRODUCER_TEAM,
                'owner', :P_PRODUCER_EMAIL,
                'slack_channel', '#data-contracts'
            ),
            'sla', OBJECT_CONSTRUCT(
                'freshness_minutes', :P_SLA_FRESHNESS_MINUTES,
                'completeness_percent', 99.0,
                'availability_percent', 99.9
            ),
            'governance', OBJECT_CONSTRUCT(
                'classification', :v_overall_classification,
                'ai_eligibility', :v_ai_eligibility,
                'retention_days', 2555
            ),
            'notes', 'Auto-generated contract. Review column tags using VW_COLUMN_INFERENCE view.'
        )
    );
    
    -- Optionally register the contract
    IF (:P_REGISTER_CONTRACT) THEN
        INSERT INTO GOVERNANCE.CONTRACT_REGISTRY.CONTRACTS (
            CONTRACT_ID, CONTRACT_TYPE, VERSION, STATUS,
            PRODUCER_SYSTEM, PRODUCER_TEAM, PRODUCER_EMAIL,
            DESCRIPTION, YAML_DEFINITION
        ) VALUES (
            :v_contract_id, 
            'data', 
            '1.0.0', 
            'draft',
            :P_SYSTEM_NAME, 
            :P_PRODUCER_TEAM, 
            :P_PRODUCER_EMAIL,
            'Auto-generated contract for ' || :P_DATABASE || '.' || :P_SCHEMA || '.' || :P_TABLE,
            :v_contract
        );
    END IF;
    
    RETURN v_contract;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- VIEW: Tables Available for Contract Generation
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE VIEW GOVERNANCE.CONTRACT_REGISTRY.VW_TABLES_FOR_CONTRACTS AS
SELECT
    t.TABLE_CATALOG AS DATABASE_NAME,
    t.TABLE_SCHEMA AS SCHEMA_NAME,
    t.TABLE_NAME,
    t.TABLE_TYPE,
    t.ROW_COUNT,
    t.BYTES,
    t.CREATED AS TABLE_CREATED,
    t.LAST_ALTERED AS TABLE_LAST_ALTERED,
    COUNT(c.COLUMN_NAME) AS COLUMN_COUNT,
    SUM(CASE 
        WHEN GOVERNANCE.CONTRACT_REGISTRY.INFER_PII_TYPE(c.COLUMN_NAME) IN ('HIGH', 'MODERATE') 
        THEN 1 ELSE 0 
    END) AS PII_COLUMN_COUNT,
    MAX(CASE 
        WHEN GOVERNANCE.CONTRACT_REGISTRY.INFER_CLASSIFICATION(
            c.COLUMN_NAME, 
            GOVERNANCE.CONTRACT_REGISTRY.INFER_PII_TYPE(c.COLUMN_NAME)
        ) = 'CONFIDENTIAL' 
        THEN 'CONFIDENTIAL' ELSE 'INTERNAL' 
    END) AS RECOMMENDED_CLASSIFICATION,
    COALESCE(con.CONTRACT_ID, 'NOT_REGISTERED') AS CONTRACT_STATUS
FROM RAW_DEV.INFORMATION_SCHEMA.TABLES t
JOIN RAW_DEV.INFORMATION_SCHEMA.COLUMNS c 
    ON t.TABLE_CATALOG = c.TABLE_CATALOG 
    AND t.TABLE_SCHEMA = c.TABLE_SCHEMA 
    AND t.TABLE_NAME = c.TABLE_NAME
LEFT JOIN GOVERNANCE.CONTRACT_REGISTRY.CONTRACTS con 
    ON LOWER(con.PRODUCER_SYSTEM) || '_' || LOWER(REGEXP_REPLACE(t.TABLE_NAME, '[^a-zA-Z0-9]', '_')) || '_v1' = con.CONTRACT_ID
WHERE t.TABLE_TYPE = 'BASE TABLE'
GROUP BY t.TABLE_CATALOG, t.TABLE_SCHEMA, t.TABLE_NAME, t.TABLE_TYPE, 
         t.ROW_COUNT, t.BYTES, t.CREATED, t.LAST_ALTERED, con.CONTRACT_ID;

-- ─────────────────────────────────────────────────────────────────────────────
-- VERIFICATION
-- ─────────────────────────────────────────────────────────────────────────────

SELECT 'Contract Generator Objects Created Successfully' AS STATUS;

-- Show created functions
SHOW FUNCTIONS IN SCHEMA GOVERNANCE.CONTRACT_REGISTRY;

-- Example: View inferred column tags
-- SELECT * FROM GOVERNANCE.CONTRACT_REGISTRY.VW_COLUMN_INFERENCE 
-- WHERE TABLE_NAME = 'CUSTOMER_RAW' LIMIT 20;

-- Example: Generate a contract from a table
-- CALL GOVERNANCE.CONTRACT_REGISTRY.GENERATE_CONTRACT_FROM_TABLE(
--     'RAW_DEV', 'RAW_TPCH', 'CUSTOMER_RAW', 'TPCH_DEMO'
-- );

-- Example: View tables available for contract generation
-- SELECT * FROM GOVERNANCE.CONTRACT_REGISTRY.VW_TABLES_FOR_CONTRACTS;

-- ============================================================================
-- GENERIC CONTRACT GENERATOR - Snowflake Stored Procedure
-- ============================================================================
-- This script creates a stored procedure that can generate data contracts
-- directly from any Snowflake table schema.
-- ============================================================================

USE ROLE ACCOUNTADMIN;
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
-- PROCEDURE: Generate Contract from Table
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
    v_columns ARRAY;
    v_column_defs ARRAY;
    v_quality_rules ARRAY;
    v_primary_key VARCHAR;
    v_overall_classification VARCHAR;
    v_ai_eligibility VARCHAR;
    v_contract VARIANT;
    v_col_name VARCHAR;
    v_col_type VARCHAR;
    v_is_nullable BOOLEAN;
    v_pii_type VARCHAR;
    v_classification VARCHAR;
    v_ai_allowed VARCHAR;
    v_rule_id INT := 1;
BEGIN
    -- Generate contract ID
    v_contract_id := LOWER(P_SYSTEM_NAME) || '_' || 
                     LOWER(REGEXP_REPLACE(P_TABLE, '[^a-zA-Z0-9]', '_')) || '_v1';
    
    -- Initialize arrays
    v_column_defs := ARRAY_CONSTRUCT();
    v_quality_rules := ARRAY_CONSTRUCT();
    
    -- Get primary key if exists
    SELECT LISTAGG(kcu.COLUMN_NAME, ',') INTO v_primary_key
    FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc
    JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE kcu 
        ON tc.CONSTRAINT_NAME = kcu.CONSTRAINT_NAME
        AND tc.TABLE_CATALOG = kcu.TABLE_CATALOG
        AND tc.TABLE_SCHEMA = kcu.TABLE_SCHEMA
    WHERE tc.TABLE_CATALOG = :P_DATABASE
      AND tc.TABLE_SCHEMA = :P_SCHEMA
      AND tc.TABLE_NAME = :P_TABLE
      AND tc.CONSTRAINT_TYPE = 'PRIMARY KEY';
    
    -- Process each column
    FOR col IN (
        SELECT 
            COLUMN_NAME,
            DATA_TYPE,
            IS_NULLABLE,
            COMMENT,
            ORDINAL_POSITION
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_CATALOG = :P_DATABASE
          AND TABLE_SCHEMA = :P_SCHEMA
          AND TABLE_NAME = :P_TABLE
        ORDER BY ORDINAL_POSITION
    ) DO
        v_col_name := col.COLUMN_NAME;
        v_col_type := col.DATA_TYPE;
        v_is_nullable := (col.IS_NULLABLE = 'YES');
        
        -- Skip if it's a system column
        IF (v_col_name LIKE '\\_%') THEN
            v_column_defs := ARRAY_APPEND(v_column_defs, OBJECT_CONSTRUCT(
                'name', v_col_name,
                'type', v_col_type,
                'description', COALESCE(col.COMMENT, 'System column ' || v_col_name),
                'constraints', IFF(v_is_nullable, ARRAY_CONSTRUCT(), ARRAY_CONSTRUCT('not_null')),
                'system_managed', TRUE
            ));
        ELSE
            -- Infer tags
            v_pii_type := GOVERNANCE.CONTRACT_REGISTRY.INFER_PII_TYPE(v_col_name);
            v_classification := GOVERNANCE.CONTRACT_REGISTRY.INFER_CLASSIFICATION(v_col_name, v_pii_type);
            v_ai_allowed := GOVERNANCE.CONTRACT_REGISTRY.INFER_AI_ALLOWED(v_pii_type, v_classification);
            
            -- Build column definition with tags
            LET col_def := OBJECT_CONSTRUCT(
                'name', v_col_name,
                'type', v_col_type,
                'description', COALESCE(col.COMMENT, 'Column ' || v_col_name),
                'constraints', IFF(v_is_nullable, ARRAY_CONSTRUCT(), ARRAY_CONSTRUCT('not_null')),
                'tags', OBJECT_CONSTRUCT(
                    'DATA_CLASSIFICATION', v_classification,
                    'PII_TYPE', v_pii_type,
                    'AI_ALLOWED', v_ai_allowed
                )
            );
            
            -- Add residency for PII columns
            IF (v_pii_type IN ('MODERATE', 'HIGH')) THEN
                col_def := OBJECT_INSERT(col_def, 'tags', 
                    OBJECT_INSERT(col_def:tags, 'RESIDENCY_REGION', 'ORIGIN'));
            END IF;
            
            v_column_defs := ARRAY_APPEND(v_column_defs, col_def);
        END IF;
    END FOR;
    
    -- Add system columns if they don't exist
    IF (NOT ARRAY_CONTAINS('_LOADED_AT'::VARIANT, v_column_defs)) THEN
        v_column_defs := ARRAY_APPEND(v_column_defs, OBJECT_CONSTRUCT(
            'name', '_LOADED_AT',
            'type', 'TIMESTAMP_NTZ',
            'description', 'Snowflake ingestion timestamp',
            'constraints', ARRAY_CONSTRUCT('not_null'),
            'system_managed', TRUE
        ));
        v_column_defs := ARRAY_APPEND(v_column_defs, OBJECT_CONSTRUCT(
            'name', '_SOURCE_FILE',
            'type', 'VARCHAR(1024)',
            'description', 'Source file or batch identifier',
            'system_managed', TRUE
        ));
        v_column_defs := ARRAY_APPEND(v_column_defs, OBJECT_CONSTRUCT(
            'name', '_ROW_HASH',
            'type', 'VARCHAR(64)',
            'description', 'SHA256 hash of business columns',
            'system_managed', TRUE
        ));
        v_column_defs := ARRAY_APPEND(v_column_defs, OBJECT_CONSTRUCT(
            'name', '_IS_CURRENT',
            'type', 'BOOLEAN',
            'description', 'Flag for current record version',
            'system_managed', TRUE
        ));
    END IF;
    
    -- Generate quality rules
    IF (v_primary_key IS NOT NULL) THEN
        v_quality_rules := ARRAY_APPEND(v_quality_rules, OBJECT_CONSTRUCT(
            'id', 'qr_' || LPAD(v_rule_id, 3, '0'),
            'name', 'valid_primary_key',
            'type', 'column_check',
            'column', v_primary_key,
            'sql', v_primary_key || ' IS NOT NULL',
            'severity', 'error'
        ));
        v_rule_id := v_rule_id + 1;
        
        v_quality_rules := ARRAY_APPEND(v_quality_rules, OBJECT_CONSTRUCT(
            'id', 'qr_' || LPAD(v_rule_id, 3, '0'),
            'name', 'no_duplicate_keys',
            'type', 'table_check',
            'sql', 'COUNT(*) = COUNT(DISTINCT ' || v_primary_key || ')',
            'severity', 'error'
        ));
        v_rule_id := v_rule_id + 1;
    END IF;
    
    -- Determine overall classification
    v_overall_classification := 'INTERNAL';
    FOR i IN 0 TO ARRAY_SIZE(v_column_defs) - 1 DO
        IF (v_column_defs[i]:tags:DATA_CLASSIFICATION::VARCHAR = 'CONFIDENTIAL') THEN
            v_overall_classification := 'CONFIDENTIAL';
        END IF;
    END FOR;
    
    -- Determine AI eligibility
    v_ai_eligibility := 'TRUE';
    FOR i IN 0 TO ARRAY_SIZE(v_column_defs) - 1 DO
        LET ai_val := v_column_defs[i]:tags:AI_ALLOWED::VARCHAR;
        IF (ai_val = 'FALSE') THEN
            v_ai_eligibility := 'FALSE';
        ELSEIF (ai_val = 'PSEUDONYMIZED_ONLY' AND v_ai_eligibility != 'FALSE') THEN
            v_ai_eligibility := 'PSEUDONYMIZED_ONLY';
        END IF;
    END FOR;
    
    -- Build the complete contract
    v_contract := OBJECT_CONSTRUCT(
        'contract', OBJECT_CONSTRUCT(
            'id', v_contract_id,
            'version', '1.0.0',
            'status', 'draft',
            'producer', OBJECT_CONSTRUCT(
                'system', P_SYSTEM_NAME,
                'team', P_PRODUCER_TEAM,
                'owner', P_PRODUCER_EMAIL,
                'slack_channel', '#data-contracts'
            ),
            'schema', OBJECT_CONSTRUCT(
                'database', P_DATABASE,
                'schema', P_SCHEMA,
                'table', P_TABLE,
                'columns', v_column_defs
            ),
            'sla', OBJECT_CONSTRUCT(
                'freshness', OBJECT_CONSTRUCT(
                    'max_age_minutes', P_SLA_FRESHNESS_MINUTES,
                    'measurement', 'MAX(_LOADED_AT) vs CURRENT_TIMESTAMP()'
                ),
                'completeness', OBJECT_CONSTRUCT(
                    'threshold_percent', 99.0,
                    'critical_columns', IFF(v_primary_key IS NOT NULL, 
                        ARRAY_CONSTRUCT(v_primary_key), ARRAY_CONSTRUCT())
                ),
                'availability', OBJECT_CONSTRUCT(
                    'uptime_percent', 99.9,
                    'maintenance_window', 'Sunday 02:00-04:00 UTC'
                ),
                'volume', OBJECT_CONSTRUCT(
                    'expected_daily_rows', OBJECT_CONSTRUCT(
                        'min', 1000,
                        'max', 1000000
                    ),
                    'alert_on_variance_percent', 25
                )
            ),
            'quality_rules', v_quality_rules,
            'governance', OBJECT_CONSTRUCT(
                'classification', v_overall_classification,
                'residency_requirements', ARRAY_CONSTRUCT(),
                'retention_days', 2555,
                'ai_eligibility', v_ai_eligibility
            ),
            'lineage', OBJECT_CONSTRUCT(
                'source_systems', ARRAY_CONSTRUCT(
                    OBJECT_CONSTRUCT(
                        'name', P_SYSTEM_NAME,
                        'connection', P_SYSTEM_NAME || '_CONNECTION',
                        'extraction', 'DIRECT_LOAD'
                    )
                ),
                'downstream_dependencies', ARRAY_CONSTRUCT()
            ),
            'consumers', ARRAY_CONSTRUCT()
        )
    );
    
    -- Optionally register the contract
    IF (P_REGISTER_CONTRACT) THEN
        INSERT INTO GOVERNANCE.CONTRACT_REGISTRY.CONTRACTS (
            CONTRACT_ID, CONTRACT_TYPE, VERSION, STATUS,
            PRODUCER_SYSTEM, PRODUCER_TEAM, PRODUCER_EMAIL,
            YAML_DEFINITION
        ) VALUES (
            v_contract_id, 'data', '1.0.0', 'draft',
            P_SYSTEM_NAME, P_PRODUCER_TEAM, P_PRODUCER_EMAIL,
            v_contract
        );
    END IF;
    
    RETURN v_contract;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- PROCEDURE: Generate Contracts for All Tables in Schema
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE PROCEDURE GOVERNANCE.CONTRACT_REGISTRY.GENERATE_CONTRACTS_FOR_SCHEMA(
    P_DATABASE VARCHAR,
    P_SCHEMA VARCHAR,
    P_SYSTEM_NAME VARCHAR DEFAULT 'CUSTOM',
    P_REGISTER_CONTRACTS BOOLEAN DEFAULT FALSE
)
RETURNS TABLE (table_name VARCHAR, contract_id VARCHAR, status VARCHAR)
LANGUAGE SQL
AS
$$
DECLARE
    res RESULTSET;
BEGIN
    CREATE OR REPLACE TEMPORARY TABLE _GENERATED_CONTRACTS (
        table_name VARCHAR,
        contract_id VARCHAR,
        status VARCHAR
    );
    
    FOR tbl IN (
        SELECT TABLE_NAME
        FROM INFORMATION_SCHEMA.TABLES
        WHERE TABLE_CATALOG = :P_DATABASE
          AND TABLE_SCHEMA = :P_SCHEMA
          AND TABLE_TYPE = 'BASE TABLE'
    ) DO
        BEGIN
            LET contract VARIANT := (
                CALL GOVERNANCE.CONTRACT_REGISTRY.GENERATE_CONTRACT_FROM_TABLE(
                    :P_DATABASE, :P_SCHEMA, tbl.TABLE_NAME, :P_SYSTEM_NAME,
                    'Data Engineering', 'data-eng@company.com', 60, :P_REGISTER_CONTRACTS
                )
            );
            
            INSERT INTO _GENERATED_CONTRACTS VALUES (
                tbl.TABLE_NAME,
                contract:contract:id::VARCHAR,
                'SUCCESS'
            );
        EXCEPTION
            WHEN OTHER THEN
                INSERT INTO _GENERATED_CONTRACTS VALUES (
                    tbl.TABLE_NAME,
                    NULL,
                    'ERROR: ' || SQLERRM
                );
        END;
    END FOR;
    
    res := (SELECT * FROM _GENERATED_CONTRACTS ORDER BY table_name);
    RETURN TABLE(res);
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- VERIFICATION
-- ─────────────────────────────────────────────────────────────────────────────

SELECT 'Contract Generator Procedures Created Successfully' AS STATUS;

-- Example: Generate a contract from a table
-- CALL GOVERNANCE.CONTRACT_REGISTRY.GENERATE_CONTRACT_FROM_TABLE(
--     'RAW_DEV', 'RAW_TPCH', 'CUSTOMER_RAW', 'TPCH_DEMO'
-- );

-- Example: Generate contracts for all tables in a schema
-- CALL GOVERNANCE.CONTRACT_REGISTRY.GENERATE_CONTRACTS_FOR_SCHEMA(
--     'RAW_DEV', 'RAW_TPCH', 'TPCH_DEMO', TRUE
-- );

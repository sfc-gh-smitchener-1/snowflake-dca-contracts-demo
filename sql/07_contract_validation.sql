-- ============================================================================
-- CONTRACT VALIDATION AND ENFORCEMENT
-- ============================================================================
-- This script creates procedures and views for:
--   1. Schema validation against contracts
--   2. Quality rule execution
--   3. SLA monitoring
--   4. Contract adherence scoring
-- ============================================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE GOVERNANCE;
USE SCHEMA CONTRACT_REGISTRY;
USE WAREHOUSE TRANSFORM_WH;

-- ─────────────────────────────────────────────────────────────────────────────
-- PROCEDURE: Validate Schema Against Contract
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE PROCEDURE GOVERNANCE.CONTRACT_REGISTRY.VALIDATE_SCHEMA(
    P_CONTRACT_ID VARCHAR,
    P_DATABASE VARCHAR,
    P_SCHEMA VARCHAR,
    P_TABLE VARCHAR
)
RETURNS VARIANT
LANGUAGE SQL
AS
$$
DECLARE
    v_result VARIANT;
    v_contract VARIANT;
    v_expected_columns ARRAY;
    v_actual_columns ARRAY;
    v_missing_columns ARRAY;
    v_extra_columns ARRAY;
    v_type_mismatches ARRAY;
    v_validation_passed BOOLEAN;
BEGIN
    -- Get contract definition
    SELECT YAML_DEFINITION INTO v_contract
    FROM GOVERNANCE.CONTRACT_REGISTRY.CONTRACTS
    WHERE CONTRACT_ID = :P_CONTRACT_ID 
    AND STATUS = 'active'
    ORDER BY VERSION DESC
    LIMIT 1;
    
    IF (v_contract IS NULL) THEN
        RETURN OBJECT_CONSTRUCT(
            'status', 'ERROR',
            'message', 'Contract not found or not active: ' || P_CONTRACT_ID
        );
    END IF;
    
    -- Get expected columns from contract
    SELECT ARRAY_AGG(VALUE:name::VARCHAR) INTO v_expected_columns
    FROM TABLE(FLATTEN(v_contract:contract:schema:columns));
    
    -- Get actual columns from table
    SELECT ARRAY_AGG(COLUMN_NAME) INTO v_actual_columns
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_CATALOG = :P_DATABASE
      AND TABLE_SCHEMA = :P_SCHEMA
      AND TABLE_NAME = :P_TABLE;
    
    -- Find missing columns
    SELECT ARRAY_AGG(VALUE) INTO v_missing_columns
    FROM TABLE(FLATTEN(v_expected_columns))
    WHERE VALUE NOT IN (SELECT VALUE FROM TABLE(FLATTEN(v_actual_columns)));
    
    -- Find extra columns (not in contract, excluding system columns)
    SELECT ARRAY_AGG(VALUE) INTO v_extra_columns
    FROM TABLE(FLATTEN(v_actual_columns))
    WHERE VALUE NOT IN (SELECT VALUE FROM TABLE(FLATTEN(v_expected_columns)))
      AND VALUE NOT LIKE '\_%';  -- Exclude system columns
    
    -- Check for type mismatches
    CREATE OR REPLACE TEMPORARY TABLE _TYPE_CHECK AS
    SELECT 
        c.VALUE:name::VARCHAR AS COLUMN_NAME,
        c.VALUE:type::VARCHAR AS EXPECTED_TYPE,
        ic.DATA_TYPE AS ACTUAL_TYPE
    FROM TABLE(FLATTEN(v_contract:contract:schema:columns)) c
    LEFT JOIN INFORMATION_SCHEMA.COLUMNS ic
        ON ic.TABLE_CATALOG = :P_DATABASE
        AND ic.TABLE_SCHEMA = :P_SCHEMA
        AND ic.TABLE_NAME = :P_TABLE
        AND ic.COLUMN_NAME = c.VALUE:name::VARCHAR;
    
    SELECT ARRAY_AGG(OBJECT_CONSTRUCT(
        'column', COLUMN_NAME,
        'expected', EXPECTED_TYPE,
        'actual', ACTUAL_TYPE
    )) INTO v_type_mismatches
    FROM _TYPE_CHECK
    WHERE ACTUAL_TYPE IS NOT NULL
      AND NOT (
          -- Allow common type equivalences
          (EXPECTED_TYPE LIKE 'VARCHAR%' AND ACTUAL_TYPE = 'TEXT') OR
          (EXPECTED_TYPE LIKE 'NUMBER%' AND ACTUAL_TYPE LIKE 'NUMBER%') OR
          (EXPECTED_TYPE = ACTUAL_TYPE)
      );
    
    -- Determine if validation passed
    v_validation_passed := (ARRAY_SIZE(v_missing_columns) = 0);
    
    -- Build result
    v_result := OBJECT_CONSTRUCT(
        'status', IFF(v_validation_passed, 'PASSED', 'FAILED'),
        'contract_id', P_CONTRACT_ID,
        'table', P_DATABASE || '.' || P_SCHEMA || '.' || P_TABLE,
        'validation_time', CURRENT_TIMESTAMP(),
        'expected_column_count', ARRAY_SIZE(v_expected_columns),
        'actual_column_count', ARRAY_SIZE(v_actual_columns),
        'missing_columns', COALESCE(v_missing_columns, ARRAY_CONSTRUCT()),
        'extra_columns', COALESCE(v_extra_columns, ARRAY_CONSTRUCT()),
        'type_mismatches', COALESCE(v_type_mismatches, ARRAY_CONSTRUCT())
    );
    
    -- Log validation result
    INSERT INTO GOVERNANCE.CONTRACT_REGISTRY.QUALITY_RULE_RESULTS (
        RESULT_ID, RULE_ID, CONTRACT_ID, EXECUTION_TIME, PASSED, RESULT_VALUE
    ) VALUES (
        UUID_STRING(),
        'schema_validation',
        :P_CONTRACT_ID,
        CURRENT_TIMESTAMP(),
        :v_validation_passed,
        :v_result
    );
    
    RETURN v_result;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- PROCEDURE: Execute Quality Rules for Contract
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE PROCEDURE GOVERNANCE.CONTRACT_REGISTRY.EXECUTE_QUALITY_RULES(
    P_CONTRACT_ID VARCHAR
)
RETURNS TABLE (rule_id VARCHAR, rule_name VARCHAR, passed BOOLEAN, message VARCHAR, execution_time TIMESTAMP_NTZ)
LANGUAGE SQL
AS
$$
DECLARE
    v_contract VARIANT;
    v_db VARCHAR;
    v_schema VARCHAR;
    v_table VARCHAR;
    v_full_table VARCHAR;
    v_rule_id VARCHAR;
    v_rule_name VARCHAR;
    v_rule_sql VARCHAR;
    v_rule_type VARCHAR;
    v_severity VARCHAR;
    v_passed BOOLEAN;
    v_error_msg VARCHAR;
    res RESULTSET;
BEGIN
    -- Create temp results table
    CREATE OR REPLACE TEMPORARY TABLE _RULE_RESULTS (
        rule_id VARCHAR,
        rule_name VARCHAR,
        passed BOOLEAN,
        message VARCHAR,
        execution_time TIMESTAMP_NTZ
    );
    
    -- Get contract
    SELECT YAML_DEFINITION INTO v_contract
    FROM GOVERNANCE.CONTRACT_REGISTRY.CONTRACTS
    WHERE CONTRACT_ID = :P_CONTRACT_ID AND STATUS = 'active'
    ORDER BY VERSION DESC LIMIT 1;
    
    IF (v_contract IS NULL) THEN
        INSERT INTO _RULE_RESULTS VALUES ('error', 'Contract Not Found', FALSE, 'Contract not found or inactive', CURRENT_TIMESTAMP());
        res := (SELECT * FROM _RULE_RESULTS);
        RETURN TABLE(res);
    END IF;
    
    -- Extract table info
    v_db := REPLACE(v_contract:contract:schema:database::VARCHAR, '${ENV}', 'DEV');
    v_schema := v_contract:contract:schema:schema::VARCHAR;
    v_table := v_contract:contract:schema:table::VARCHAR;
    v_full_table := v_db || '.' || v_schema || '.' || v_table;
    
    -- Process each quality rule
    FOR rule IN (
        SELECT VALUE AS rule_def
        FROM TABLE(FLATTEN(v_contract:contract:quality_rules))
    ) DO
        v_rule_id := rule.rule_def:id::VARCHAR;
        v_rule_name := rule.rule_def:name::VARCHAR;
        v_rule_sql := rule.rule_def:sql::VARCHAR;
        v_rule_type := rule.rule_def:type::VARCHAR;
        v_severity := rule.rule_def:severity::VARCHAR;
        
        BEGIN
            -- Execute the rule based on type
            IF (v_rule_type = 'column_check' OR v_rule_type = 'table_check') THEN
                -- Build and execute check query
                EXECUTE IMMEDIATE 
                    'SELECT CASE WHEN (' || v_rule_sql || ') THEN TRUE ELSE FALSE END FROM ' || v_full_table || ' WHERE _IS_CURRENT = TRUE LIMIT 1'
                    INTO v_passed;
                
                IF (v_passed IS NULL) THEN
                    -- Table might be empty, consider passed
                    v_passed := TRUE;
                END IF;
                
                INSERT INTO _RULE_RESULTS VALUES (
                    v_rule_id,
                    v_rule_name,
                    v_passed,
                    IFF(v_passed, 'Rule passed', 'Rule failed: ' || v_rule_sql),
                    CURRENT_TIMESTAMP()
                );
            ELSEIF (v_rule_type = 'cross_table_check') THEN
                -- Execute cross-table check directly
                v_rule_sql := REPLACE(v_rule_sql, '${ENV}', 'DEV');
                EXECUTE IMMEDIATE v_rule_sql INTO v_passed;
                
                INSERT INTO _RULE_RESULTS VALUES (
                    v_rule_id,
                    v_rule_name,
                    v_passed,
                    IFF(v_passed, 'Cross-table check passed', 'Cross-table check failed'),
                    CURRENT_TIMESTAMP()
                );
            END IF;
            
            -- Log result
            INSERT INTO GOVERNANCE.CONTRACT_REGISTRY.QUALITY_RULE_RESULTS (
                RESULT_ID, RULE_ID, CONTRACT_ID, EXECUTION_TIME, PASSED, RESULT_VALUE
            ) VALUES (
                UUID_STRING(), v_rule_id, :P_CONTRACT_ID, CURRENT_TIMESTAMP(), v_passed,
                OBJECT_CONSTRUCT('rule_name', v_rule_name, 'severity', v_severity)
            );
            
        EXCEPTION
            WHEN OTHER THEN
                v_error_msg := SQLERRM;
                INSERT INTO _RULE_RESULTS VALUES (
                    v_rule_id,
                    v_rule_name,
                    FALSE,
                    'Error executing rule: ' || v_error_msg,
                    CURRENT_TIMESTAMP()
                );
        END;
    END FOR;
    
    res := (SELECT * FROM _RULE_RESULTS ORDER BY execution_time);
    RETURN TABLE(res);
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- PROCEDURE: Check Freshness SLA
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE PROCEDURE GOVERNANCE.CONTRACT_REGISTRY.CHECK_FRESHNESS_SLA(
    P_CONTRACT_ID VARCHAR
)
RETURNS VARIANT
LANGUAGE SQL
AS
$$
DECLARE
    v_contract VARIANT;
    v_db VARCHAR;
    v_schema VARCHAR;
    v_table VARCHAR;
    v_full_table VARCHAR;
    v_max_age_minutes INT;
    v_actual_age_minutes INT;
    v_last_loaded TIMESTAMP_NTZ;
    v_is_violation BOOLEAN;
    v_result VARIANT;
BEGIN
    -- Get contract
    SELECT YAML_DEFINITION INTO v_contract
    FROM GOVERNANCE.CONTRACT_REGISTRY.CONTRACTS
    WHERE CONTRACT_ID = :P_CONTRACT_ID AND STATUS = 'active'
    ORDER BY VERSION DESC LIMIT 1;
    
    IF (v_contract IS NULL) THEN
        RETURN OBJECT_CONSTRUCT('status', 'ERROR', 'message', 'Contract not found');
    END IF;
    
    -- Extract SLA and table info
    v_max_age_minutes := v_contract:contract:sla:freshness:max_age_minutes::INT;
    v_db := REPLACE(v_contract:contract:schema:database::VARCHAR, '${ENV}', 'DEV');
    v_schema := v_contract:contract:schema:schema::VARCHAR;
    v_table := v_contract:contract:schema:table::VARCHAR;
    v_full_table := v_db || '.' || v_schema || '.' || v_table;
    
    -- Get actual freshness
    EXECUTE IMMEDIATE 'SELECT MAX(_LOADED_AT) FROM ' || v_full_table || ' WHERE _IS_CURRENT = TRUE'
        INTO v_last_loaded;
    
    v_actual_age_minutes := TIMESTAMPDIFF('minute', v_last_loaded, CURRENT_TIMESTAMP());
    v_is_violation := (v_actual_age_minutes > v_max_age_minutes);
    
    v_result := OBJECT_CONSTRUCT(
        'contract_id', P_CONTRACT_ID,
        'table', v_full_table,
        'sla_max_age_minutes', v_max_age_minutes,
        'actual_age_minutes', v_actual_age_minutes,
        'last_loaded_at', v_last_loaded,
        'checked_at', CURRENT_TIMESTAMP(),
        'status', IFF(v_is_violation, 'VIOLATION', IFF(v_actual_age_minutes > v_max_age_minutes * 0.8, 'WARNING', 'OK')),
        'is_violation', v_is_violation,
        'margin_minutes', v_max_age_minutes - v_actual_age_minutes
    );
    
    -- Log SLA metric
    INSERT INTO GOVERNANCE.CONTRACT_REGISTRY.SLA_METRICS (
        METRIC_ID, CONTRACT_ID, SLA_ID, MEASURED_VALUE, THRESHOLD_VALUE, 
        IS_VIOLATION, VIOLATION_SEVERITY, MEASURED_AT
    ) VALUES (
        UUID_STRING(),
        :P_CONTRACT_ID,
        'freshness',
        :v_actual_age_minutes,
        :v_max_age_minutes,
        :v_is_violation,
        IFF(v_is_violation, 'error', 'ok'),
        CURRENT_TIMESTAMP()
    );
    
    RETURN v_result;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- PROCEDURE: Calculate Contract Adherence Score
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE PROCEDURE GOVERNANCE.CONTRACT_REGISTRY.CALCULATE_ADHERENCE_SCORE(
    P_CONTRACT_ID VARCHAR
)
RETURNS VARIANT
LANGUAGE SQL
AS
$$
DECLARE
    v_quality_score FLOAT;
    v_freshness_score FLOAT;
    v_schema_score FLOAT;
    v_overall_score FLOAT;
    v_quality_rules_passed INT;
    v_quality_rules_total INT;
    v_freshness_ok BOOLEAN;
    v_schema_valid BOOLEAN;
    v_result VARIANT;
BEGIN
    -- Calculate quality score (last 24 hours)
    SELECT 
        COUNT(CASE WHEN PASSED THEN 1 END),
        COUNT(*)
    INTO v_quality_rules_passed, v_quality_rules_total
    FROM GOVERNANCE.CONTRACT_REGISTRY.QUALITY_RULE_RESULTS
    WHERE CONTRACT_ID = :P_CONTRACT_ID
      AND EXECUTION_TIME > DATEADD('hour', -24, CURRENT_TIMESTAMP())
      AND RULE_ID != 'schema_validation';
    
    v_quality_score := COALESCE(
        v_quality_rules_passed::FLOAT / NULLIF(v_quality_rules_total, 0) * 100,
        100  -- Default to 100 if no rules executed
    );
    
    -- Calculate freshness score
    SELECT NOT IS_VIOLATION INTO v_freshness_ok
    FROM GOVERNANCE.CONTRACT_REGISTRY.SLA_METRICS
    WHERE CONTRACT_ID = :P_CONTRACT_ID
      AND SLA_ID = 'freshness'
    ORDER BY MEASURED_AT DESC
    LIMIT 1;
    
    v_freshness_score := IFF(COALESCE(v_freshness_ok, TRUE), 100, 0);
    
    -- Check schema validation
    SELECT PASSED INTO v_schema_valid
    FROM GOVERNANCE.CONTRACT_REGISTRY.QUALITY_RULE_RESULTS
    WHERE CONTRACT_ID = :P_CONTRACT_ID
      AND RULE_ID = 'schema_validation'
    ORDER BY EXECUTION_TIME DESC
    LIMIT 1;
    
    v_schema_score := IFF(COALESCE(v_schema_valid, TRUE), 100, 0);
    
    -- Calculate overall score (weighted average)
    v_overall_score := (
        v_quality_score * 0.4 +      -- 40% weight for quality
        v_freshness_score * 0.35 +   -- 35% weight for freshness
        v_schema_score * 0.25        -- 25% weight for schema
    );
    
    v_result := OBJECT_CONSTRUCT(
        'contract_id', P_CONTRACT_ID,
        'calculated_at', CURRENT_TIMESTAMP(),
        'overall_score', ROUND(v_overall_score, 1),
        'quality_score', ROUND(v_quality_score, 1),
        'quality_rules_passed', v_quality_rules_passed,
        'quality_rules_total', v_quality_rules_total,
        'freshness_score', v_freshness_score,
        'schema_score', v_schema_score,
        'grade', CASE 
            WHEN v_overall_score >= 95 THEN 'A'
            WHEN v_overall_score >= 85 THEN 'B'
            WHEN v_overall_score >= 75 THEN 'C'
            WHEN v_overall_score >= 60 THEN 'D'
            ELSE 'F'
        END
    );
    
    RETURN v_result;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- PROCEDURE: Run All Validations for Contract
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE PROCEDURE GOVERNANCE.CONTRACT_REGISTRY.VALIDATE_CONTRACT(
    P_CONTRACT_ID VARCHAR
)
RETURNS VARIANT
LANGUAGE SQL
AS
$$
DECLARE
    v_contract VARIANT;
    v_db VARCHAR;
    v_schema VARCHAR;
    v_table VARCHAR;
    v_schema_result VARIANT;
    v_freshness_result VARIANT;
    v_adherence_result VARIANT;
BEGIN
    -- Get contract info
    SELECT YAML_DEFINITION INTO v_contract
    FROM GOVERNANCE.CONTRACT_REGISTRY.CONTRACTS
    WHERE CONTRACT_ID = :P_CONTRACT_ID AND STATUS = 'active'
    ORDER BY VERSION DESC LIMIT 1;
    
    IF (v_contract IS NULL) THEN
        RETURN OBJECT_CONSTRUCT('status', 'ERROR', 'message', 'Contract not found');
    END IF;
    
    -- Extract table info
    v_db := REPLACE(v_contract:contract:schema:database::VARCHAR, '${ENV}', 'DEV');
    v_schema := v_contract:contract:schema:schema::VARCHAR;
    v_table := v_contract:contract:schema:table::VARCHAR;
    
    -- Run schema validation
    CALL GOVERNANCE.CONTRACT_REGISTRY.VALIDATE_SCHEMA(:P_CONTRACT_ID, :v_db, :v_schema, :v_table)
        INTO v_schema_result;
    
    -- Run quality rules
    CALL GOVERNANCE.CONTRACT_REGISTRY.EXECUTE_QUALITY_RULES(:P_CONTRACT_ID);
    
    -- Check freshness
    CALL GOVERNANCE.CONTRACT_REGISTRY.CHECK_FRESHNESS_SLA(:P_CONTRACT_ID)
        INTO v_freshness_result;
    
    -- Calculate adherence score
    CALL GOVERNANCE.CONTRACT_REGISTRY.CALCULATE_ADHERENCE_SCORE(:P_CONTRACT_ID)
        INTO v_adherence_result;
    
    RETURN OBJECT_CONSTRUCT(
        'contract_id', P_CONTRACT_ID,
        'validation_time', CURRENT_TIMESTAMP(),
        'schema_validation', v_schema_result,
        'freshness_check', v_freshness_result,
        'adherence_score', v_adherence_result
    );
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- PROCEDURE: Validate All Active Contracts
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE PROCEDURE GOVERNANCE.CONTRACT_REGISTRY.VALIDATE_ALL_CONTRACTS()
RETURNS TABLE (contract_id VARCHAR, status VARCHAR, overall_score FLOAT, validated_at TIMESTAMP_NTZ)
LANGUAGE SQL
AS
$$
DECLARE
    v_contract_id VARCHAR;
    v_result VARIANT;
    res RESULTSET;
BEGIN
    CREATE OR REPLACE TEMPORARY TABLE _VALIDATION_RESULTS (
        contract_id VARCHAR,
        status VARCHAR,
        overall_score FLOAT,
        validated_at TIMESTAMP_NTZ
    );
    
    FOR contract IN (
        SELECT DISTINCT CONTRACT_ID 
        FROM GOVERNANCE.CONTRACT_REGISTRY.CONTRACTS 
        WHERE STATUS = 'active'
    ) DO
        v_contract_id := contract.CONTRACT_ID;
        
        BEGIN
            CALL GOVERNANCE.CONTRACT_REGISTRY.VALIDATE_CONTRACT(:v_contract_id) INTO v_result;
            
            INSERT INTO _VALIDATION_RESULTS VALUES (
                v_contract_id,
                v_result:adherence_score:grade::VARCHAR,
                v_result:adherence_score:overall_score::FLOAT,
                CURRENT_TIMESTAMP()
            );
        EXCEPTION
            WHEN OTHER THEN
                INSERT INTO _VALIDATION_RESULTS VALUES (
                    v_contract_id,
                    'ERROR',
                    0,
                    CURRENT_TIMESTAMP()
                );
        END;
    END FOR;
    
    res := (SELECT * FROM _VALIDATION_RESULTS ORDER BY overall_score DESC);
    RETURN TABLE(res);
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- TASK: Scheduled Contract Validation
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE TASK GOVERNANCE.CONTRACT_REGISTRY.TASK_VALIDATE_ALL_CONTRACTS
    WAREHOUSE = TRANSFORM_WH
    SCHEDULE = 'USING CRON 0 * * * * UTC'  -- Every hour
    COMMENT = 'Hourly contract validation for all active contracts'
AS
    CALL GOVERNANCE.CONTRACT_REGISTRY.VALIDATE_ALL_CONTRACTS();

-- Enable the task (uncomment when ready)
-- ALTER TASK GOVERNANCE.CONTRACT_REGISTRY.TASK_VALIDATE_ALL_CONTRACTS RESUME;

-- ─────────────────────────────────────────────────────────────────────────────
-- VERIFICATION
-- ─────────────────────────────────────────────────────────────────────────────

SELECT 'Contract Validation Procedures Created Successfully' AS STATUS;

SHOW PROCEDURES IN SCHEMA GOVERNANCE.CONTRACT_REGISTRY;

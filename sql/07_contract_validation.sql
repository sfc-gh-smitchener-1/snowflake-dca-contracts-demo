-- ============================================================================
-- CONTRACT VALIDATION AND ENFORCEMENT
-- ============================================================================
-- This script creates views and simple procedures for:
--   1. Contract status tracking
--   2. Quality metrics monitoring  
--   3. SLA monitoring views
--   4. Contract adherence scoring
-- ============================================================================

USE ROLE DATA_ADMIN;
USE DATABASE GOVERNANCE;
USE SCHEMA CONTRACT_REGISTRY;
USE WAREHOUSE TRANSFORM_WH;

-- ─────────────────────────────────────────────────────────────────────────────
-- VIEW: Contract Status Summary
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE VIEW GOVERNANCE.CONTRACT_REGISTRY.VW_CONTRACT_STATUS AS
SELECT 
    c.CONTRACT_ID,
    c.CONTRACT_TYPE,
    c.VERSION,
    c.STATUS,
    c.PRODUCER_SYSTEM,
    c.PRODUCER_EMAIL,
    c.DESCRIPTION,
    COALESCE(cc.CONSUMER_COUNT, 0) AS CONSUMER_COUNT,
    c.CREATED_AT,
    c.UPDATED_AT
FROM GOVERNANCE.CONTRACT_REGISTRY.CONTRACTS c
LEFT JOIN (
    SELECT CONTRACT_ID, COUNT(*) AS CONSUMER_COUNT
    FROM GOVERNANCE.CONTRACT_REGISTRY.CONTRACT_CONSUMERS
    GROUP BY CONTRACT_ID
) cc ON c.CONTRACT_ID = cc.CONTRACT_ID
WHERE c.STATUS = 'active';

-- ─────────────────────────────────────────────────────────────────────────────
-- VIEW: Quality Rule Execution Summary
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE VIEW GOVERNANCE.CONTRACT_REGISTRY.VW_QUALITY_RULE_SUMMARY AS
SELECT
    CONTRACT_ID,
    COUNT(*) AS TOTAL_EXECUTIONS,
    SUM(CASE WHEN PASSED THEN 1 ELSE 0 END) AS PASSED_COUNT,
    SUM(CASE WHEN NOT PASSED THEN 1 ELSE 0 END) AS FAILED_COUNT,
    ROUND(SUM(CASE WHEN PASSED THEN 1 ELSE 0 END)::FLOAT / NULLIF(COUNT(*), 0) * 100, 2) AS PASS_RATE_PCT,
    MAX(EXECUTION_TIME) AS LAST_EXECUTION,
    MIN(EXECUTION_TIME) AS FIRST_EXECUTION
FROM GOVERNANCE.CONTRACT_REGISTRY.QUALITY_RULE_RESULTS
WHERE EXECUTION_TIME > DATEADD('day', -7, CURRENT_TIMESTAMP())
GROUP BY CONTRACT_ID;

-- ─────────────────────────────────────────────────────────────────────────────
-- VIEW: SLA Compliance Summary
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE VIEW GOVERNANCE.CONTRACT_REGISTRY.VW_SLA_COMPLIANCE_SUMMARY AS
SELECT
    CONTRACT_ID,
    SLA_ID,
    COUNT(*) AS TOTAL_CHECKS,
    SUM(CASE WHEN IS_VIOLATION THEN 1 ELSE 0 END) AS VIOLATIONS,
    ROUND((1 - SUM(CASE WHEN IS_VIOLATION THEN 1 ELSE 0 END)::FLOAT / NULLIF(COUNT(*), 0)) * 100, 2) AS COMPLIANCE_PCT,
    MAX(MEASURED_AT) AS LAST_CHECK,
    AVG(MEASURED_VALUE) AS AVG_MEASURED_VALUE
FROM GOVERNANCE.CONTRACT_REGISTRY.SLA_METRICS
WHERE MEASURED_AT > DATEADD('day', -7, CURRENT_TIMESTAMP())
GROUP BY CONTRACT_ID, SLA_ID;

-- ─────────────────────────────────────────────────────────────────────────────
-- VIEW: Latest SLA Status per Contract
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE VIEW GOVERNANCE.CONTRACT_REGISTRY.VW_LATEST_SLA_STATUS AS
SELECT 
    s.*
FROM GOVERNANCE.CONTRACT_REGISTRY.SLA_METRICS s
INNER JOIN (
    SELECT CONTRACT_ID, SLA_ID, MAX(MEASURED_AT) AS MAX_MEASURED
    FROM GOVERNANCE.CONTRACT_REGISTRY.SLA_METRICS
    GROUP BY CONTRACT_ID, SLA_ID
) latest ON s.CONTRACT_ID = latest.CONTRACT_ID 
         AND s.SLA_ID = latest.SLA_ID 
         AND s.MEASURED_AT = latest.MAX_MEASURED;

-- ─────────────────────────────────────────────────────────────────────────────
-- VIEW: Contract Columns with Tags
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE VIEW GOVERNANCE.CONTRACT_REGISTRY.VW_COLUMN_GOVERNANCE AS
SELECT
    cc.CONTRACT_ID,
    cc.COLUMN_NAME,
    cc.DATA_TYPE,
    cc.IS_NULLABLE,
    cc.IS_PRIMARY_KEY,
    cc.DESCRIPTION,
    MAX(CASE WHEN ct.TAG_NAME = 'DATA_CLASSIFICATION' THEN ct.TAG_VALUE END) AS DATA_CLASSIFICATION,
    MAX(CASE WHEN ct.TAG_NAME = 'PII_TYPE' THEN ct.TAG_VALUE END) AS PII_TYPE,
    MAX(CASE WHEN ct.TAG_NAME = 'AI_ALLOWED' THEN ct.TAG_VALUE END) AS AI_ALLOWED
FROM GOVERNANCE.CONTRACT_REGISTRY.CONTRACT_COLUMNS cc
LEFT JOIN GOVERNANCE.CONTRACT_REGISTRY.COLUMN_TAGS ct 
    ON cc.COLUMN_ID = ct.COLUMN_ID
GROUP BY cc.CONTRACT_ID, cc.COLUMN_ID, cc.COLUMN_NAME, cc.DATA_TYPE, 
         cc.IS_NULLABLE, cc.IS_PRIMARY_KEY, cc.DESCRIPTION;

-- ─────────────────────────────────────────────────────────────────────────────
-- PROCEDURE: Log Quality Rule Result (Simple)
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE PROCEDURE GOVERNANCE.CONTRACT_REGISTRY.LOG_QUALITY_RESULT(
    P_CONTRACT_ID VARCHAR,
    P_RULE_ID VARCHAR,
    P_PASSED BOOLEAN,
    P_MESSAGE VARCHAR
)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
BEGIN
    INSERT INTO GOVERNANCE.CONTRACT_REGISTRY.QUALITY_RULE_RESULTS (
        RESULT_ID, RULE_ID, CONTRACT_ID, EXECUTION_TIME, PASSED, RESULT_VALUE
    ) VALUES (
        UUID_STRING(),
        :P_RULE_ID,
        :P_CONTRACT_ID,
        CURRENT_TIMESTAMP(),
        :P_PASSED,
        PARSE_JSON('{"message": "' || :P_MESSAGE || '"}')
    );
    
    RETURN 'Logged result for rule ' || :P_RULE_ID || ': ' || IFF(:P_PASSED, 'PASSED', 'FAILED');
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- PROCEDURE: Log SLA Metric
-- ─────────────────────────────────────────────────────────────────────────────
--
CREATE OR REPLACE PROCEDURE GOVERNANCE.CONTRACT_REGISTRY.LOG_SLA_METRIC(
    P_CONTRACT_ID VARCHAR,
    P_SLA_ID VARCHAR,
    P_MEASURED_VALUE FLOAT,
    P_THRESHOLD_VALUE FLOAT
)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    v_is_violation BOOLEAN;
    v_severity VARCHAR;
BEGIN
    v_is_violation := (:P_MEASURED_VALUE > :P_THRESHOLD_VALUE);
    v_severity := IFF(v_is_violation, 'error', 'ok');
    
    INSERT INTO GOVERNANCE.CONTRACT_REGISTRY.SLA_METRICS (
        METRIC_ID, CONTRACT_ID, SLA_ID, MEASURED_VALUE, THRESHOLD_VALUE, 
        IS_VIOLATION, VIOLATION_SEVERITY, MEASURED_AT
    ) VALUES (
        UUID_STRING(),
        :P_CONTRACT_ID,
        :P_SLA_ID,
        :P_MEASURED_VALUE,
        :P_THRESHOLD_VALUE,
        :v_is_violation,
        :v_severity,
        CURRENT_TIMESTAMP()
    );
    
    RETURN 'Logged SLA metric for ' || :P_SLA_ID || ': ' || 
           :P_MEASURED_VALUE::VARCHAR || ' / ' || :P_THRESHOLD_VALUE::VARCHAR || 
           ' - ' || IFF(:v_is_violation, 'VIOLATION', 'OK');
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- PROCEDURE: Calculate Contract Score
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE PROCEDURE GOVERNANCE.CONTRACT_REGISTRY.CALCULATE_CONTRACT_SCORE(
    P_CONTRACT_ID VARCHAR
)
RETURNS VARIANT
LANGUAGE SQL
AS
$$
DECLARE
    v_quality_score FLOAT DEFAULT 100;
    v_sla_score FLOAT DEFAULT 100;
    v_overall_score FLOAT;
    v_rules_passed INT DEFAULT 0;
    v_rules_total INT DEFAULT 0;
    v_sla_violations INT DEFAULT 0;
    v_sla_checks INT DEFAULT 0;
    v_grade VARCHAR;
BEGIN
    -- Get quality score from last 24 hours
    SELECT 
        COALESCE(SUM(CASE WHEN PASSED THEN 1 ELSE 0 END), 0),
        COALESCE(COUNT(*), 0)
    INTO v_rules_passed, v_rules_total
    FROM GOVERNANCE.CONTRACT_REGISTRY.QUALITY_RULE_RESULTS
    WHERE CONTRACT_ID = :P_CONTRACT_ID
      AND EXECUTION_TIME > DATEADD('hour', -24, CURRENT_TIMESTAMP());
    
    IF (v_rules_total > 0) THEN
        v_quality_score := (v_rules_passed::FLOAT / v_rules_total) * 100;
    END IF;
    
    -- Get SLA compliance from last 24 hours
    SELECT 
        COALESCE(SUM(CASE WHEN IS_VIOLATION THEN 1 ELSE 0 END), 0),
        COALESCE(COUNT(*), 0)
    INTO v_sla_violations, v_sla_checks
    FROM GOVERNANCE.CONTRACT_REGISTRY.SLA_METRICS
    WHERE CONTRACT_ID = :P_CONTRACT_ID
      AND MEASURED_AT > DATEADD('hour', -24, CURRENT_TIMESTAMP());
    
    IF (v_sla_checks > 0) THEN
        v_sla_score := ((v_sla_checks - v_sla_violations)::FLOAT / v_sla_checks) * 100;
    END IF;
    
    -- Calculate overall score (weighted)
    v_overall_score := (v_quality_score * 0.5) + (v_sla_score * 0.5);
    
    -- Determine grade
    v_grade := CASE 
        WHEN v_overall_score >= 95 THEN 'A'
        WHEN v_overall_score >= 85 THEN 'B'
        WHEN v_overall_score >= 75 THEN 'C'
        WHEN v_overall_score >= 60 THEN 'D'
        ELSE 'F'
    END;
    
    RETURN OBJECT_CONSTRUCT(
        'contract_id', :P_CONTRACT_ID,
        'calculated_at', CURRENT_TIMESTAMP(),
        'overall_score', ROUND(:v_overall_score, 1),
        'quality_score', ROUND(:v_quality_score, 1),
        'sla_score', ROUND(:v_sla_score, 1),
        'rules_passed', :v_rules_passed,
        'rules_total', :v_rules_total,
        'sla_violations', :v_sla_violations,
        'sla_checks', :v_sla_checks,
        'grade', :v_grade
    );
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- PROCEDURE: Simple Contract Validation
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE PROCEDURE GOVERNANCE.CONTRACT_REGISTRY.VALIDATE_CONTRACT(
    P_CONTRACT_ID VARCHAR
)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    v_contract_exists BOOLEAN DEFAULT FALSE;
    v_contract_type VARCHAR;
    v_status VARCHAR;
BEGIN
    -- Check if contract exists
    SELECT TRUE, CONTRACT_TYPE, STATUS
    INTO v_contract_exists, v_contract_type, v_status
    FROM GOVERNANCE.CONTRACT_REGISTRY.CONTRACTS
    WHERE CONTRACT_ID = :P_CONTRACT_ID
    ORDER BY VERSION DESC
    LIMIT 1;
    
    IF (NOT v_contract_exists) THEN
        RETURN 'ERROR: Contract not found - ' || :P_CONTRACT_ID;
    END IF;
    
    IF (:v_status != 'active') THEN
        RETURN 'WARNING: Contract is not active - Status: ' || :v_status;
    END IF;
    
    -- Log validation event
    CALL GOVERNANCE.CONTRACT_REGISTRY.LOG_QUALITY_RESULT(
        :P_CONTRACT_ID, 
        'contract_validation', 
        TRUE, 
        'Contract validated successfully'
    );
    
    RETURN 'OK: Contract validated - ' || :P_CONTRACT_ID || ' (type: ' || :v_contract_type || ')';
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- TASK: Scheduled Contract Validation (Disabled by default)
-- ─────────────────────────────────────────────────────────────────────────────

-- Note: This task validates contracts hourly when enabled
-- To enable: ALTER TASK GOVERNANCE.CONTRACT_REGISTRY.TASK_HOURLY_VALIDATION RESUME;

CREATE OR REPLACE TASK GOVERNANCE.CONTRACT_REGISTRY.TASK_HOURLY_VALIDATION
    WAREHOUSE = TRANSFORM_WH
    SCHEDULE = 'USING CRON 0 * * * * UTC'  -- Every hour
    COMMENT = 'Hourly contract validation for demo purposes'
AS
    SELECT 'Validation task placeholder - customize as needed';

-- ─────────────────────────────────────────────────────────────────────────────
-- SAMPLE DATA: Insert Initial Quality Rule Results for Demo
-- ─────────────────────────────────────────────────────────────────────────────

-- Log some sample quality results for demo contracts
INSERT INTO GOVERNANCE.CONTRACT_REGISTRY.QUALITY_RULE_RESULTS 
    (RESULT_ID, RULE_ID, CONTRACT_ID, EXECUTION_TIME, PASSED, RESULT_VALUE)
SELECT 
    UUID_STRING(),
    'demo_rule_' || SEQ4()::VARCHAR,
    'tpch_customer_v1',
    DATEADD('minute', -SEQ4() * 30, CURRENT_TIMESTAMP()),
    TRUE,
    PARSE_JSON('{"message": "Demo rule passed"}')
FROM TABLE(GENERATOR(ROWCOUNT => 10));

INSERT INTO GOVERNANCE.CONTRACT_REGISTRY.QUALITY_RULE_RESULTS 
    (RESULT_ID, RULE_ID, CONTRACT_ID, EXECUTION_TIME, PASSED, RESULT_VALUE)
SELECT 
    UUID_STRING(),
    'demo_rule_' || SEQ4()::VARCHAR,
    'tpch_orders_v1',
    DATEADD('minute', -SEQ4() * 30, CURRENT_TIMESTAMP()),
    TRUE,
    PARSE_JSON('{"message": "Demo rule passed"}')
FROM TABLE(GENERATOR(ROWCOUNT => 10));

-- Log some sample SLA metrics for demo
INSERT INTO GOVERNANCE.CONTRACT_REGISTRY.SLA_METRICS 
    (METRIC_ID, CONTRACT_ID, SLA_ID, MEASURED_VALUE, THRESHOLD_VALUE, IS_VIOLATION, VIOLATION_SEVERITY, MEASURED_AT)
SELECT 
    UUID_STRING(),
    'tpch_customer_v1',
    'freshness',
    30 + (RANDOM() % 20),  -- 30-50 minutes
    60,  -- 60 minute threshold
    FALSE,
    'ok',
    DATEADD('hour', -SEQ4(), CURRENT_TIMESTAMP())
FROM TABLE(GENERATOR(ROWCOUNT => 24));

-- ─────────────────────────────────────────────────────────────────────────────
-- VERIFICATION
-- ─────────────────────────────────────────────────────────────────────────────

SELECT 'Contract Validation Objects Created Successfully' AS STATUS;

-- Show created views
SHOW VIEWS IN SCHEMA GOVERNANCE.CONTRACT_REGISTRY;

-- Show created procedures
SHOW PROCEDURES IN SCHEMA GOVERNANCE.CONTRACT_REGISTRY;

-- Test the score calculation
SELECT 'Testing contract score calculation...' AS STATUS;
-- CALL GOVERNANCE.CONTRACT_REGISTRY.CALCULATE_CONTRACT_SCORE('tpch_customer_v1');

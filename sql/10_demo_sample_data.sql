-- ============================================================================
-- DEMO SAMPLE DATA - Populate Contract Registry for Demo
-- ============================================================================
-- This script inserts sample data into the contract registry to demonstrate
-- the observability dashboard and semantic models.
-- Run this AFTER all other setup scripts.
-- ============================================================================

USE ROLE DATA_ADMIN;
USE DATABASE GOVERNANCE;
USE SCHEMA CONTRACT_REGISTRY;
USE WAREHOUSE TRANSFORM_WH;

-- ─────────────────────────────────────────────────────────────────────────────
-- REGISTER SAMPLE CONTRACTS (using INSERT-SELECT for PARSE_JSON)
-- ─────────────────────────────────────────────────────────────────────────────

-- TPCH Customer Contract
INSERT INTO CONTRACTS (CONTRACT_ID, CONTRACT_TYPE, VERSION, STATUS, PRODUCER_SYSTEM, PRODUCER_EMAIL, DESCRIPTION, YAML_DEFINITION)
SELECT 'tpch_customer_v1', 'data', '1.0.0', 'active', 'TPCH_DEMO', 'data-eng@company.com', 
       'TPCH Customer master data contract',
       PARSE_JSON('{"contract":{"id":"tpch_customer_v1","sla":{"freshness_minutes":60}}}');

-- TPCH Orders Contract
INSERT INTO CONTRACTS (CONTRACT_ID, CONTRACT_TYPE, VERSION, STATUS, PRODUCER_SYSTEM, PRODUCER_EMAIL, DESCRIPTION, YAML_DEFINITION)
SELECT 'tpch_orders_v1', 'data', '1.0.0', 'active', 'TPCH_DEMO', 'data-eng@company.com',
       'TPCH Orders transaction data contract',
       PARSE_JSON('{"contract":{"id":"tpch_orders_v1","sla":{"freshness_minutes":30}}}');

-- TPCH Lineitem Contract
INSERT INTO CONTRACTS (CONTRACT_ID, CONTRACT_TYPE, VERSION, STATUS, PRODUCER_SYSTEM, PRODUCER_EMAIL, DESCRIPTION, YAML_DEFINITION)
SELECT 'tpch_lineitem_v1', 'data', '1.0.0', 'active', 'TPCH_DEMO', 'data-eng@company.com',
       'TPCH Line Item detail data contract',
       PARSE_JSON('{"contract":{"id":"tpch_lineitem_v1","sla":{"freshness_minutes":30}}}');

-- TPCH Part Contract
INSERT INTO CONTRACTS (CONTRACT_ID, CONTRACT_TYPE, VERSION, STATUS, PRODUCER_SYSTEM, PRODUCER_EMAIL, DESCRIPTION, YAML_DEFINITION)
SELECT 'tpch_part_v1', 'data', '1.0.0', 'active', 'TPCH_DEMO', 'data-eng@company.com',
       'TPCH Part master data contract',
       PARSE_JSON('{"contract":{"id":"tpch_part_v1","sla":{"freshness_minutes":120}}}');

-- TPCH Supplier Contract
INSERT INTO CONTRACTS (CONTRACT_ID, CONTRACT_TYPE, VERSION, STATUS, PRODUCER_SYSTEM, PRODUCER_EMAIL, DESCRIPTION, YAML_DEFINITION)
SELECT 'tpch_supplier_v1', 'data', '1.0.0', 'active', 'TPCH_DEMO', 'data-eng@company.com',
       'TPCH Supplier master data contract',
       PARSE_JSON('{"contract":{"id":"tpch_supplier_v1","sla":{"freshness_minutes":120}}}');

-- TPCH Nation Contract
INSERT INTO CONTRACTS (CONTRACT_ID, CONTRACT_TYPE, VERSION, STATUS, PRODUCER_SYSTEM, PRODUCER_EMAIL, DESCRIPTION, YAML_DEFINITION)
SELECT 'tpch_nation_v1', 'data', '1.0.0', 'active', 'TPCH_DEMO', 'data-eng@company.com',
       'TPCH Nation reference data contract',
       PARSE_JSON('{"contract":{"id":"tpch_nation_v1","sla":{"freshness_minutes":1440}}}');

-- TPCH Region Contract
INSERT INTO CONTRACTS (CONTRACT_ID, CONTRACT_TYPE, VERSION, STATUS, PRODUCER_SYSTEM, PRODUCER_EMAIL, DESCRIPTION, YAML_DEFINITION)
SELECT 'tpch_region_v1', 'data', '1.0.0', 'active', 'TPCH_DEMO', 'data-eng@company.com',
       'TPCH Region reference data contract',
       PARSE_JSON('{"contract":{"id":"tpch_region_v1","sla":{"freshness_minutes":1440}}}');

-- TPCH Partsupp Contract
INSERT INTO CONTRACTS (CONTRACT_ID, CONTRACT_TYPE, VERSION, STATUS, PRODUCER_SYSTEM, PRODUCER_EMAIL, DESCRIPTION, YAML_DEFINITION)
SELECT 'tpch_partsupp_v1', 'data', '1.0.0', 'active', 'TPCH_DEMO', 'data-eng@company.com',
       'TPCH Part-Supplier relationship contract',
       PARSE_JSON('{"contract":{"id":"tpch_partsupp_v1","sla":{"freshness_minutes":60}}}');

-- Sales Analytics Product Contract
INSERT INTO CONTRACTS (CONTRACT_ID, CONTRACT_TYPE, VERSION, STATUS, PRODUCER_SYSTEM, PRODUCER_EMAIL, DESCRIPTION, YAML_DEFINITION)
SELECT 'sem_sales_analytics_v1', 'product', '1.0.0', 'active', 'SEM_DEV', 'analytics@company.com',
       'Sales Analytics semantic view for BI and AI consumption',
       PARSE_JSON('{"product":{"id":"sem_sales_analytics_v1","ai_allowed":true}}');

-- Customer Analytics Product Contract
INSERT INTO CONTRACTS (CONTRACT_ID, CONTRACT_TYPE, VERSION, STATUS, PRODUCER_SYSTEM, PRODUCER_EMAIL, DESCRIPTION, YAML_DEFINITION)
SELECT 'sem_customer_analytics_v1', 'product', '1.0.0', 'active', 'SEM_DEV', 'analytics@company.com',
       'Customer Analytics semantic view with RFM segmentation',
       PARSE_JSON('{"product":{"id":"sem_customer_analytics_v1","ai_allowed":true}}');

-- ─────────────────────────────────────────────────────────────────────────────
-- REGISTER SAMPLE CONSUMERS
-- ─────────────────────────────────────────────────────────────────────────────

INSERT INTO CONTRACT_CONSUMERS (CONSUMER_ID, CONTRACT_ID, CONSUMER_SYSTEM, CONSUMER_TEAM, CONSUMER_EMAIL, USE_CASE, NOTIFY_BREAKING)
SELECT UUID_STRING(), 'tpch_customer_v1', 'BI_DASHBOARD', 'Business Intelligence', 'bi-team@company.com', 'Customer reporting dashboard', TRUE;

INSERT INTO CONTRACT_CONSUMERS (CONSUMER_ID, CONTRACT_ID, CONSUMER_SYSTEM, CONSUMER_TEAM, CONSUMER_EMAIL, USE_CASE, NOTIFY_BREAKING)
SELECT UUID_STRING(), 'tpch_customer_v1', 'ML_PIPELINE', 'Data Science', 'ds-team@company.com', 'Customer churn prediction model', TRUE;

INSERT INTO CONTRACT_CONSUMERS (CONSUMER_ID, CONTRACT_ID, CONSUMER_SYSTEM, CONSUMER_TEAM, CONSUMER_EMAIL, USE_CASE, NOTIFY_BREAKING)
SELECT UUID_STRING(), 'tpch_customer_v1', 'CRM_SYNC', 'Sales Operations', 'sales-ops@company.com', 'CRM data synchronization', TRUE;

INSERT INTO CONTRACT_CONSUMERS (CONSUMER_ID, CONTRACT_ID, CONSUMER_SYSTEM, CONSUMER_TEAM, CONSUMER_EMAIL, USE_CASE, NOTIFY_BREAKING)
SELECT UUID_STRING(), 'tpch_orders_v1', 'BI_DASHBOARD', 'Business Intelligence', 'bi-team@company.com', 'Sales reporting dashboard', TRUE;

INSERT INTO CONTRACT_CONSUMERS (CONSUMER_ID, CONTRACT_ID, CONSUMER_SYSTEM, CONSUMER_TEAM, CONSUMER_EMAIL, USE_CASE, NOTIFY_BREAKING)
SELECT UUID_STRING(), 'tpch_orders_v1', 'FINANCE_SYSTEM', 'Finance', 'finance@company.com', 'Revenue recognition', TRUE;

INSERT INTO CONTRACT_CONSUMERS (CONSUMER_ID, CONTRACT_ID, CONSUMER_SYSTEM, CONSUMER_TEAM, CONSUMER_EMAIL, USE_CASE, NOTIFY_BREAKING)
SELECT UUID_STRING(), 'tpch_lineitem_v1', 'BI_DASHBOARD', 'Business Intelligence', 'bi-team@company.com', 'Product performance analytics', TRUE;

INSERT INTO CONTRACT_CONSUMERS (CONSUMER_ID, CONTRACT_ID, CONSUMER_SYSTEM, CONSUMER_TEAM, CONSUMER_EMAIL, USE_CASE, NOTIFY_BREAKING)
SELECT UUID_STRING(), 'tpch_lineitem_v1', 'SUPPLY_CHAIN', 'Operations', 'ops@company.com', 'Inventory planning', TRUE;

INSERT INTO CONTRACT_CONSUMERS (CONSUMER_ID, CONTRACT_ID, CONSUMER_SYSTEM, CONSUMER_TEAM, CONSUMER_EMAIL, USE_CASE, NOTIFY_BREAKING)
SELECT UUID_STRING(), 'sem_sales_analytics_v1', 'CORTEX_ANALYST', 'AI Platform', 'ai-platform@company.com', 'Natural language sales queries', FALSE;

INSERT INTO CONTRACT_CONSUMERS (CONSUMER_ID, CONTRACT_ID, CONSUMER_SYSTEM, CONSUMER_TEAM, CONSUMER_EMAIL, USE_CASE, NOTIFY_BREAKING)
SELECT UUID_STRING(), 'sem_sales_analytics_v1', 'EXECUTIVE_DASH', 'Executive Team', 'exec@company.com', 'Executive KPI dashboard', TRUE;

INSERT INTO CONTRACT_CONSUMERS (CONSUMER_ID, CONTRACT_ID, CONSUMER_SYSTEM, CONSUMER_TEAM, CONSUMER_EMAIL, USE_CASE, NOTIFY_BREAKING)
SELECT UUID_STRING(), 'sem_customer_analytics_v1', 'CORTEX_ANALYST', 'AI Platform', 'ai-platform@company.com', 'Customer insights queries', FALSE;

INSERT INTO CONTRACT_CONSUMERS (CONSUMER_ID, CONTRACT_ID, CONSUMER_SYSTEM, CONSUMER_TEAM, CONSUMER_EMAIL, USE_CASE, NOTIFY_BREAKING)
SELECT UUID_STRING(), 'sem_customer_analytics_v1', 'MARKETING', 'Marketing', 'marketing@company.com', 'Campaign targeting', TRUE;

-- ─────────────────────────────────────────────────────────────────────────────
-- GENERATE SAMPLE SLA METRICS (Last 48 hours)
-- ─────────────────────────────────────────────────────────────────────────────

INSERT INTO SLA_METRICS (METRIC_ID, CONTRACT_ID, SLA_ID, MEASURED_VALUE, THRESHOLD_VALUE, IS_VIOLATION, VIOLATION_SEVERITY, MEASURED_AT)
SELECT 
    UUID_STRING(),
    contract_id,
    'freshness',
    10 + ABS(RANDOM() % 60),
    threshold,
    (10 + ABS(RANDOM() % 60)) > threshold,
    CASE WHEN (10 + ABS(RANDOM() % 60)) > threshold THEN 'error' ELSE 'ok' END,
    DATEADD('hour', -seq, CURRENT_TIMESTAMP())
FROM (
    SELECT 'tpch_customer_v1' AS contract_id, 60 AS threshold UNION ALL
    SELECT 'tpch_orders_v1', 30 UNION ALL
    SELECT 'tpch_lineitem_v1', 30 UNION ALL
    SELECT 'tpch_part_v1', 120 UNION ALL
    SELECT 'tpch_supplier_v1', 120 UNION ALL
    SELECT 'tpch_nation_v1', 1440 UNION ALL
    SELECT 'tpch_region_v1', 1440 UNION ALL
    SELECT 'tpch_partsupp_v1', 60
) contracts
CROSS JOIN (SELECT SEQ4() AS seq FROM TABLE(GENERATOR(ROWCOUNT => 48))) hours;

-- ─────────────────────────────────────────────────────────────────────────────
-- GENERATE SAMPLE QUALITY RULE RESULTS (Last 24 hours)
-- ─────────────────────────────────────────────────────────────────────────────

INSERT INTO QUALITY_RULE_RESULTS (RESULT_ID, RULE_ID, CONTRACT_ID, EXECUTION_TIME, PASSED, RESULT_VALUE, ROWS_CHECKED, ROWS_FAILED)
SELECT 
    UUID_STRING(),
    'qr_' || LPAD(rule_num::VARCHAR, 3, '0'),
    contract_id,
    DATEADD('hour', -seq, CURRENT_TIMESTAMP()),
    RANDOM() % 100 < 95,
    PARSE_JSON('{"rule_name": "' || rule_name || '", "severity": "' || severity || '"}'),
    1000 + ABS(RANDOM() % 10000),
    CASE WHEN RANDOM() % 100 < 95 THEN 0 ELSE ABS(RANDOM() % 50) END
FROM (
    SELECT 'tpch_customer_v1' AS contract_id, 1 AS rule_num, 'valid_custkey' AS rule_name, 'error' AS severity UNION ALL
    SELECT 'tpch_customer_v1', 2, 'no_null_names', 'warning' UNION ALL
    SELECT 'tpch_orders_v1', 1, 'valid_orderkey', 'error' UNION ALL
    SELECT 'tpch_orders_v1', 2, 'valid_order_date', 'error' UNION ALL
    SELECT 'tpch_orders_v1', 3, 'positive_amount', 'warning' UNION ALL
    SELECT 'tpch_lineitem_v1', 1, 'valid_lineitem', 'error' UNION ALL
    SELECT 'tpch_lineitem_v1', 2, 'valid_quantity', 'warning' UNION ALL
    SELECT 'tpch_part_v1', 1, 'valid_partkey', 'error' UNION ALL
    SELECT 'tpch_supplier_v1', 1, 'valid_suppkey', 'error' UNION ALL
    SELECT 'sem_sales_analytics_v1', 1, 'view_accessible', 'error' UNION ALL
    SELECT 'sem_customer_analytics_v1', 1, 'view_accessible', 'error'
) rules
CROSS JOIN (SELECT SEQ4() AS seq FROM TABLE(GENERATOR(ROWCOUNT => 24))) hours;

-- ─────────────────────────────────────────────────────────────────────────────
-- GENERATE SAMPLE ALERTS
-- ─────────────────────────────────────────────────────────────────────────────

INSERT INTO GOVERNANCE.OBSERVABILITY.ALERTS (ALERT_ID, CONTRACT_ID, ALERT_TYPE, SEVERITY, TITLE, MESSAGE, STATUS, CREATED_AT)
SELECT UUID_STRING(), 'tpch_orders_v1', 'SLA_VIOLATION', 'WARNING', 
       'Freshness Warning: tpch_orders_v1', 
       'Data freshness approaching threshold. Current age: 25 minutes, Threshold: 30 minutes',
       'OPEN', DATEADD('hour', -2, CURRENT_TIMESTAMP());

INSERT INTO GOVERNANCE.OBSERVABILITY.ALERTS (ALERT_ID, CONTRACT_ID, ALERT_TYPE, SEVERITY, TITLE, MESSAGE, STATUS, CREATED_AT)
SELECT UUID_STRING(), 'tpch_lineitem_v1', 'QUALITY_FAILURE', 'ERROR',
       'Quality Rule Failed: valid_quantity',
       'Quality rule "valid_quantity" failed for contract tpch_lineitem_v1. 12 rows with invalid quantities detected.',
       'ACKNOWLEDGED', DATEADD('hour', -6, CURRENT_TIMESTAMP());

INSERT INTO GOVERNANCE.OBSERVABILITY.ALERTS (ALERT_ID, CONTRACT_ID, ALERT_TYPE, SEVERITY, TITLE, MESSAGE, STATUS, CREATED_AT)
SELECT UUID_STRING(), 'tpch_customer_v1', 'SLA_VIOLATION', 'ERROR',
       'Freshness SLA Violation: tpch_customer_v1',
       'Data freshness exceeded threshold. Current age: 75 minutes, Threshold: 60 minutes',
       'OPEN', DATEADD('hour', -1, CURRENT_TIMESTAMP());

-- ─────────────────────────────────────────────────────────────────────────────
-- VERIFICATION
-- ─────────────────────────────────────────────────────────────────────────────

USE DATABASE GOVERNANCE;
USE SCHEMA CONTRACT_REGISTRY;

SELECT '✓ Demo Sample Data Loaded Successfully' AS STATUS;

-- Show contract counts
SELECT 'Contracts' AS ENTITY, COUNT(*) AS COUNT FROM CONTRACTS WHERE STATUS = 'active'
UNION ALL
SELECT 'Consumers', COUNT(*) FROM CONTRACT_CONSUMERS
UNION ALL
SELECT 'SLA Metrics', COUNT(*) FROM SLA_METRICS WHERE MEASURED_AT > DATEADD('day', -2, CURRENT_TIMESTAMP())
UNION ALL
SELECT 'Quality Results', COUNT(*) FROM QUALITY_RULE_RESULTS WHERE EXECUTION_TIME > DATEADD('day', -2, CURRENT_TIMESTAMP())
UNION ALL
SELECT 'Active Alerts', COUNT(*) FROM GOVERNANCE.OBSERVABILITY.ALERTS WHERE STATUS IN ('OPEN', 'ACKNOWLEDGED');

-- Show dashboard KPIs
SELECT * FROM GOVERNANCE.OBSERVABILITY.VW_DASHBOARD_KPIS;

-- Show contract health
SELECT CONTRACT_ID, OVERALL_HEALTH, QUALITY_SCORE, FRESHNESS_STATUS, CONSUMER_COUNT
FROM GOVERNANCE.OBSERVABILITY.VW_CONTRACT_HEALTH_DASHBOARD
ORDER BY CONSUMER_COUNT DESC;

-- ============================================================================
-- DIRECT LOAD TPCH DATA - Initial Load and Incremental Refresh
-- ============================================================================
-- This script loads TPCH data from Snowflake sample database with:
--   1. Initial full load with hash generation
--   2. Procedures for incremental/delta processing
--   3. Current record management (mark old records, insert new)
-- ============================================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE RAW_DEV;
USE SCHEMA RAW_TPCH;
USE WAREHOUSE TRANSFORM_WH;

-- ─────────────────────────────────────────────────────────────────────────────
-- HELPER FUNCTION: Generate Row Hash
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION RAW_DEV.RAW_TPCH.GENERATE_HASH(input_array ARRAY)
RETURNS VARCHAR(64)
LANGUAGE SQL
AS
$$
    SHA2(ARRAY_TO_STRING(input_array, '|'), 256)
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- LOAD REGION (Reference Data - Full Refresh)
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE PROCEDURE RAW_DEV.RAW_TPCH.LOAD_REGION()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
BEGIN
    -- Full refresh for reference data
    TRUNCATE TABLE RAW_DEV.RAW_TPCH.REGION_RAW;
    
    INSERT INTO RAW_DEV.RAW_TPCH.REGION_RAW (
        R_REGIONKEY,
        R_NAME,
        R_COMMENT,
        _LOADED_AT,
        _SOURCE_FILE,
        _IS_CURRENT
    )
    SELECT
        R_REGIONKEY,
        R_NAME,
        R_COMMENT,
        CURRENT_TIMESTAMP(),
        'SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.REGION',
        TRUE
    FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.REGION;
    
    RETURN 'Loaded ' || (SELECT COUNT(*) FROM RAW_DEV.RAW_TPCH.REGION_RAW) || ' regions';
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- LOAD NATION (Reference Data - Full Refresh)
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE PROCEDURE RAW_DEV.RAW_TPCH.LOAD_NATION()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
BEGIN
    TRUNCATE TABLE RAW_DEV.RAW_TPCH.NATION_RAW;
    
    INSERT INTO RAW_DEV.RAW_TPCH.NATION_RAW (
        N_NATIONKEY,
        N_NAME,
        N_REGIONKEY,
        N_COMMENT,
        _LOADED_AT,
        _SOURCE_FILE,
        _IS_CURRENT
    )
    SELECT
        N_NATIONKEY,
        N_NAME,
        N_REGIONKEY,
        N_COMMENT,
        CURRENT_TIMESTAMP(),
        'SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.NATION',
        TRUE
    FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.NATION;
    
    RETURN 'Loaded ' || (SELECT COUNT(*) FROM RAW_DEV.RAW_TPCH.NATION_RAW) || ' nations';
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- LOAD CUSTOMER (With Change Detection)
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE PROCEDURE RAW_DEV.RAW_TPCH.LOAD_CUSTOMER(
    P_FULL_REFRESH BOOLEAN DEFAULT FALSE
)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    v_loaded_count INT;
    v_updated_count INT;
BEGIN
    IF (P_FULL_REFRESH) THEN
        -- Full refresh mode
        TRUNCATE TABLE RAW_DEV.RAW_TPCH.CUSTOMER_RAW;
        
        INSERT INTO RAW_DEV.RAW_TPCH.CUSTOMER_RAW (
            C_CUSTKEY, C_NAME, C_ADDRESS, C_NATIONKEY, C_PHONE, 
            C_ACCTBAL, C_MKTSEGMENT, C_COMMENT,
            _LOADED_AT, _SOURCE_FILE, _ROW_HASH, _IS_CURRENT
        )
        SELECT
            C_CUSTKEY, C_NAME, C_ADDRESS, C_NATIONKEY, C_PHONE,
            C_ACCTBAL, C_MKTSEGMENT, C_COMMENT,
            CURRENT_TIMESTAMP(),
            'SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.CUSTOMER',
            SHA2(C_CUSTKEY || '|' || C_NAME || '|' || C_ADDRESS || '|' || 
                 C_NATIONKEY || '|' || C_PHONE || '|' || C_ACCTBAL || '|' || 
                 C_MKTSEGMENT, 256),
            TRUE
        FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.CUSTOMER;
        
        RETURN 'Full refresh: Loaded ' || (SELECT COUNT(*) FROM RAW_DEV.RAW_TPCH.CUSTOMER_RAW) || ' customers';
    ELSE
        -- Incremental mode with change detection
        -- Step 1: Mark existing records as not current if they changed
        UPDATE RAW_DEV.RAW_TPCH.CUSTOMER_RAW tgt
        SET _IS_CURRENT = FALSE
        WHERE tgt._IS_CURRENT = TRUE
        AND EXISTS (
            SELECT 1 FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.CUSTOMER src
            WHERE src.C_CUSTKEY = tgt.C_CUSTKEY
            AND SHA2(src.C_CUSTKEY || '|' || src.C_NAME || '|' || src.C_ADDRESS || '|' || 
                     src.C_NATIONKEY || '|' || src.C_PHONE || '|' || src.C_ACCTBAL || '|' || 
                     src.C_MKTSEGMENT, 256) != tgt._ROW_HASH
        );
        
        v_updated_count := SQLROWCOUNT;
        
        -- Step 2: Insert new and changed records
        INSERT INTO RAW_DEV.RAW_TPCH.CUSTOMER_RAW (
            C_CUSTKEY, C_NAME, C_ADDRESS, C_NATIONKEY, C_PHONE, 
            C_ACCTBAL, C_MKTSEGMENT, C_COMMENT,
            _LOADED_AT, _SOURCE_FILE, _ROW_HASH, _IS_CURRENT
        )
        SELECT
            src.C_CUSTKEY, src.C_NAME, src.C_ADDRESS, src.C_NATIONKEY, src.C_PHONE,
            src.C_ACCTBAL, src.C_MKTSEGMENT, src.C_COMMENT,
            CURRENT_TIMESTAMP(),
            'SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.CUSTOMER',
            SHA2(src.C_CUSTKEY || '|' || src.C_NAME || '|' || src.C_ADDRESS || '|' || 
                 src.C_NATIONKEY || '|' || src.C_PHONE || '|' || src.C_ACCTBAL || '|' || 
                 src.C_MKTSEGMENT, 256),
            TRUE
        FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.CUSTOMER src
        WHERE NOT EXISTS (
            SELECT 1 FROM RAW_DEV.RAW_TPCH.CUSTOMER_RAW tgt
            WHERE tgt.C_CUSTKEY = src.C_CUSTKEY
            AND tgt._IS_CURRENT = TRUE
            AND tgt._ROW_HASH = SHA2(src.C_CUSTKEY || '|' || src.C_NAME || '|' || src.C_ADDRESS || '|' || 
                                      src.C_NATIONKEY || '|' || src.C_PHONE || '|' || src.C_ACCTBAL || '|' || 
                                      src.C_MKTSEGMENT, 256)
        );
        
        v_loaded_count := SQLROWCOUNT;
        
        RETURN 'Incremental: Updated ' || v_updated_count || ', Inserted ' || v_loaded_count || ' customers';
    END IF;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- LOAD SUPPLIER (With Change Detection)
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE PROCEDURE RAW_DEV.RAW_TPCH.LOAD_SUPPLIER(
    P_FULL_REFRESH BOOLEAN DEFAULT FALSE
)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    v_loaded_count INT;
BEGIN
    IF (P_FULL_REFRESH) THEN
        TRUNCATE TABLE RAW_DEV.RAW_TPCH.SUPPLIER_RAW;
        
        INSERT INTO RAW_DEV.RAW_TPCH.SUPPLIER_RAW (
            S_SUPPKEY, S_NAME, S_ADDRESS, S_NATIONKEY, S_PHONE, S_ACCTBAL, S_COMMENT,
            _LOADED_AT, _SOURCE_FILE, _ROW_HASH, _IS_CURRENT
        )
        SELECT
            S_SUPPKEY, S_NAME, S_ADDRESS, S_NATIONKEY, S_PHONE, S_ACCTBAL, S_COMMENT,
            CURRENT_TIMESTAMP(),
            'SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.SUPPLIER',
            SHA2(S_SUPPKEY || '|' || S_NAME || '|' || S_ADDRESS || '|' || 
                 S_NATIONKEY || '|' || S_PHONE || '|' || S_ACCTBAL, 256),
            TRUE
        FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.SUPPLIER;
        
        RETURN 'Full refresh: Loaded ' || (SELECT COUNT(*) FROM RAW_DEV.RAW_TPCH.SUPPLIER_RAW) || ' suppliers';
    ELSE
        -- Simplified incremental for demo
        MERGE INTO RAW_DEV.RAW_TPCH.SUPPLIER_RAW tgt
        USING (
            SELECT
                S_SUPPKEY, S_NAME, S_ADDRESS, S_NATIONKEY, S_PHONE, S_ACCTBAL, S_COMMENT,
                SHA2(S_SUPPKEY || '|' || S_NAME || '|' || S_ADDRESS || '|' || 
                     S_NATIONKEY || '|' || S_PHONE || '|' || S_ACCTBAL, 256) AS _ROW_HASH
            FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.SUPPLIER
        ) src
        ON tgt.S_SUPPKEY = src.S_SUPPKEY AND tgt._IS_CURRENT = TRUE
        WHEN MATCHED AND tgt._ROW_HASH != src._ROW_HASH THEN
            UPDATE SET 
                S_NAME = src.S_NAME,
                S_ADDRESS = src.S_ADDRESS,
                S_NATIONKEY = src.S_NATIONKEY,
                S_PHONE = src.S_PHONE,
                S_ACCTBAL = src.S_ACCTBAL,
                S_COMMENT = src.S_COMMENT,
                _LOADED_AT = CURRENT_TIMESTAMP(),
                _ROW_HASH = src._ROW_HASH
        WHEN NOT MATCHED THEN
            INSERT (S_SUPPKEY, S_NAME, S_ADDRESS, S_NATIONKEY, S_PHONE, S_ACCTBAL, S_COMMENT,
                    _LOADED_AT, _SOURCE_FILE, _ROW_HASH, _IS_CURRENT)
            VALUES (src.S_SUPPKEY, src.S_NAME, src.S_ADDRESS, src.S_NATIONKEY, src.S_PHONE, 
                    src.S_ACCTBAL, src.S_COMMENT, CURRENT_TIMESTAMP(), 
                    'SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.SUPPLIER', src._ROW_HASH, TRUE);
        
        RETURN 'Incremental merge completed for suppliers';
    END IF;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- LOAD PART (With Change Detection)
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE PROCEDURE RAW_DEV.RAW_TPCH.LOAD_PART(
    P_FULL_REFRESH BOOLEAN DEFAULT FALSE
)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
BEGIN
    IF (P_FULL_REFRESH) THEN
        TRUNCATE TABLE RAW_DEV.RAW_TPCH.PART_RAW;
        
        INSERT INTO RAW_DEV.RAW_TPCH.PART_RAW (
            P_PARTKEY, P_NAME, P_MFGR, P_BRAND, P_TYPE, P_SIZE, P_CONTAINER, P_RETAILPRICE, P_COMMENT,
            _LOADED_AT, _SOURCE_FILE, _ROW_HASH, _IS_CURRENT
        )
        SELECT
            P_PARTKEY, P_NAME, P_MFGR, P_BRAND, P_TYPE, P_SIZE, P_CONTAINER, P_RETAILPRICE, P_COMMENT,
            CURRENT_TIMESTAMP(),
            'SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.PART',
            SHA2(P_PARTKEY || '|' || P_NAME || '|' || P_MFGR || '|' || P_BRAND || '|' || 
                 P_TYPE || '|' || P_SIZE || '|' || P_CONTAINER || '|' || P_RETAILPRICE, 256),
            TRUE
        FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.PART;
        
        RETURN 'Full refresh: Loaded ' || (SELECT COUNT(*) FROM RAW_DEV.RAW_TPCH.PART_RAW) || ' parts';
    ELSE
        MERGE INTO RAW_DEV.RAW_TPCH.PART_RAW tgt
        USING (
            SELECT *,
                SHA2(P_PARTKEY || '|' || P_NAME || '|' || P_MFGR || '|' || P_BRAND || '|' || 
                     P_TYPE || '|' || P_SIZE || '|' || P_CONTAINER || '|' || P_RETAILPRICE, 256) AS _ROW_HASH
            FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.PART
        ) src
        ON tgt.P_PARTKEY = src.P_PARTKEY AND tgt._IS_CURRENT = TRUE
        WHEN MATCHED AND tgt._ROW_HASH != src._ROW_HASH THEN
            UPDATE SET 
                P_NAME = src.P_NAME, P_MFGR = src.P_MFGR, P_BRAND = src.P_BRAND,
                P_TYPE = src.P_TYPE, P_SIZE = src.P_SIZE, P_CONTAINER = src.P_CONTAINER,
                P_RETAILPRICE = src.P_RETAILPRICE, P_COMMENT = src.P_COMMENT,
                _LOADED_AT = CURRENT_TIMESTAMP(), _ROW_HASH = src._ROW_HASH
        WHEN NOT MATCHED THEN
            INSERT (P_PARTKEY, P_NAME, P_MFGR, P_BRAND, P_TYPE, P_SIZE, P_CONTAINER, P_RETAILPRICE, P_COMMENT,
                    _LOADED_AT, _SOURCE_FILE, _ROW_HASH, _IS_CURRENT)
            VALUES (src.P_PARTKEY, src.P_NAME, src.P_MFGR, src.P_BRAND, src.P_TYPE, src.P_SIZE, 
                    src.P_CONTAINER, src.P_RETAILPRICE, src.P_COMMENT, CURRENT_TIMESTAMP(),
                    'SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.PART', src._ROW_HASH, TRUE);
        
        RETURN 'Incremental merge completed for parts';
    END IF;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- LOAD PARTSUPP
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE PROCEDURE RAW_DEV.RAW_TPCH.LOAD_PARTSUPP(
    P_FULL_REFRESH BOOLEAN DEFAULT FALSE
)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
BEGIN
    IF (P_FULL_REFRESH) THEN
        TRUNCATE TABLE RAW_DEV.RAW_TPCH.PARTSUPP_RAW;
        
        INSERT INTO RAW_DEV.RAW_TPCH.PARTSUPP_RAW (
            PS_PARTKEY, PS_SUPPKEY, PS_AVAILQTY, PS_SUPPLYCOST, PS_COMMENT,
            _LOADED_AT, _SOURCE_FILE, _ROW_HASH, _IS_CURRENT
        )
        SELECT
            PS_PARTKEY, PS_SUPPKEY, PS_AVAILQTY, PS_SUPPLYCOST, PS_COMMENT,
            CURRENT_TIMESTAMP(),
            'SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.PARTSUPP',
            SHA2(PS_PARTKEY || '|' || PS_SUPPKEY || '|' || PS_AVAILQTY || '|' || PS_SUPPLYCOST, 256),
            TRUE
        FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.PARTSUPP;
        
        RETURN 'Full refresh: Loaded ' || (SELECT COUNT(*) FROM RAW_DEV.RAW_TPCH.PARTSUPP_RAW) || ' part-supplier records';
    ELSE
        RETURN 'Incremental load not implemented for PARTSUPP - use full refresh';
    END IF;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- LOAD ORDERS (With Change Detection)
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE PROCEDURE RAW_DEV.RAW_TPCH.LOAD_ORDERS(
    P_FULL_REFRESH BOOLEAN DEFAULT FALSE
)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
BEGIN
    IF (P_FULL_REFRESH) THEN
        TRUNCATE TABLE RAW_DEV.RAW_TPCH.ORDERS_RAW;
        
        INSERT INTO RAW_DEV.RAW_TPCH.ORDERS_RAW (
            O_ORDERKEY, O_CUSTKEY, O_ORDERSTATUS, O_TOTALPRICE, O_ORDERDATE,
            O_ORDERPRIORITY, O_CLERK, O_SHIPPRIORITY, O_COMMENT,
            _LOADED_AT, _SOURCE_FILE, _ROW_HASH, _IS_CURRENT
        )
        SELECT
            O_ORDERKEY, O_CUSTKEY, O_ORDERSTATUS, O_TOTALPRICE, O_ORDERDATE,
            O_ORDERPRIORITY, O_CLERK, O_SHIPPRIORITY, O_COMMENT,
            CURRENT_TIMESTAMP(),
            'SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.ORDERS',
            SHA2(O_ORDERKEY || '|' || O_CUSTKEY || '|' || O_ORDERSTATUS || '|' || 
                 O_TOTALPRICE || '|' || O_ORDERDATE || '|' || O_ORDERPRIORITY, 256),
            TRUE
        FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.ORDERS;
        
        RETURN 'Full refresh: Loaded ' || (SELECT COUNT(*) FROM RAW_DEV.RAW_TPCH.ORDERS_RAW) || ' orders';
    ELSE
        MERGE INTO RAW_DEV.RAW_TPCH.ORDERS_RAW tgt
        USING (
            SELECT *,
                SHA2(O_ORDERKEY || '|' || O_CUSTKEY || '|' || O_ORDERSTATUS || '|' || 
                     O_TOTALPRICE || '|' || O_ORDERDATE || '|' || O_ORDERPRIORITY, 256) AS _ROW_HASH
            FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.ORDERS
        ) src
        ON tgt.O_ORDERKEY = src.O_ORDERKEY AND tgt._IS_CURRENT = TRUE
        WHEN MATCHED AND tgt._ROW_HASH != src._ROW_HASH THEN
            UPDATE SET 
                O_CUSTKEY = src.O_CUSTKEY, O_ORDERSTATUS = src.O_ORDERSTATUS,
                O_TOTALPRICE = src.O_TOTALPRICE, O_ORDERDATE = src.O_ORDERDATE,
                O_ORDERPRIORITY = src.O_ORDERPRIORITY, O_CLERK = src.O_CLERK,
                O_SHIPPRIORITY = src.O_SHIPPRIORITY, O_COMMENT = src.O_COMMENT,
                _LOADED_AT = CURRENT_TIMESTAMP(), _ROW_HASH = src._ROW_HASH
        WHEN NOT MATCHED THEN
            INSERT (O_ORDERKEY, O_CUSTKEY, O_ORDERSTATUS, O_TOTALPRICE, O_ORDERDATE,
                    O_ORDERPRIORITY, O_CLERK, O_SHIPPRIORITY, O_COMMENT,
                    _LOADED_AT, _SOURCE_FILE, _ROW_HASH, _IS_CURRENT)
            VALUES (src.O_ORDERKEY, src.O_CUSTKEY, src.O_ORDERSTATUS, src.O_TOTALPRICE, 
                    src.O_ORDERDATE, src.O_ORDERPRIORITY, src.O_CLERK, src.O_SHIPPRIORITY, 
                    src.O_COMMENT, CURRENT_TIMESTAMP(), 
                    'SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.ORDERS', src._ROW_HASH, TRUE);
        
        RETURN 'Incremental merge completed for orders';
    END IF;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- LOAD LINEITEM (With Change Detection)
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE PROCEDURE RAW_DEV.RAW_TPCH.LOAD_LINEITEM(
    P_FULL_REFRESH BOOLEAN DEFAULT FALSE
)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
BEGIN
    IF (P_FULL_REFRESH) THEN
        TRUNCATE TABLE RAW_DEV.RAW_TPCH.LINEITEM_RAW;
        
        INSERT INTO RAW_DEV.RAW_TPCH.LINEITEM_RAW (
            L_ORDERKEY, L_PARTKEY, L_SUPPKEY, L_LINENUMBER, L_QUANTITY,
            L_EXTENDEDPRICE, L_DISCOUNT, L_TAX, L_RETURNFLAG, L_LINESTATUS,
            L_SHIPDATE, L_COMMITDATE, L_RECEIPTDATE, L_SHIPINSTRUCT, L_SHIPMODE, L_COMMENT,
            _LOADED_AT, _SOURCE_FILE, _ROW_HASH, _IS_CURRENT
        )
        SELECT
            L_ORDERKEY, L_PARTKEY, L_SUPPKEY, L_LINENUMBER, L_QUANTITY,
            L_EXTENDEDPRICE, L_DISCOUNT, L_TAX, L_RETURNFLAG, L_LINESTATUS,
            L_SHIPDATE, L_COMMITDATE, L_RECEIPTDATE, L_SHIPINSTRUCT, L_SHIPMODE, L_COMMENT,
            CURRENT_TIMESTAMP(),
            'SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.LINEITEM',
            SHA2(L_ORDERKEY || '|' || L_LINENUMBER || '|' || L_QUANTITY || '|' || 
                 L_EXTENDEDPRICE || '|' || L_DISCOUNT || '|' || L_TAX || '|' ||
                 L_RETURNFLAG || '|' || L_LINESTATUS, 256),
            TRUE
        FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.LINEITEM;
        
        RETURN 'Full refresh: Loaded ' || (SELECT COUNT(*) FROM RAW_DEV.RAW_TPCH.LINEITEM_RAW) || ' line items';
    ELSE
        MERGE INTO RAW_DEV.RAW_TPCH.LINEITEM_RAW tgt
        USING (
            SELECT *,
                SHA2(L_ORDERKEY || '|' || L_LINENUMBER || '|' || L_QUANTITY || '|' || 
                     L_EXTENDEDPRICE || '|' || L_DISCOUNT || '|' || L_TAX || '|' ||
                     L_RETURNFLAG || '|' || L_LINESTATUS, 256) AS _ROW_HASH
            FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.LINEITEM
        ) src
        ON tgt.L_ORDERKEY = src.L_ORDERKEY AND tgt.L_LINENUMBER = src.L_LINENUMBER AND tgt._IS_CURRENT = TRUE
        WHEN MATCHED AND tgt._ROW_HASH != src._ROW_HASH THEN
            UPDATE SET 
                L_PARTKEY = src.L_PARTKEY, L_SUPPKEY = src.L_SUPPKEY, L_QUANTITY = src.L_QUANTITY,
                L_EXTENDEDPRICE = src.L_EXTENDEDPRICE, L_DISCOUNT = src.L_DISCOUNT, L_TAX = src.L_TAX,
                L_RETURNFLAG = src.L_RETURNFLAG, L_LINESTATUS = src.L_LINESTATUS,
                L_SHIPDATE = src.L_SHIPDATE, L_COMMITDATE = src.L_COMMITDATE, L_RECEIPTDATE = src.L_RECEIPTDATE,
                L_SHIPINSTRUCT = src.L_SHIPINSTRUCT, L_SHIPMODE = src.L_SHIPMODE, L_COMMENT = src.L_COMMENT,
                _LOADED_AT = CURRENT_TIMESTAMP(), _ROW_HASH = src._ROW_HASH
        WHEN NOT MATCHED THEN
            INSERT (L_ORDERKEY, L_PARTKEY, L_SUPPKEY, L_LINENUMBER, L_QUANTITY,
                    L_EXTENDEDPRICE, L_DISCOUNT, L_TAX, L_RETURNFLAG, L_LINESTATUS,
                    L_SHIPDATE, L_COMMITDATE, L_RECEIPTDATE, L_SHIPINSTRUCT, L_SHIPMODE, L_COMMENT,
                    _LOADED_AT, _SOURCE_FILE, _ROW_HASH, _IS_CURRENT)
            VALUES (src.L_ORDERKEY, src.L_PARTKEY, src.L_SUPPKEY, src.L_LINENUMBER, src.L_QUANTITY,
                    src.L_EXTENDEDPRICE, src.L_DISCOUNT, src.L_TAX, src.L_RETURNFLAG, src.L_LINESTATUS,
                    src.L_SHIPDATE, src.L_COMMITDATE, src.L_RECEIPTDATE, src.L_SHIPINSTRUCT, src.L_SHIPMODE,
                    src.L_COMMENT, CURRENT_TIMESTAMP(), 'SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.LINEITEM', 
                    src._ROW_HASH, TRUE);
        
        RETURN 'Incremental merge completed for line items';
    END IF;
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- MASTER LOAD PROCEDURE - Load All Tables
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE PROCEDURE RAW_DEV.RAW_TPCH.LOAD_ALL_TPCH(
    P_FULL_REFRESH BOOLEAN DEFAULT TRUE
)
RETURNS TABLE (table_name VARCHAR, result VARCHAR, load_time TIMESTAMP_NTZ)
LANGUAGE SQL
AS
$$
DECLARE
    res RESULTSET;
BEGIN
    -- Create temp table for results
    CREATE OR REPLACE TEMPORARY TABLE _LOAD_RESULTS (
        table_name VARCHAR,
        result VARCHAR,
        load_time TIMESTAMP_NTZ
    );
    
    -- Load reference data first
    INSERT INTO _LOAD_RESULTS VALUES ('REGION', (CALL RAW_DEV.RAW_TPCH.LOAD_REGION()), CURRENT_TIMESTAMP());
    INSERT INTO _LOAD_RESULTS VALUES ('NATION', (CALL RAW_DEV.RAW_TPCH.LOAD_NATION()), CURRENT_TIMESTAMP());
    
    -- Load dimension tables
    INSERT INTO _LOAD_RESULTS VALUES ('CUSTOMER', (CALL RAW_DEV.RAW_TPCH.LOAD_CUSTOMER(:P_FULL_REFRESH)), CURRENT_TIMESTAMP());
    INSERT INTO _LOAD_RESULTS VALUES ('SUPPLIER', (CALL RAW_DEV.RAW_TPCH.LOAD_SUPPLIER(:P_FULL_REFRESH)), CURRENT_TIMESTAMP());
    INSERT INTO _LOAD_RESULTS VALUES ('PART', (CALL RAW_DEV.RAW_TPCH.LOAD_PART(:P_FULL_REFRESH)), CURRENT_TIMESTAMP());
    INSERT INTO _LOAD_RESULTS VALUES ('PARTSUPP', (CALL RAW_DEV.RAW_TPCH.LOAD_PARTSUPP(:P_FULL_REFRESH)), CURRENT_TIMESTAMP());
    
    -- Load fact tables
    INSERT INTO _LOAD_RESULTS VALUES ('ORDERS', (CALL RAW_DEV.RAW_TPCH.LOAD_ORDERS(:P_FULL_REFRESH)), CURRENT_TIMESTAMP());
    INSERT INTO _LOAD_RESULTS VALUES ('LINEITEM', (CALL RAW_DEV.RAW_TPCH.LOAD_LINEITEM(:P_FULL_REFRESH)), CURRENT_TIMESTAMP());
    
    res := (SELECT * FROM _LOAD_RESULTS ORDER BY load_time);
    RETURN TABLE(res);
END;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- EXECUTE INITIAL LOAD
-- ─────────────────────────────────────────────────────────────────────────────

-- Run initial full load
CALL RAW_DEV.RAW_TPCH.LOAD_ALL_TPCH(TRUE);

-- Verify counts
SELECT 
    'REGION' AS TABLE_NAME, COUNT(*) AS ROW_COUNT FROM RAW_DEV.RAW_TPCH.REGION_RAW
UNION ALL
SELECT 'NATION', COUNT(*) FROM RAW_DEV.RAW_TPCH.NATION_RAW
UNION ALL
SELECT 'CUSTOMER', COUNT(*) FROM RAW_DEV.RAW_TPCH.CUSTOMER_RAW
UNION ALL
SELECT 'SUPPLIER', COUNT(*) FROM RAW_DEV.RAW_TPCH.SUPPLIER_RAW
UNION ALL
SELECT 'PART', COUNT(*) FROM RAW_DEV.RAW_TPCH.PART_RAW
UNION ALL
SELECT 'PARTSUPP', COUNT(*) FROM RAW_DEV.RAW_TPCH.PARTSUPP_RAW
UNION ALL
SELECT 'ORDERS', COUNT(*) FROM RAW_DEV.RAW_TPCH.ORDERS_RAW
UNION ALL
SELECT 'LINEITEM', COUNT(*) FROM RAW_DEV.RAW_TPCH.LINEITEM_RAW;

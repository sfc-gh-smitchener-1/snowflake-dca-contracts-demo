# Snowflake Data Contracts Demo

> A comprehensive demonstration of enforcing data contracts in a production Snowflake environment using TPCH sample data.

## Architectural Foundation

This demo implements the principles from the **[Enterprise Architecture Guide for the Snowflake Data Cloud v.5](docs/ARCHITECTURE_ALIGNMENT.md)**, specifically:

> *"AI, governance, and automation cannot scale unless business intent is explicit, portable, and enforceable by the data platform itself."*

The core dependency chain: **People → Data → Governance → Automation** is enforced through:

| Layer | Implementation |
|-------|---------------|
| **People** | Producer ownership, consumer registration |
| **Data** | Explicit schema contracts with semantic meaning |
| **Governance** | Runtime-enforced tags and policies |
| **Automation** | Dynamic tables, scheduled validation, alerting |

## Overview

This demo showcases a **contract-first data architecture** in Snowflake, implementing:

- **Data Contracts as Code**: YAML-based contracts defining schema, quality rules, SLAs, and governance
- **Three-Layer Architecture**: RAW → CURATED → SEMANTIC data flow
- **Automated Governance**: Tag-based classification, PII detection, and AI eligibility
- **Dynamic Tables**: Automated transformation pipelines
- **Semantic Views**: First-class Snowflake semantic views with YAML models for Cortex Analyst and Snowflake Intelligence
- **Observability Dashboard**: Real-time contract adherence monitoring

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           DATA CONTRACTS ARCHITECTURE                       │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐   │
│  │   SOURCE    │    │     RAW     │    │   CURATED   │    │  SEMANTIC   │   │
│  │   SYSTEMS   │───▶│    LAYER    │───▶│    LAYER    │───▶│    LAYER    │   │
│  │             │    │             │    │             │    │             │   │
│  │ TPCH Sample │    │ Direct Load │    │  Dynamic    │    │ Semantic    │   │
│  │ (or any     │    │ + CDC       │    │  Tables     │    │ Views +     │   │
│  │  source)    │    │ + Current   │    │ + Business  │    │ Cortex AI   │   │
│  │             │    │   Records   │    │   Rules     │    │             │   │
│  └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘   │
│         │                  │                  │                  │          │
│         ▼                  ▼                  ▼                  ▼          │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                        CONTRACT REGISTRY                              │  │
│  │  • Schema Definitions    • Quality Rules    • SLA Monitoring          │  │
│  │  • Governance Tags       • Consumer Registry • Breaking Changes       │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                    │                                        │
│                                    ▼                                        │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                     OBSERVABILITY DASHBOARD                           │  │
│  │  • Contract Health    • SLA Compliance    • Quality Scores            │  │
│  │  • Active Alerts      • Lineage Graph     • Tag Coverage              │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Quick Start

### Prerequisites

- Snowflake account with ACCOUNTADMIN role
- Access to `SNOWFLAKE_SAMPLE_DATA.TPCH_SF1` (available in all accounts)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/your-org/snowflake-dca-contracts-demo.git
   cd snowflake-dca-contracts-demo
   ```

2. **Run the setup scripts in order**
   ```sql
   -- Connect to Snowflake and run scripts in numbered order
   USE ROLE ACCOUNTADMIN;
   
   -- Step 1: Contract Registry Setup
   -- Run: sql/01_contract_registry_setup.sql
   
   -- Step 2: Demo Environment
   -- Run: sql/02_tpch_demo_setup.sql
   
   -- Step 3: RAW Layer Tables
   -- Run: sql/03_raw_layer_tables.sql
   
   -- Step 4: Load TPCH Data
   -- Run: sql/04_direct_load_tpch.sql
   
   -- Step 5: Curated Layer (Dynamic Tables)
   -- Run: sql/05_curated_layer_dynamic_tables.sql
   
   -- Step 6: Semantic Layer
   -- Run: sql/06_semantic_layer.sql
   ```

4. **Upload Semantic Models to Stage** (required for Cortex Analyst)
   ```bash
   # Using SnowSQL CLI (run from project root directory)
   cd snowflake-dca-contracts-demo
   snowsql -a <account> -u <user> -f tools/upload_semantic_models.sql
   
   # Or using Python
   pip install snowflake-connector-python
   export SNOWFLAKE_ACCOUNT=<account>
   export SNOWFLAKE_USER=<user>
   export SNOWFLAKE_PASSWORD=<password>
   python tools/upload_semantic_models.py
   ```
   
   Alternatively, upload via Snowsight UI:
   - Navigate to Data → Databases → SEM_DEV → SEM_SALES → Stages → SEMANTIC_MODELS
   - Click "Upload Files" and select all files from `semantic_models/` folder

5. **Continue with remaining scripts**
   ```sql
   -- Step 7: Contract Validation
   -- Run: sql/07_contract_validation.sql
   
   -- Step 8: Observability Dashboard
   -- Run: sql/08_observability_dashboard.sql
   
   -- Step 9: Contract Generator (Optional)
   -- Run: sql/09_contract_generator_proc.sql
   
   -- Step 10: Roles and Users (Demo Access Control)
   -- Run: sql/10_roles_and_users.sql
   ```

6. **Verify the installation**
   ```sql
   -- Check dashboard KPIs
   SELECT * FROM GOVERNANCE.OBSERVABILITY.VW_DASHBOARD_KPIS;
   
   -- View contract health
   SELECT * FROM GOVERNANCE.OBSERVABILITY.VW_CONTRACT_HEALTH_DASHBOARD;
   
   -- Query sales analytics
   SELECT REGION_NAME, SUM(NET_REVENUE) as revenue
   FROM SEM_DEV.SEM_SALES.VW_SALES_ANALYTICS
   GROUP BY REGION_NAME
   ORDER BY revenue DESC;
   ```

## Directory Structure

```
snowflake-dca-contracts-demo/
│
├── contracts/                      # Data Contract Definitions
│   ├── data/                       # Data contracts (producer → platform)
│   │   ├── tpch_customer_v1.yml
│   │   ├── tpch_orders_v1.yml
│   │   ├── tpch_lineitem_v1.yml
│   │   ├── tpch_nation_v1.yml
│   │   ├── tpch_region_v1.yml
│   │   ├── tpch_part_v1.yml
│   │   ├── tpch_supplier_v1.yml
│   │   └── crm_customer_v1.yml     # Example CRM contract
│   └── products/                   # Product contracts (platform → consumer)
│       ├── sem_customer_analytics_v1.yml
│       └── sem_sales_analytics_v1.yml
│
├── sql/                            # Snowflake SQL Scripts
│   ├── 00_run_full_demo.sql        # Quick setup script
│   ├── 01_contract_registry_setup.sql
│   ├── 02_tpch_demo_setup.sql
│   ├── 03_raw_layer_tables.sql
│   ├── 04_direct_load_tpch.sql
│   ├── 05_curated_layer_dynamic_tables.sql
│   ├── 06_semantic_layer.sql
│   ├── 07_contract_validation.sql
│   ├── 08_observability_dashboard.sql
│   ├── 09_contract_generator_proc.sql
│   └── 10_roles_and_users.sql          # Access control setup
│
├── semantic_models/                # Cortex Analyst Semantic Models (YAML)
│   ├── sales_analytics_model.yaml      # Revenue, orders, delivery
│   ├── customer_analytics_model.yaml   # RFM, segmentation, churn
│   ├── product_analytics_model.yaml    # Inventory, margins, performance
│   ├── supplier_analytics_model.yaml   # Vendor quality, delivery
│   └── governance_analytics_model.yaml # Contract health, SLAs, trust
│
├── schemas/                        # JSON Schemas for Validation
│   └── data_contract_schema.json
│
├── templates/                      # Contract Templates
│   ├── data_contract_template.yml
│   └── product_contract_template.yml
│
├── tools/                          # Python Utilities
│   ├── generate_contract.py        # Contract generator
│   └── validate_contracts.py       # Contract validation
│
├── docs/                           # Documentation
│   ├── DATA_CONTRACTS_WIREFRAME.md # Detailed design document
│   ├── ARCHITECTURE_ALIGNMENT.md   # EA Guide v.5 alignment
│   └── SAMPLE_QUESTIONS.md         # 125+ Snowflake Intelligence questions
│
└── README.md
```

## Data Contract Structure

Each data contract defines:

```yaml
contract:
  id: tpch_customer_v1
  version: 1.0.0
  status: active
  
  producer:
    system: SNOWFLAKE_SAMPLE_TPCH
    team: Demo Data Engineering
    owner: demo-team@company.com
  
  schema:
    database: RAW_${ENV}
    schema: RAW_TPCH
    table: CUSTOMER_RAW
    columns:
      - name: C_CUSTKEY
        type: NUMBER(38,0)
        tags:
          DATA_CLASSIFICATION: INTERNAL
          PII_TYPE: NONE
          AI_ALLOWED: "TRUE"
      # ... more columns
  
  sla:
    freshness:
      max_age_minutes: 60
    completeness:
      threshold_percent: 99.5
  
  quality_rules:
    - id: qr_001
      name: valid_custkey
      sql: "C_CUSTKEY > 0"
      severity: error
  
  governance:
    classification: CONFIDENTIAL
    ai_eligibility: PSEUDONYMIZED_ONLY
```

## Key Features

### 1. Governance Tags
Automatic tag application based on contracts:
- **DATA_CLASSIFICATION**: PUBLIC, INTERNAL, CONFIDENTIAL, RESTRICTED
- **PII_TYPE**: NONE, LOW, MODERATE, HIGH
- **AI_ALLOWED**: TRUE, FALSE, PSEUDONYMIZED_ONLY

### 2. Dynamic Tables
Automated transformation pipeline:
```sql
-- Example: Customer dimension with derived attributes
CREATE DYNAMIC TABLE DIM_CUSTOMER
    TARGET_LAG = '1 hour'
AS
SELECT
    C_CUSTKEY,
    SHA2(C_NAME, 256) AS CUSTOMER_NAME_HASH,  -- Pseudonymized
    C_MKTSEGMENT AS MARKET_SEGMENT,
    CASE WHEN C_ACCTBAL >= 8000 THEN 'PREMIUM' ... END AS CUSTOMER_TIER
FROM RAW_DEV.RAW_TPCH.CUSTOMER_RAW
WHERE _IS_CURRENT = TRUE;
```

### 3. Contract Validation
```sql
-- Validate a specific contract
CALL GOVERNANCE.CONTRACT_REGISTRY.VALIDATE_CONTRACT('tpch_customer_v1');

-- Run all quality rules
CALL GOVERNANCE.CONTRACT_REGISTRY.EXECUTE_QUALITY_RULES('tpch_customer_v1');

-- Check freshness SLA
CALL GOVERNANCE.CONTRACT_REGISTRY.CHECK_FRESHNESS_SLA('tpch_customer_v1');
```

### 4. Generate Contracts from Any Table
```sql
-- Generate a contract from an existing table
CALL GOVERNANCE.CONTRACT_REGISTRY.GENERATE_CONTRACT_FROM_TABLE(
    'MY_DATABASE', 'MY_SCHEMA', 'MY_TABLE', 'MY_SYSTEM'
);
```

### 5. Observability Dashboard
Key views for monitoring:
- `VW_DASHBOARD_KPIS` - High-level metrics
- `VW_CONTRACT_HEALTH_DASHBOARD` - Per-contract health
- `VW_SLA_COMPLIANCE_TREND` - Trending over time
- `VW_ACTIVE_ALERTS` - Current violations and warnings
- `VW_TAG_COVERAGE` - Governance tag completeness

### 6. Role-Based Access Control

The demo includes a complete role hierarchy implementing least-privilege access:

```
                   ACCOUNTADMIN
                        │
                   DATA_ADMIN
                        │
    ┌───────────────────┼───────────────────┐
    │                   │                   │
DATA_ENGINEER     DATA_STEWARD        PII_VIEWER
    │                   │                   │
    └───────►  DATA_ANALYST  AI_AGENT  ◄────┘
                   │         │
                   └────┬────┘
                        │
                   BI_VIEWER
```

| Role | Access Level | Use Case |
|------|--------------|----------|
| `DATA_ADMIN` | Full access all layers | Administration |
| `DATA_ENGINEER` | RAW + CURATED read/write | Pipeline management |
| `DATA_STEWARD` | Contracts + Observability | Governance management |
| `PII_VIEWER` | Unmasked PII access | Compliance/Legal |
| `DATA_ANALYST` | Semantic layer (masked) | BI and analytics |
| `AI_AGENT` | AI-safe views only | Cortex/ML workloads |
| `BI_VIEWER` | Summary views only | Dashboard consumption |

**Demo Users:**
- `DEMO_DATA_ADMIN`, `DEMO_DATA_ENGINEER`, `DEMO_DATA_STEWARD`
- `DEMO_ANALYST_SALES`, `DEMO_ANALYST_MARKETING`
- `DEMO_AI_AGENT`, `DEMO_BI_VIEWER`, `DEMO_PII_VIEWER`

## Sample Queries

### Contract Health Overview
```sql
SELECT 
    CONTRACT_ID,
    OVERALL_HEALTH,
    QUALITY_SCORE,
    FRESHNESS_STATUS,
    CONSUMER_COUNT
FROM GOVERNANCE.OBSERVABILITY.VW_CONTRACT_HEALTH_DASHBOARD
ORDER BY OVERALL_SCORE ASC;
```

### Sales Analytics (AI-Safe)
```sql
SELECT 
    REGION_NAME,
    MARKET_SEGMENT,
    COUNT(DISTINCT CUSTOMER_ID) as customers,
    SUM(NET_REVENUE) as revenue,
    AVG(DISCOUNT_PERCENTAGE) as avg_discount
FROM SEM_DEV.SEM_SALES.VW_SALES_ANALYTICS
GROUP BY REGION_NAME, MARKET_SEGMENT
ORDER BY revenue DESC;
```

### Customer Segmentation
```sql
SELECT 
    CUSTOMER_SEGMENT,
    COUNT(*) as customer_count,
    AVG(LIFETIME_VALUE) as avg_ltv,
    AVG(RECENCY_SCORE) as avg_recency
FROM SEM_DEV.SEM_CUSTOMER.VW_CUSTOMER_ANALYTICS
GROUP BY CUSTOMER_SEGMENT
ORDER BY customer_count DESC;
```

## Extending the Demo

### Adding a New Data Source

1. **Create a data contract** in `contracts/data/`:
   ```yaml
   contract:
     id: my_source_v1
     version: 1.0.0
     # ... define schema, SLAs, quality rules
   ```

2. **Or generate automatically**:
   ```sql
   CALL GOVERNANCE.CONTRACT_REGISTRY.GENERATE_CONTRACT_FROM_TABLE(
       'DATABASE', 'SCHEMA', 'TABLE', 'SYSTEM_NAME'
   );
   ```

3. **Create RAW layer table** matching the contract

4. **Create Dynamic Tables** for CURATED layer

5. **Create Semantic Views** for consumption

### Python Contract Validation

```bash
cd tools
python validate_contracts.py
```

### Custom Quality Rules

Add rules to your contract:
```yaml
quality_rules:
  - id: qr_custom_001
    name: custom_business_rule
    type: table_check
    sql: "AVG(AMOUNT) BETWEEN 100 AND 10000"
    severity: warning
```

## Key Principles from Enterprise Architecture Guide v.5

### Intent as Executable Constraints

Contracts encode six dimensions of intent that the platform enforces at runtime:

| Intent Dimension | Contract Implementation |
|-----------------|------------------------|
| **Meaning** | Column descriptions, semantic models |
| **Ownership** | Producer team, owner, contact |
| **Stability** | Version, status, breaking change tracking |
| **Allowed Use** | Consumer registry, access controls |
| **Risk Class** | DATA_CLASSIFICATION, governance.classification |
| **AI Eligibility** | AI_ALLOWED tag, ai_constraints block |

### Why This Matters

> *"Ambiguity can only be resolved before it is encoded. Once ambiguity reaches automation, the organization is no longer debating meaning—it is reacting to outcomes after the fact."*

This demo forces disambiguation at contract definition time, ensuring that:
- Every column has explicit classification
- Every PII field is tagged
- Every consumer is registered
- Every SLA is measurable

## Snowflake Intelligence Sample Questions

See **[Sample Questions](docs/SAMPLE_QUESTIONS.md)** for 125+ proven questions across:

| Category | Examples |
|----------|----------|
| **Sales Analytics** | "What was revenue by region last quarter?" |
| **Customer Analytics** | "Which customers are at risk of churning?" |
| **Product Analytics** | "Which products have low stock but high sales?" |
| **Supplier Analytics** | "Which suppliers have the best on-time delivery?" |
| **Contract Health** | "Which contracts have critical issues?" |
| **Data Governance** | "What percentage of columns have governance tags?" |
| **Trust & Lineage** | "Show me consumer dependencies by contract" |

## Resources

- [Sample Questions for Snowflake Intelligence](docs/SAMPLE_QUESTIONS.md)
- [Enterprise Architecture Guide Alignment](docs/ARCHITECTURE_ALIGNMENT.md)
- [Snowflake Object Tagging](https://docs.snowflake.com/en/user-guide/object-tagging)
- [Snowflake Dynamic Tables](https://docs.snowflake.com/en/user-guide/dynamic-tables-intro)
- [Snowflake Cortex](https://docs.snowflake.com/en/guides-overview-ai-features)
- [Data Contract Specification](https://datacontract.com/)

## License

MIT License - See LICENSE file for details.

## Contributing

Contributions welcome! Please read CONTRIBUTING.md for guidelines.

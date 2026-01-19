# Snowflake Data Contracts Demo

> A comprehensive demonstration of enforcing data contracts in a production Snowflake environment using TPCH sample data, built on **Snowflake Horizon** governance capabilities.

## Snowflake Horizon Governance

This demo leverages **[Snowflake Horizon](https://www.snowflake.com/en/data-cloud/horizon/)** unified governance:

| Horizon Capability | Implementation in This Demo |
|--------------------|----------------------------|
| **Object Tagging** | `DATA_CLASSIFICATION`, `PII_TYPE`, `AI_ALLOWED`, `CONTRACT_ID` tags |
| **Tag-Based Masking Policies** | Dynamic masking based on PII_TYPE tags |
| **Access History** | Consumer tracking and lineage |
| **Data Classification** | Automatic sensitivity labeling on columns |
| **Dynamic Tables** | Automated, declarative data pipelines |
| **Role-Based Access Control** | Hierarchical roles with least-privilege access |
| **Secure Data Sharing** | Consumer registration and contract-based access |

## Snowflake AI & ML Capabilities

This demo is designed for **Snowflake Cortex** and AI-powered applications:

| AI Capability | Implementation in This Demo |
|--------------|----------------------------|
| **Cortex Analyst** | YAML semantic models enable natural language SQL generation |
| **Snowflake Intelligence** | AI-powered insights on business and governance data |
| **Cortex LLM Functions** | `COMPLETE()`, `SUMMARIZE()`, `TRANSLATE()` on contract-governed data |
| **Cortex Search** | Semantic search over product catalogs and customer data |
| **Cortex Fine-Tuning** | Train custom models on AI-eligible data (AI_ALLOWED=TRUE) |
| **ML Functions** | `FORECAST()`, `ANOMALY_DETECTION()`, `CLASSIFICATION()` |
| **Snowpark ML** | Build ML pipelines on governed, AI-safe semantic views |

### Building AI Agents with This Architecture

The contract-first architecture provides the foundation for **trustworthy AI agents**:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         AI AGENT ARCHITECTURE                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                   🤖 STREAMLIT APP (Cortex Analyst)                   │  │
│  │         Natural Language Interface • Chat UI • Results Display        │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                    │                                        │
│                                    ▼                                        │
│  ┌─────────────┐    ┌─────────────────┐    ┌─────────────────────────────┐  │
│  │   USER      │    │  CORTEX ANALYST │    │    SEMANTIC LAYER           │  │
│  │   QUERY     │───▶│  + LLM          │───▶│    (AI-Safe Views)          │  │
│  │             │    │                 │    │                             │  │
│  │ "Show me    │    │ Parses intent,  │    │ • AI_ALLOWED = TRUE         │  │
│  │  top        │    │ generates SQL   │    │ • PII pseudonymized         │  │
│  │  customers" │    │ from semantic   │    │ • Contract guarantees       │  │
│  │             │    │ model YAML      │    │ • Lineage tracked           │  │
│  └─────────────┘    └─────────────────┘    └─────────────────────────────┘  │
│                              │                          │                   │
│                              ▼                          ▼                   │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                     GOVERNANCE ENFORCEMENT                            │  │
│  │  • AI_ALLOWED tag checked before data access                          │  │
│  │  • Masking policies applied at query time                             │  │
│  │  • Access logged to ACCESS_HISTORY                                    │  │
│  │  • Contract SLAs validated                                            │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Key patterns for AI agents:**

1. **Use the `AI_AGENT` role** - Pre-configured with access only to AI-safe views
2. **Query semantic models** - Cortex Analyst uses YAML models in `@SEM_DEV.SEM_SALES.SEMANTIC_MODELS`
3. **Respect AI_ALLOWED tags** - Only data tagged `AI_ALLOWED = TRUE` or `PSEUDONYMIZED_ONLY` is accessible
4. **Audit everything** - All agent queries logged via Access History for compliance

## Architectural Foundation

This demo implements the principles from the **[Enterprise Architecture Guide for the Snowflake Data Cloud v.5](docs/ARCHITECTURE_ALIGNMENT.md)**, specifically:

> *"AI, governance, and automation cannot scale unless business intent is explicit, portable, and enforceable by the data platform itself."*

The core dependency chain: **People → Data → Governance → Automation** is enforced through:

| Layer | Implementation | Horizon Features |
|-------|---------------|------------------|
| **People** | Producer ownership, consumer registration | Access History, Secure Sharing |
| **Data** | Explicit schema contracts with semantic meaning | Object Tagging, Data Classification |
| **Governance** | Runtime-enforced tags and policies | Tag-Based Policies, Masking |
| **Automation** | Dynamic tables, scheduled validation, alerting | Dynamic Tables, Tasks |

## Overview

This demo showcases a **contract-first data architecture** in Snowflake, implementing:

- **Data Contracts as Code**: YAML-based contracts defining schema, quality rules, SLAs, and governance
- **Three-Layer Architecture**: RAW → CURATED → SEMANTIC data flow
- **Snowflake Horizon Governance**: Tag-based classification, PII detection, and AI eligibility using native Snowflake features
- **Dynamic Tables**: Automated transformation pipelines with declarative lag targets
- **Cortex Analyst Integration**: First-class Snowflake semantic views with YAML models for natural language queries
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
│         ┌──────────────────────────┼──────────────────────────┐             │
│         ▼                          ▼                          ▼             │
│  ┌─────────────────┐    ┌───────────────────┐    ┌─────────────────────┐   │
│  │ 🔮 HORIZON      │    │ 🤖 CORTEX         │    │  OBSERVABILITY      │   │
│  │    DASHBOARD    │    │    ANALYST        │    │  VIEWS              │   │
│  │                 │    │                   │    │                     │   │
│  │ • Stoplights    │    │ • Natural Lang    │    │ • VW_DASHBOARD_KPIS │   │
│  │ • Health KPIs   │    │ • Semantic Models │    │ • VW_CONTRACT_HEALTH│   │
│  │ • Tag Coverage  │    │ • Query Results   │    │ • VW_SLA_COMPLIANCE │   │
│  └─────────────────┘    └───────────────────┘    └─────────────────────┘   │
│         │                          │                                        │
│         └──────────────────────────┘                                        │
│                          │                                                  │
│                          ▼                                                  │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │               ❄️ STREAMLIT IN SNOWFLAKE APPLICATION                   │  │
│  │  • Cortex Analyst Chat    • Horizon Dashboard    • Contract Explorer  │  │
│  │  • Natural Language UI    • Stoplight Metrics    • Governance Views   │  │
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
   
   -- Step 1: Initial Setup (roles, warehouses, databases, tags)
   -- Run: sql/01_setup.sql (AS ACCOUNTADMIN)
   
   -- Step 2: Contract Registry
   -- Run: sql/02_contract_registry.sql (AS DATA_ADMIN)
   
   -- Step 3: RAW Layer Tables
   -- Run: sql/03_raw_layer_tables.sql (AS DATA_ADMIN)
   
   -- Step 4: Load TPCH Data
   -- Run: sql/04_direct_load_tpch.sql (AS DATA_ADMIN)
   
   -- Step 5: Curated Layer (Dynamic Tables)
   -- Run: sql/05_curated_layer_dynamic_tables.sql (AS DATA_ADMIN)
   
   -- Step 6: Semantic Layer
   -- Run: sql/06_semantic_layer.sql (AS DATA_ADMIN)
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
   -- Step 7: Contract Validation (AS DATA_ADMIN)
   -- Run: sql/07_contract_validation.sql
   
   -- Step 8: Observability Dashboard (AS DATA_ADMIN)
   -- Run: sql/08_observability_dashboard.sql
   
   -- Step 9: Contract Generator - Optional (AS DATA_ADMIN)
   -- Run: sql/09_contract_generator_proc.sql
   
   -- Step 10: Load Sample Data for Demo (AS DATA_ADMIN)
   -- Run: sql/10_demo_sample_data.sql
   ```
   
   **To reset the demo environment:**
   ```sql
   -- Cleanup (removes all demo objects)
   -- Run: sql/99_cleanup_demo.sql (AS ACCOUNTADMIN)
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
│   ├── 01_setup.sql                # Roles, warehouses, databases, tags (ACCOUNTADMIN)
│   ├── 02_contract_registry.sql    # Contract tables and procedures
│   ├── 03_raw_layer_tables.sql     # RAW layer with governance tags
│   ├── 04_direct_load_tpch.sql     # Load TPCH sample data
│   ├── 05_curated_layer_dynamic_tables.sql  # Dynamic Tables
│   ├── 06_semantic_layer.sql       # Semantic views for Cortex Analyst
│   ├── 07_contract_validation.sql  # Validation procedures
│   ├── 08_observability_dashboard.sql  # Monitoring views
│   ├── 09_contract_generator_proc.sql  # Contract generator utility
│   ├── 10_demo_sample_data.sql     # Sample data for demo
│   ├── 12_streamlit_app.sql        # Deploy Streamlit app
│   └── 99_cleanup_demo.sql         # Reset/cleanup script (ACCOUNTADMIN)
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
├── tools/                          # Utilities
│   ├── generate_contract.py        # Contract generator (Python)
│   ├── validate_contracts.py       # Contract validation (Python)
│   ├── upload_semantic_models.py   # Upload models to stage (Python)
│   ├── upload_semantic_models.sql  # Upload models to stage (SnowSQL)
│   └── upload_semantic_models_notebook.py  # For Snowflake Notebooks
│
├── streamlit/                      # Streamlit in Snowflake App
│   └── data_contracts_app.py       # Main app with Cortex + Horizon dashboard
│
├── docs/                           # Documentation
│   ├── DATA_CONTRACTS_WIREFRAME.md # Detailed design document
│   ├── ARCHITECTURE_ALIGNMENT.md   # EA Guide v.5 alignment
│   └── SAMPLE_QUESTIONS.md         # 125+ Cortex Analyst questions
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

### 1. Snowflake Horizon Object Tagging
Automatic tag application based on contracts using Snowflake Horizon's unified governance:
- **DATA_CLASSIFICATION**: PUBLIC, INTERNAL, CONFIDENTIAL, RESTRICTED
- **PII_TYPE**: NONE, LOW, MODERATE, HIGH  
- **AI_ALLOWED**: TRUE, FALSE, PSEUDONYMIZED_ONLY
- **CONTRACT_ID**: Links objects to their governing contract
- **RESIDENCY_REGION**: GLOBAL, ORIGIN, EU_ONLY, US_ONLY

### 2. Snowflake Dynamic Tables
Automated, declarative transformation pipelines with Snowflake's Dynamic Tables:
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

### 6. Deploy the Streamlit App
```sql
-- Run the deployment script
@sql/12_streamlit_app.sql

-- Then upload the app file to the stage:
-- Method 1: SnowSQL
PUT file://streamlit/data_contracts_app.py @SEM_DEV.SEM_SALES.STREAMLIT_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE;

-- Method 2: Snowsight UI
-- Navigate to Data → SEM_DEV → SEM_SALES → STREAMLIT_STAGE → Upload Files
```

Access the app at: **Projects → Streamlit → DATA_CONTRACTS_APP**

**App Features:**

| Tab | Description |
|-----|-------------|
| 🤖 **Cortex Analyst** | Natural language queries on semantic models |
| 🔮 **Horizon Dashboard** | Governance health with stoplights, charts, alerts |
| 📊 **Contract Details** | Individual contract exploration |
| ℹ️ **About** | Architecture overview and resources |

### 7. Role-Based Access Control

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
- `DEMO_DATA_ANALYST`, `DEMO_BI_VIEWER`
- `DEMO_AI_AGENT`, `DEMO_PII_VIEWER`

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

## Cortex Analyst & Snowflake Intelligence

The semantic models in this demo are designed for **Cortex Analyst** natural language queries:

```sql
-- Query sales data using natural language
SELECT SNOWFLAKE.CORTEX.ANALYST(
    'What was our revenue by region last quarter?',
    '@SEM_DEV.SEM_SALES.SEMANTIC_MODELS/sales_analytics_model.yaml'
);

-- Query governance data using natural language  
SELECT SNOWFLAKE.CORTEX.ANALYST(
    'Which contracts have SLA violations?',
    '@SEM_DEV.SEM_SALES.SEMANTIC_MODELS/governance_analytics_model.yaml'
);
```

See **[Sample Questions](docs/SAMPLE_QUESTIONS.md)** for 125+ proven questions across:

| Category | Semantic Model | Examples |
|----------|---------------|----------|
| **Sales Analytics** | `sales_analytics_model.yaml` | "What was revenue by region last quarter?" |
| **Customer Analytics** | `customer_analytics_model.yaml` | "Which customers are at risk of churning?" |
| **Product Analytics** | `product_analytics_model.yaml` | "Which products have low stock but high sales?" |
| **Supplier Analytics** | `supplier_analytics_model.yaml` | "Which suppliers have the best on-time delivery?" |
| **Governance Analytics** | `governance_analytics_model.yaml` | "Which contracts have critical issues?" |

### Using Cortex LLM Functions with Governed Data

```sql
-- Summarize customer feedback (respects AI_ALLOWED tags)
SELECT 
    CUSTOMER_ID,
    SNOWFLAKE.CORTEX.SUMMARIZE(FEEDBACK_TEXT) as SUMMARY
FROM SEM_DEV.SEM_CUSTOMER.VW_CUSTOMER_FEEDBACK
WHERE AI_ALLOWED = TRUE;

-- Classify support tickets
SELECT 
    TICKET_ID,
    SNOWFLAKE.CORTEX.CLASSIFY_TEXT(
        TICKET_DESCRIPTION, 
        ['billing', 'technical', 'account', 'other']
    ) as CATEGORY
FROM SEM_DEV.SEM_SALES.VW_SUPPORT_TICKETS;
```

## Resources

### Snowflake Horizon (Governance)
- [Snowflake Horizon Overview](https://www.snowflake.com/en/data-cloud/horizon/)
- [Object Tagging](https://docs.snowflake.com/en/user-guide/object-tagging)
- [Tag-Based Masking Policies](https://docs.snowflake.com/en/user-guide/security-column-ddm-intro)
- [Data Classification](https://docs.snowflake.com/en/user-guide/governance-classify-concepts)
- [Access History](https://docs.snowflake.com/en/sql-reference/account-usage/access_history)

### Snowflake Cortex (AI & ML)
- [Cortex Analyst (Semantic Models)](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-analyst)
- [Cortex LLM Functions](https://docs.snowflake.com/en/user-guide/snowflake-cortex/llm-functions)
- [Cortex Search](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-search)
- [Cortex Fine-Tuning](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-finetuning)
- [Cortex ML Functions](https://docs.snowflake.com/en/guides-overview-ml-functions)
- [Snowpark ML](https://docs.snowflake.com/en/developer-guide/snowpark-ml/index)

### Snowflake Intelligence & Agents
- [Snowflake Intelligence](https://docs.snowflake.com/en/user-guide/snowflake-intelligence)
- [Building AI Agents](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-analyst)
- [Streamlit in Snowflake](https://docs.snowflake.com/en/developer-guide/streamlit/about-streamlit)

### Data Platform
- [Dynamic Tables](https://docs.snowflake.com/en/user-guide/dynamic-tables-intro)
- [Tasks & Scheduling](https://docs.snowflake.com/en/user-guide/tasks-intro)
- [Alerts](https://docs.snowflake.com/en/user-guide/alerts)

### Architecture & Standards
- [Sample Questions for Snowflake Intelligence](docs/SAMPLE_QUESTIONS.md)
- [Enterprise Architecture Guide Alignment](docs/ARCHITECTURE_ALIGNMENT.md)
- [Data Contract Specification](https://datacontract.com/)

## License

MIT License - See LICENSE file for details.

## Contributing

Contributions welcome! Please read CONTRIBUTING.md for guidelines.

# Architecture Alignment with Enterprise Architecture Guide v.5

This document maps the Snowflake Data Contracts Demo to the principles outlined in the **Enterprise Architecture Guide for the Snowflake Data Cloud v.5**, implemented using **Snowflake Horizon** governance capabilities.

## Snowflake Horizon Capabilities Used

| Horizon Feature | Purpose in This Demo |
|----------------|---------------------|
| **Object Tagging** | Apply governance metadata (DATA_CLASSIFICATION, PII_TYPE, AI_ALLOWED) |
| **Tag-Based Masking Policies** | Enforce PII protection based on tags at query time |
| **Data Classification** | Automatic sensitivity labeling for compliance |
| **Access History** | Track consumer usage and data lineage |
| **Dynamic Tables** | Declarative, automated data transformation pipelines |
| **Cortex Analyst** | Natural language queries via semantic models |
| **Snowflake Intelligence** | AI-powered insights on data and governance |
| **Row Access Policies** | Fine-grained access control based on user context |
| **Secure Data Sharing** | Contract-based consumer access patterns |

## Core Principle: The Dependency Chain

The guide establishes a fundamental truth:

> *"Complex systems do not scale outcomes until they stabilize dependencies."*

The dependency chain flows in one direction:

```
People → Data → Governance → Automation
```

Each layer inherits the stability (or instability) of the layer that precedes it.

### How This Demo Implements the Chain

| Layer | Responsibility | Demo Implementation | Horizon Features |
|-------|---------------|---------------------|------------------|
| **People** | Define intent and decision context | Contract `producer` ownership, consumer registration | Access History, Secure Sharing |
| **Data** | Encode meaning and ownership | Schema definitions, column contracts, quality rules | Object Tagging, Data Classification |
| **Governance** | Enforce constraints at runtime | Tags, masking policies, row access policies | Tag-Based Masking, Row Access Policies |
| **Automation** | Execute decisions at scale | Dynamic Tables, scheduled validation, alerting | Dynamic Tables, Tasks, Alerts |

---

## Intent as Executable Constraints

The guide defines six dimensions of intent that must be executable, not merely documented:

### 1. Meaning (What does this data represent?)

```yaml
# From contracts/data/tpch_customer_v1.yml
columns:
  - name: C_CUSTKEY
    description: "Unique customer identifier (primary key)"
    type: NUMBER(38,0)
```

**Enforcement**: Column descriptions flow through to Snowflake comments, semantic models enable natural language queries.

### 2. Ownership (Who is accountable?)

```yaml
producer:
  system: SNOWFLAKE_SAMPLE_TPCH
  team: Demo Data Engineering
  owner: demo-team@company.com
  slack_channel: "#demo-data-contracts"
```

**Enforcement**: Breaking changes require consumer acknowledgment, alerts route to owner.

### 3. Stability (How may this change?)

```yaml
contract:
  id: tpch_customer_v1
  version: 1.0.0
  status: active  # draft | review | approved | active | deprecated | retired
```

**Enforcement**: Version history tracked, semantic versioning for breaking changes.

### 4. Allowed Use (Who may use this data and for what purpose?)

```yaml
consumers:
  - team: Analytics Platform
    contact: analytics@company.com
    use_case: Customer segmentation and sales analysis
    access_level: read_masked

access:
  allowed_roles:
    - DATA_ANALYST_${REGION}
    - BI_DEVELOPER_${REGION}
```

**Enforcement**: Consumer registration, role-based access, masking policies.

### 5. Risk Class (What protections apply?)

```yaml
tags:
  DATA_CLASSIFICATION: CONFIDENTIAL
  PII_TYPE: MODERATE
  RESIDENCY_REGION: ORIGIN

governance:
  classification: CONFIDENTIAL
  residency_requirements:
    - "PII columns must not leave origin region without masking"
```

**Enforcement via Snowflake Horizon**: 
- **Object Tagging**: Tags applied at column level via `ALTER TABLE ... SET TAG`
- **Tag-Based Masking Policies**: Masking rules evaluate tags at query time
- **Data Classification**: Automatic sensitivity detection and labeling

### 6. AI Eligibility (May automation or AI consume this data?)

```yaml
tags:
  AI_ALLOWED: PSEUDONYMIZED_ONLY

ai_constraints:
  embedding_allowed: true
  raw_pii_in_output: false
  model_training_allowed: true
```

**Enforcement via Snowflake Cortex**: 
- **AI_ALLOWED tag** declares eligibility at column level
- **Semantic models** (YAML) define what Cortex Analyst can query
- **AI_AGENT role** restricts access to AI-safe views only
- **Pseudonymization** applied in semantic layer (SHA2 hashing)

---

## Streamlit in Snowflake Application

The demo includes a fully-featured **Streamlit in Snowflake** application (`streamlit/data_contracts_app.py`) that brings together all capabilities:

### Application Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    STREAMLIT IN SNOWFLAKE APPLICATION                       │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                         SIDEBAR NAVIGATION                          │    │
│  │  ❄️ Logo • Quick Stats • Page Selection                            │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                             │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐              │
│  │ 🤖 CORTEX       │  │ 🔮 HORIZON      │  │ 📊 CONTRACT     │              │
│  │    ANALYST      │  │    DASHBOARD    │  │    DETAILS      │              │
│  │                 │  │                 │  │                 │              │
│  │ • Chat UI       │  │ • Stoplights    │  │ • Selector      │              │
│  │ • Model Select  │  │ • KPI Cards     │  │ • Consumers     │              │
│  │ • Sample Qs     │  │ • Trend Charts  │  │ • Quality Rules │              │
│  │ • Results DF    │  │ • Alert List    │  │ • YAML View     │              │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘              │
│                                    │                                        │
│                                    ▼                                        │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                    OBSERVABILITY VIEWS                              │    │
│  │  VW_DASHBOARD_KPIS • VW_CONTRACT_HEALTH • VW_SLA_COMPLIANCE_TREND   │    │
│  │  VW_ACTIVE_ALERTS • VW_TAG_COVERAGE • VW_QUALITY_RULE_RESULTS       │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Key Features

| Tab | Purpose | Data Sources |
|-----|---------|--------------|
| **🤖 Cortex Analyst** | Natural language queries | Semantic models in stage |
| **🔮 Horizon Dashboard** | Governance health monitoring | Observability views |
| **📊 Contract Details** | Contract exploration | Contract registry tables |
| **ℹ️ About** | Architecture overview | Static content |

### Visual Design Elements

- **Snowflake Blue** (`#29B5E8`) - Primary branding color
- **Horizon Purple** (`#7C3AED`) - Gradient accents for governance
- **Stoplight Indicators** - 🟢🟡🔴 for health status
- **Dark Theme** - Modern, professional appearance
- **Custom CSS** - Branded cards, chat bubbles, metrics

---

## Snowflake Cortex AI Capabilities

This demo is designed to work with the full Snowflake Cortex AI platform:

### Cortex Analyst (Natural Language Queries)

The Streamlit app uses the **Cortex Analyst REST API** with native Semantic Views:

```python
# Cortex Analyst REST API call
POST /api/v2/cortex/analyst/message
{
    "messages": [{"role": "user", "content": [{"type": "text", "text": "What was revenue by region?"}]}],
    "semantic_view": "SEM_DEV.SEM_SALES.SALES_ANALYTICS"
}
```

The API returns structured responses including:
- Natural language explanation
- Generated semantic SQL
- Query results

The Streamlit app's **Cortex Analyst** tab provides an interactive chat interface for these queries.

**Query Semantic Views Directly:**

```sql
-- Using SEMANTIC_VIEW() function
SELECT * FROM SEMANTIC_VIEW(
    SEM_DEV.SEM_SALES.SALES_ANALYTICS
    DIMENSIONS REGION_NAME, YEAR
    METRICS total_revenue, order_count
);

-- Using AGG() for metrics with GROUP BY
SELECT REGION_NAME, AGG(total_revenue) AS revenue
FROM SEM_DEV.SEM_SALES.SALES_ANALYTICS
GROUP BY REGION_NAME;
```

### Cortex LLM Functions

Use LLM functions on governed data:

```sql
-- Summarize (respects AI_ALLOWED tags)
SELECT SNOWFLAKE.CORTEX.SUMMARIZE(description) FROM products;

-- Complete
SELECT SNOWFLAKE.CORTEX.COMPLETE('llama3.1-70b', 'Analyze this customer: ' || profile);

-- Translate
SELECT SNOWFLAKE.CORTEX.TRANSLATE(feedback, 'en', 'es');

-- Classify
SELECT SNOWFLAKE.CORTEX.CLASSIFY_TEXT(ticket, ['billing','technical','other']);
```

### Cortex ML Functions

Built-in ML on contract-governed data:

```sql
-- Forecasting
SELECT SNOWFLAKE.CORTEX.FORECAST(date_column, value_column, 30) FROM sales;

-- Anomaly Detection  
SELECT SNOWFLAKE.CORTEX.ANOMALY_DETECTION(metric, timestamp) FROM metrics;

-- Classification
SELECT SNOWFLAKE.CORTEX.CLASSIFICATION(features) FROM customers;
```

### Building AI Agents

The contract architecture enables trustworthy AI agents:

| Pattern | Implementation |
|---------|---------------|
| **Least-privilege access** | AI_AGENT role with semantic layer access only |
| **Data eligibility** | AI_ALLOWED tag checked before access |
| **PII protection** | Pseudonymization in semantic views |
| **Audit trail** | Access History logs all agent queries |
| **Natural language** | Cortex Analyst + semantic models |
| **Guardrails** | Contract SLAs and quality rules validate data |

---

## Three-Layer Architecture

The guide recommends separating concerns across layers. Our demo implements:

### RAW Layer (RAW_DEV)
- **Purpose**: Capture data with minimal transformation
- **Trust Model**: Source system fidelity
- **Key Features**:
  - Direct load from sources
  - Current record management (_IS_CURRENT flag)
  - Row hash for change detection
  - Full governance tags applied

### CURATED Layer (CURATED_DEV)
- **Purpose**: Business-ready transformations
- **Trust Model**: Business rule enforcement
- **Key Features**:
  - Dynamic Tables for automated refresh
  - Derived attributes and classifications
  - Dimensional modeling
  - Inherited governance from RAW

### SEMANTIC Layer (SEM_DEV)
- **Purpose**: Consumer-facing, AI-ready products
- **Trust Model**: Contract guarantees
- **Key Features**:
  - First-class Snowflake semantic views (not secure views)
  - Designed for Cortex Analyst and Snowflake Intelligence
  - Pseudonymized identifiers for AI safety
  - YAML semantic models with dimensions, measures, and sample questions
  - Pre-calculated metrics and business-friendly column names
  - Masking policies for PII at query time (not in view definition)

---

## Contract Types

### Data Contracts (Producer → Platform)

Located in `contracts/data/`, these define:
- What the producer commits to deliver
- Schema, SLAs, quality rules
- Governance classifications
- Lineage from source systems

### Product Contracts (Platform → Consumer)

Located in `contracts/products/`, these define:
- What consumers can rely on
- Output specification
- Freshness and quality guarantees
- AI constraints and access controls

---

## Observability: The Feedback Loop

The guide emphasizes reflexive systems that learn:

> *"When the system can see itself clearly, it can improve itself deliberately."*

Our observability layer provides:

| View | Purpose |
|------|---------|
| `VW_DASHBOARD_KPIS` | High-level health metrics |
| `VW_CONTRACT_HEALTH_DASHBOARD` | Per-contract health scoring |
| `VW_SLA_COMPLIANCE_TREND` | Trending over time |
| `VW_QUALITY_SCORE_TREND` | Quality rule pass rates |
| `VW_ACTIVE_ALERTS` | Current violations |
| `VW_TAG_COVERAGE` | Governance completeness |
| `VW_CONTRACT_LINEAGE` | Dependency graph |

---

## Key Quotes Implemented

### On Contracts

> *"Publish contracts instead of assumptions."*

Every table in our demo has a corresponding contract that defines expectations before data flows.

### On Governance

> *"Enforce governance at runtime."*

Tags are applied via SQL, policies execute during query processing, not as after-the-fact audits.

### On AI

> *"Treat AI as a participant, not an exception."*

`AI_ALLOWED` tags explicitly declare what data AI systems may consume, with `PSEUDONYMIZED_ONLY` as the bridge between protection and utility.

### On Scale

> *"Ambiguity can only be resolved before it is encoded."*

Contracts force disambiguation at design time, before data enters the platform.

---

## Extending This Demo

When adding new data sources, follow the dependency chain:

1. **People**: Who owns this data? Who will consume it?
2. **Data**: What does each column mean? What are the constraints?
3. **Governance**: What classification? What PII level? AI eligible?
4. **Automation**: Dynamic tables, scheduled validation, alerting

Use the contract generator to bootstrap:

```sql
CALL GOVERNANCE.CONTRACT_REGISTRY.GENERATE_CONTRACT_FROM_TABLE(
    'DATABASE', 'SCHEMA', 'TABLE', 'SYSTEM_NAME'
);
```

Then refine the generated contract with business context that only people can provide.

---

## References

### Snowflake Horizon Governance
- [Snowflake Horizon Overview](https://www.snowflake.com/en/data-cloud/horizon/)
- [Object Tagging](https://docs.snowflake.com/en/user-guide/object-tagging)
- [Tag-Based Masking Policies](https://docs.snowflake.com/en/user-guide/security-column-ddm-intro)
- [Data Classification](https://docs.snowflake.com/en/user-guide/governance-classify-concepts)
- [Access History](https://docs.snowflake.com/en/sql-reference/account-usage/access_history)
- [Row Access Policies](https://docs.snowflake.com/en/user-guide/security-row-intro)

### Snowflake Cortex (AI & ML)
- [Cortex Analyst](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-analyst)
- [Cortex LLM Functions](https://docs.snowflake.com/en/user-guide/snowflake-cortex/llm-functions)
- [Cortex Search](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-search)
- [Cortex Fine-Tuning](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-finetuning)
- [Cortex ML Functions](https://docs.snowflake.com/en/guides-overview-ml-functions)
- [Snowflake Intelligence](https://docs.snowflake.com/en/user-guide/snowflake-intelligence)
- [Snowpark ML](https://docs.snowflake.com/en/developer-guide/snowpark-ml/index)

### Snowflake Automation
- [Dynamic Tables](https://docs.snowflake.com/en/user-guide/dynamic-tables-intro)
- [Tasks](https://docs.snowflake.com/en/user-guide/tasks-intro)
- [Alerts](https://docs.snowflake.com/en/user-guide/alerts)

### Architecture
- [Enterprise Architecture Guide for the Snowflake Data Cloud v.5](https://docs.google.com/document/d/1C2GtbfRo0koEtvrMejTzzyRib7eadsVstOaAlrUls-w)
- [Data Contract Specification](https://datacontract.com/)

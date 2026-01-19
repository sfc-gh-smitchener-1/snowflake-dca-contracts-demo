# Repository Description

## Short Description (for GitHub)

**Snowflake Data Contracts Demo** — Built on **Snowflake Horizon** governance capabilities, this demo implements the Enterprise Architecture Guide for the Snowflake Data Cloud, demonstrating how to make business intent explicit, portable, and enforceable through data contracts, Cortex Analyst semantic models, and runtime governance using Object Tagging, Dynamic Tables, and Tag-Based Masking Policies.

---

## Full Description

### Snowflake Data Contracts Demo

> *"AI, governance, and automation cannot scale unless business intent is explicit, portable, and enforceable by the data platform itself."*
> — Enterprise Architecture Guide for the Snowflake Data Cloud v.5

A comprehensive demonstration of **contract-first data architecture** in Snowflake, implementing the core principles from the Enterprise Architecture Guide. This framework addresses the fundamental challenge facing modern data platforms:

**Complex systems do not scale outcomes until they stabilize dependencies.**

#### 🔗 The Dependency Chain

This demo enforces the one-way dependency chain that exists whether or not organizations explicitly design for it:

```
People → Data → Governance → Automation
```

| Layer | Responsibility | Demo Implementation |
|-------|---------------|---------------------|
| **People** | Define intent and decision context | Contract ownership, consumer registration |
| **Data** | Encode meaning and ownership | Schema definitions, semantic models |
| **Governance** | Enforce constraints at runtime | Tags, policies, access controls |
| **Automation** | Execute decisions at scale | Dynamic tables, validation, alerting |

Each layer inherits the stability (or instability) of the layer that precedes it. Governance cannot repair missing ownership. Automation cannot correct undefined constraints. The platform can only execute what has been made explicit.

#### 📋 Intent as Executable Constraints

The Enterprise Architecture Guide defines six dimensions of intent that must be **executable, not merely documented**. This demo implements all six:

| Intent Dimension | Question Answered | Implementation |
|-----------------|-------------------|----------------|
| **Meaning** | What does this data represent? | Column descriptions, semantic models |
| **Ownership** | Who is accountable? | Producer definitions, contact info |
| **Stability** | How may this change? | Version control, breaking change tracking |
| **Allowed Use** | Who may use this and for what? | Consumer registry, access controls |
| **Risk Class** | What protections apply? | DATA_CLASSIFICATION, governance tags |
| **AI Eligibility** | May AI consume this data? | AI_ALLOWED tags, pseudonymization |

> *"When intent cannot be executed, it exists only as documentation, and documentation does not scale."*

#### 🏗️ Three-Layer Architecture

| Layer | Purpose | Trust Model |
|-------|---------|-------------|
| **RAW** | Capture data with minimal transformation | Source system fidelity |
| **CURATED** | Business-ready transformations | Business rule enforcement |
| **SEMANTIC** | Consumer-facing, AI-ready products | Contract guarantees |

#### 🤖 Snowflake Cortex AI Integration

This demo is built for the full **Snowflake Cortex** AI platform:

| Cortex Capability | How This Demo Uses It |
|------------------|----------------------|
| **Cortex Analyst** | YAML semantic models enable natural language → SQL |
| **Snowflake Intelligence** | AI-powered insights on business + governance data |
| **Cortex LLM Functions** | `COMPLETE()`, `SUMMARIZE()`, `TRANSLATE()` on governed data |
| **Cortex Search** | Semantic search over product/customer data |
| **Cortex ML Functions** | `FORECAST()`, `ANOMALY_DETECTION()` on AI-eligible views |
| **Cortex Fine-Tuning** | Train custom models on `AI_ALLOWED=TRUE` data |

**Semantic Models for Cortex Analyst:**
- **Sales Analytics** — Revenue, orders, delivery (125+ sample questions)
- **Customer Analytics** — RFM scoring, segmentation, churn prediction
- **Product Analytics** — Inventory, margins, performance tiers
- **Supplier Analytics** — Vendor quality, delivery metrics
- **Governance Analytics** — Contract health, SLA compliance, trust

#### 🤖 Building AI Agents

The architecture provides the foundation for **trustworthy AI agents**:

1. **AI_AGENT role** — Pre-configured access to AI-safe semantic views only
2. **AI_ALLOWED tags** — Explicit declaration of AI-eligible data
3. **Pseudonymization** — PII protected via `PSEUDONYMIZED_ONLY` tag
4. **Semantic models** — YAML definitions for Cortex Analyst natural language queries
5. **Access History** — Full audit trail of agent data access

> *"Treat AI as a participant, not an exception."*

#### 🔐 Snowflake Horizon Governance at Runtime

> *"Publish contracts instead of assumptions. Enforce governance at runtime."*

Using **Snowflake Horizon** unified governance capabilities:

- **Object Tagging**: `DATA_CLASSIFICATION`, `PII_TYPE`, `AI_ALLOWED`, `CONTRACT_ID` tags
- **Tag-Based Masking Policies**: Dynamic column masking based on PII_TYPE tags
- **Data Classification**: Automatic sensitivity labeling at column level
- **Access History**: Who uses what data and for what purpose
- **Residency Controls**: GLOBAL, ORIGIN, EU_ONLY, US_ONLY
- **Breaking Changes**: Version control with consumer notification workflow

#### 👥 Role-Based Access Control

Implements least-privilege access patterns:

| Role | Access Pattern | Use Case |
|------|---------------|----------|
| DATA_ADMIN | Full access all layers | Administration |
| DATA_ENGINEER | RAW + CURATED management | Pipeline development |
| DATA_STEWARD | Contracts + Observability | Governance management |
| DATA_ANALYST | Semantic layer (masked PII) | BI and analytics |
| AI_AGENT | AI-safe views only | Cortex/ML workloads |
| BI_VIEWER | Summary views only | Dashboard consumption |

#### 📊 Observability: The Feedback Loop

> *"When the system can see itself clearly, it can improve itself deliberately."*

Real-time dashboards for:
- Contract health and SLA compliance
- Quality rule pass rates and trends
- Tag coverage and governance completeness
- Active alerts and breaking changes
- Consumer dependencies and lineage

#### 🎯 Key Principles Implemented

1. **Ambiguity resolved before encoding** — Contracts force disambiguation at design time
2. **Intent made executable** — Not documentation, but runtime-evaluated specifications
3. **Governance as platform behavior** — Enforced by the system, not by process
4. **AI as first-class participant** — Explicit eligibility, not afterthought exclusions
5. **Reflexive systems** — Observability enables continuous improvement

---

## GitHub About Section

Built on **Snowflake Horizon** — demonstrating data contracts, Cortex Analyst semantic models, Object Tagging, Tag-Based Masking, Dynamic Tables, and observability dashboards. "Business intent must be explicit, portable, and enforceable."

---

## One-Liner

Enterprise-grade data contracts for Snowflake Horizon: enforce intent with Object Tagging, Cortex Analyst semantic models, Tag-Based Masking, and real-time observability.

---

## Topics/Tags

```
snowflake, snowflake-horizon, data-contracts, data-governance, cortex-analyst, 
semantic-models, object-tagging, tag-based-masking, dynamic-tables,
enterprise-architecture, data-quality, sla-monitoring, ai-governance, 
data-mesh, data-products, snowflake-intelligence
```

---

## Key Quotes from Enterprise Architecture Guide v.5

> *"Complex systems do not scale outcomes until they stabilize dependencies."*

> *"AI cannot fix unclear semantics. Governance cannot repair missing ownership. Automation cannot correct undefined constraints."*

> *"Ambiguity can only be resolved before it is encoded. Once ambiguity reaches automation, the organization is no longer debating meaning—it is reacting to outcomes after the fact."*

> *"The role of architecture is to ensure that intent, contracts, and enforcement converge at reuse boundaries."*

> *"The architecture that endures separates intent from execution, so meaning survives automation and scale."*

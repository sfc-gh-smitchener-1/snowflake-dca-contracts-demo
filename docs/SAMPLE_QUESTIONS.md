# Sample Questions for Snowflake Intelligence & Cortex Analyst

This document provides proven sample questions that can be asked of **Snowflake Intelligence** and **Cortex Analyst** using the semantic models defined in this demo.

## Snowflake Cortex AI Features Used

| Cortex Feature | How It's Used |
|----------------|---------------|
| **Cortex Analyst** | Semantic models (YAML) define dimensions, measures, and relationships for natural language → SQL |
| **Snowflake Intelligence** | AI-powered insights using semantic model context |
| **Cortex LLM Functions** | `SUMMARIZE()`, `COMPLETE()`, `CLASSIFY_TEXT()` for enhanced analysis |
| **Cortex ML Functions** | `FORECAST()`, `ANOMALY_DETECTION()` for predictive questions |

## Snowflake Horizon Features Used

| Horizon Feature | How It Enables Queries |
|-----------------|------------------------|
| **Object Tagging** | Governance questions query `DATA_CLASSIFICATION`, `PII_TYPE`, `AI_ALLOWED` tags |
| **Access History** | Consumer and lineage questions query usage data |
| **Dynamic Tables** | Real-time data freshness for accurate answers |
| **Tag-Based Masking** | PII automatically masked based on role |

## How to Use These Questions

### With Cortex Analyst REST API

The Streamlit app uses the Cortex Analyst REST API with native Semantic Views:

```python
# API call to Cortex Analyst
POST /api/v2/cortex/analyst/message
{
    "messages": [{"role": "user", "content": [{"type": "text", "text": "What was revenue last quarter?"}]}],
    "semantic_view": "SEM_DEV.SEM_SALES.SALES_ANALYTICS"
}
```

### With Native Semantic View SQL

Query semantic views directly using the `SEMANTIC_VIEW()` function:

```sql
-- Using SEMANTIC_VIEW() function
SELECT * FROM SEMANTIC_VIEW(
    SEM_DEV.SEM_SALES.SALES_ANALYTICS
    DIMENSIONS REGION_NAME, YEAR
    METRICS total_revenue
);

-- Using AGG() for metrics
SELECT REGION_NAME, AGG(total_revenue) AS revenue
FROM SEM_DEV.SEM_SALES.SALES_ANALYTICS
GROUP BY REGION_NAME;
```

### For AI Agents

Use the `AI_AGENT` role which has access only to AI-safe semantic views:

```sql
USE ROLE AI_AGENT;
-- All queries automatically respect AI_ALLOWED tags
SELECT * FROM SEMANTIC_VIEW(
    SEM_DEV.SEM_SALES.SALES_ANALYTICS
    DIMENSIONS REGION_NAME
    METRICS total_revenue
);
```

## Question Categories

1. **Data Analytics Questions** - Business insights from the semantic models
2. **Trust & Governance Questions** - Contract adherence, data quality, and governance status

---

## Part 1: Data Analytics Questions

### Sales Analytics

#### Revenue & Performance

| Question | What It Answers |
|----------|-----------------|
| "What was our total revenue last year?" | Overall revenue performance |
| "Show me revenue by region" | Geographic revenue distribution |
| "Which market segment generates the most revenue?" | Segment performance ranking |
| "What is our average order value?" | Transaction size metrics |
| "Show me monthly revenue trend for the past year" | Revenue seasonality and trends |
| "Compare revenue between AMER, EMEA, and APAC" | Regional comparison |
| "What is our revenue by customer tier?" | Premium vs standard customer value |

#### Product Performance

| Question | What It Answers |
|----------|-----------------|
| "Which products are our top sellers by revenue?" | Best performing products |
| "What is the revenue by manufacturer?" | Manufacturer contribution |
| "Which brands have the highest sales volume?" | Brand performance |
| "Show me revenue by product price tier" | Economy vs premium performance |
| "Which product types have the highest return rates?" | Quality issues by category |

#### Discount & Margin Analysis

| Question | What It Answers |
|----------|-----------------|
| "What is our average discount rate?" | Discounting behavior |
| "Which regions receive the highest discounts?" | Geographic discount patterns |
| "Show me discount trends by quarter" | Seasonal discounting |
| "What is our gross margin by product category?" | Profitability by category |
| "Which manufacturers have the best margins?" | Supplier profitability |

#### Delivery & Operations

| Question | What It Answers |
|----------|-----------------|
| "What is our on-time delivery rate?" | Delivery performance |
| "Which shipping modes have the most delays?" | Carrier performance |
| "Show me late deliveries by region" | Geographic delivery issues |
| "What is our average delivery time?" | Fulfillment speed |
| "Which suppliers have the best delivery performance?" | Vendor reliability |

---

### Customer Analytics

#### Customer Base

| Question | What It Answers |
|----------|-----------------|
| "How many customers do we have?" | Customer base size |
| "Show me customers by market segment" | Segment distribution |
| "How are customers distributed across regions?" | Geographic spread |
| "What percentage of customers are premium tier?" | Customer tier breakdown |

#### Customer Value

| Question | What It Answers |
|----------|-----------------|
| "What is our average customer lifetime value?" | CLV metrics |
| "Which market segment has the highest LTV?" | Segment value comparison |
| "Show me lifetime value by region" | Geographic value patterns |
| "What is the total lifetime value of premium customers?" | High-value customer worth |

#### Customer Health & Churn

| Question | What It Answers |
|----------|-----------------|
| "How many customers are at risk of churning?" | Churn risk assessment |
| "Which customers are high-value at-risk?" | Priority retention targets |
| "How many customers have we lost (churned)?" | Churn volume |
| "Show me customer segments by activity status" | Engagement distribution |
| "What is the average recency score by segment?" | Engagement health |

#### RFM Analysis

| Question | What It Answers |
|----------|-----------------|
| "Show me RFM scores by region" | Regional engagement patterns |
| "Which segments have the highest frequency scores?" | Most engaged customers |
| "What is the monetary score distribution?" | Customer value distribution |
| "How many champion customers do we have?" | Best customer count |
| "Show me the breakdown of customer segments" | Segmentation overview |

---

### Product Analytics

#### Inventory & Stock

| Question | What It Answers |
|----------|-----------------|
| "Which products are out of stock?" | Stock-out situations |
| "Show me products with low stock" | Replenishment needs |
| "What is our total inventory value?" | Inventory investment |
| "Which products have low stock but high sales?" | Urgent restocking needs |
| "Show me inventory levels by manufacturer" | Supplier inventory |

#### Product Performance

| Question | What It Answers |
|----------|-----------------|
| "Which are our top performing products?" | Best sellers |
| "Show me underperforming products" | Products needing attention |
| "What is revenue by product type?" | Category performance |
| "Which products have the highest margins?" | Most profitable items |
| "Show me product performance by price tier" | Tier comparison |

#### Quality & Returns

| Question | What It Answers |
|----------|-----------------|
| "Which products have the highest return rates?" | Quality issues |
| "Show me returns by manufacturer" | Supplier quality |
| "What is our average return rate?" | Overall quality metric |
| "Which product categories have quality issues?" | Problem areas |

---

### Supplier Analytics

#### Supplier Performance

| Question | What It Answers |
|----------|-----------------|
| "Which suppliers have the highest revenue?" | Top suppliers by value |
| "Show me suppliers by performance score" | Vendor scorecards |
| "Which are our preferred suppliers?" | Strategic vendors |
| "How many inactive suppliers do we have?" | Vendor rationalization |
| "Show me supplier revenue by region" | Geographic supplier distribution |

#### Quality & Delivery

| Question | What It Answers |
|----------|-----------------|
| "Which suppliers have the best on-time delivery?" | Reliable vendors |
| "Show me suppliers with delivery issues" | Problem vendors |
| "Which suppliers have the highest return rates?" | Quality concerns |
| "What is the average supplier score by category?" | Category performance |
| "Show me suppliers with quality issues" | Vendors needing attention |

---

## Part 2: Trust & Governance Questions

### Contract Health & Compliance

#### Overall Health

| Question | What It Answers |
|----------|-----------------|
| "What is the overall health of our data contracts?" | System-wide contract status |
| "How many contracts are currently active?" | Active contract count |
| "Show me contracts by health status" | Health distribution |
| "Which contracts have critical issues?" | Priority attention needed |
| "What percentage of contracts are healthy?" | Overall compliance rate |

#### SLA Compliance

| Question | What It Answers |
|----------|-----------------|
| "Which contracts are violating SLA thresholds?" | SLA breaches |
| "What is our overall SLA compliance rate?" | Compliance percentage |
| "Show me freshness SLA violations" | Stale data issues |
| "Which contracts have completeness issues?" | Data gaps |
| "What is the SLA compliance trend over time?" | Improvement/degradation |

#### Quality Rules

| Question | What It Answers |
|----------|-----------------|
| "What is our overall quality score across contracts?" | Quality health |
| "Which contracts have failing quality rules?" | Quality issues |
| "Show me quality rule results by severity" | Error vs warning breakdown |
| "What is the quality score trend by week?" | Quality improvement tracking |
| "Which quality rules fail most frequently?" | Systematic issues |

---

### Data Governance

#### Tag Coverage

| Question | What It Answers |
|----------|-----------------|
| "What percentage of columns have governance tags?" | Tag completeness |
| "Which tables are missing classification tags?" | Governance gaps |
| "Show me PII tag coverage across contracts" | PII documentation |
| "Which contracts have incomplete tag coverage?" | Tagging priorities |
| "What is our AI_ALLOWED tag distribution?" | AI eligibility overview |

#### Data Classification

| Question | What It Answers |
|----------|-----------------|
| "How many columns are classified as CONFIDENTIAL?" | Sensitive data inventory |
| "Show me data classification distribution" | Classification breakdown |
| "Which tables contain HIGH PII?" | Sensitive data locations |
| "What percentage of data is AI-eligible?" | AI-ready data scope |
| "Show me RESTRICTED data locations" | Highly sensitive data map |

#### AI Eligibility

| Question | What It Answers |
|----------|-----------------|
| "Which semantic views are safe for AI consumption?" | AI-ready data products |
| "What data requires pseudonymization for AI?" | AI constraint requirements |
| "Show me the AI eligibility of customer data" | Customer data AI status |
| "Which contracts allow model training?" | Training data availability |
| "What PII data is blocked from AI?" | AI exclusions |

---

### Consumer & Lineage

#### Consumer Dependencies

| Question | What It Answers |
|----------|-----------------|
| "How many consumers depend on each contract?" | Dependency impact |
| "Which contracts have the most consumers?" | High-impact contracts |
| "Show me consumer teams by contract" | Stakeholder mapping |
| "Which contracts have no registered consumers?" | Orphan data |
| "What is the consumer access level distribution?" | Access patterns |

#### Data Lineage

| Question | What It Answers |
|----------|-----------------|
| "What is the lineage of the sales analytics view?" | Data flow tracing |
| "Which source systems feed into customer data?" | Source mapping |
| "Show me contracts that depend on TPCH data" | Downstream impact |
| "What tables does the customer dimension derive from?" | Transformation lineage |
| "How does data flow from RAW to SEMANTIC?" | Pipeline understanding |

---

### Alerts & Issues

#### Active Alerts

| Question | What It Answers |
|----------|-----------------|
| "What alerts are currently active?" | Current issues |
| "Show me critical alerts" | Priority issues |
| "Which contracts have warnings?" | Non-critical concerns |
| "What is the alert trend over time?" | Issue patterns |
| "How many alerts were resolved this week?" | Resolution velocity |

#### Breaking Changes

| Question | What It Answers |
|----------|-----------------|
| "Are there any pending breaking changes?" | Schema change risk |
| "Which breaking changes need approval?" | Pending decisions |
| "Show me breaking change history" | Change patterns |
| "Which consumers are impacted by pending changes?" | Impact assessment |
| "How long do breaking changes wait for approval?" | Process efficiency |

---

## Part 3: Combined Data + Trust Questions

These questions blend analytics with governance awareness:

| Question | What It Answers |
|----------|-----------------|
| "Show me revenue by region, but only from contracts with healthy SLAs" | Trusted revenue analysis |
| "Which high-value customers are in data with quality issues?" | Risk to customer insights |
| "What is the revenue from AI-eligible data sources?" | AI-monetizable data |
| "Show me top products from fully governed contracts" | Trusted product analytics |
| "Which market segments rely on contracts with SLA violations?" | Business impact of data issues |
| "What percentage of our analytics uses CONFIDENTIAL data?" | Sensitivity in reporting |
| "Which supplier insights come from validated quality data?" | Trustworthy vendor analysis |
| "Show me customer segments from pseudonymized data only" | AI-safe customer analytics |

---

## SQL Queries Behind the Questions

### Data Analytics Queries

```sql
-- Total revenue by region
SELECT REGION_NAME, SUM(NET_REVENUE) as revenue
FROM SEM_DEV.SEM_SALES.VW_SALES_ANALYTICS
GROUP BY REGION_NAME
ORDER BY revenue DESC;

-- Customers at risk of churning with high LTV
SELECT CUSTOMER_SEGMENT, REGION_NAME, 
       COUNT(*) as customers, 
       AVG(LIFETIME_VALUE) as avg_ltv
FROM SEM_DEV.SEM_CUSTOMER.VW_CUSTOMER_ANALYTICS
WHERE CUSTOMER_SEGMENT IN ('AT_RISK', 'HIGH_VALUE_AT_RISK')
GROUP BY CUSTOMER_SEGMENT, REGION_NAME
ORDER BY avg_ltv DESC;

-- Products with low stock but high sales
SELECT PART_NAME, MANUFACTURER, INVENTORY_STATUS, 
       INVENTORY_ON_HAND, TOTAL_QUANTITY_SOLD, GROSS_REVENUE
FROM SEM_DEV.SEM_PRODUCT.VW_PRODUCT_ANALYTICS
WHERE INVENTORY_STATUS = 'LOW_STOCK' 
  AND PERFORMANCE_TIER IN ('TOP_PERFORMER', 'STRONG_PERFORMER')
ORDER BY GROSS_REVENUE DESC;

-- Supplier on-time delivery performance
SELECT SUPPLIER_NAME, SUPPLIER_CATEGORY,
       100 - LATE_DELIVERY_RATE_PCT as on_time_rate,
       NET_REVENUE, SUPPLIER_SCORE
FROM SEM_DEV.SEM_SALES.VW_SUPPLIER_ANALYTICS
WHERE LINE_ITEM_COUNT > 0
ORDER BY on_time_rate DESC
LIMIT 10;
```

### Trust & Governance Queries

```sql
-- Contract health overview
SELECT CONTRACT_ID, OVERALL_HEALTH, QUALITY_SCORE, 
       FRESHNESS_STATUS, CONSUMER_COUNT
FROM GOVERNANCE.OBSERVABILITY.VW_CONTRACT_HEALTH_DASHBOARD
ORDER BY OVERALL_SCORE ASC;

-- Active SLA violations
SELECT CONTRACT_ID, ALERT_TYPE, ALERT_SEVERITY, 
       ALERT_MESSAGE, CREATED_AT
FROM GOVERNANCE.OBSERVABILITY.VW_ACTIVE_ALERTS
WHERE ALERT_SEVERITY IN ('CRITICAL', 'ERROR')
ORDER BY CREATED_AT DESC;

-- Tag coverage by contract
SELECT CONTRACT_ID, TOTAL_COLUMNS, TAGGED_COLUMNS,
       TAG_COVERAGE_PCT
FROM GOVERNANCE.OBSERVABILITY.VW_TAG_COVERAGE
ORDER BY TAG_COVERAGE_PCT ASC;

-- AI eligibility summary
SELECT 
    AI_ALLOWED_VALUE,
    COUNT(*) as column_count
FROM GOVERNANCE.CONTRACT_REGISTRY.COLUMN_TAGS
WHERE TAG_NAME = 'AI_ALLOWED'
GROUP BY AI_ALLOWED_VALUE;

-- Consumer dependencies by contract
SELECT c.CONTRACT_ID, c.CONTRACT_NAME,
       COUNT(cc.CONSUMER_TEAM) as consumer_count,
       LISTAGG(cc.CONSUMER_TEAM, ', ') as consumers
FROM GOVERNANCE.CONTRACT_REGISTRY.CONTRACTS c
LEFT JOIN GOVERNANCE.CONTRACT_REGISTRY.CONTRACT_CONSUMERS cc
    ON c.CONTRACT_ID = cc.CONTRACT_ID
GROUP BY c.CONTRACT_ID, c.CONTRACT_NAME
ORDER BY consumer_count DESC;
```

### Combined Queries

```sql
-- Revenue from healthy contracts only
SELECT 
    v.REGION_NAME,
    SUM(v.NET_REVENUE) as trusted_revenue
FROM SEM_DEV.SEM_SALES.VW_SALES_ANALYTICS v
JOIN GOVERNANCE.OBSERVABILITY.VW_CONTRACT_HEALTH_DASHBOARD h
    ON h.CONTRACT_ID = 'tpch_lineitem_v1'
WHERE h.OVERALL_HEALTH = 'HEALTHY'
GROUP BY v.REGION_NAME;

-- AI-eligible semantic models
SELECT MODEL_ID, MODEL_NAME, BASE_VIEW, AI_SAFE, DESCRIPTION
FROM SEM_DEV.SEM_SALES.VW_AVAILABLE_SEMANTIC_MODELS
WHERE AI_SAFE = TRUE;
```

---

## Using with Cortex Analyst

### Option 1: Streamlit App (Recommended)

Deploy the Streamlit app which uses the Cortex Analyst REST API:

```sql
-- Deploy the app
@sql/12_streamlit_app.sql

-- Upload app to stage
PUT file://streamlit/data_contracts_app.py @SEM_DEV.SEM_SALES.STREAMLIT_STAGE AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
```

Then access via **Projects → Streamlit → DATA_CONTRACTS_APP** and ask questions in natural language.

### Option 2: Direct REST API Call

```python
import requests

def ask_cortex_analyst(question, semantic_view):
    url = f"https://{host}/api/v2/cortex/analyst/message"
    body = {
        "messages": [{"role": "user", "content": [{"type": "text", "text": question}]}],
        "semantic_view": semantic_view
    }
    headers = {"Authorization": f'Snowflake Token="{token}"'}
    response = requests.post(url, json=body, headers=headers)
    return response.json()

# Example
result = ask_cortex_analyst("What was revenue by region?", "SEM_DEV.SEM_SALES.SALES_ANALYTICS")
```

### Option 3: Direct SQL with SEMANTIC_VIEW()

```sql
-- Query using SEMANTIC_VIEW() function
SELECT * FROM SEMANTIC_VIEW(
    SEM_DEV.SEM_SALES.SALES_ANALYTICS
    DIMENSIONS REGION_NAME
    METRICS total_revenue
);
```

---

## Question Categories Summary

| Category | Count | Focus |
|----------|-------|-------|
| Sales Analytics | 25+ | Revenue, discounts, delivery |
| Customer Analytics | 20+ | LTV, churn, RFM, segments |
| Product Analytics | 15+ | Inventory, margins, returns |
| Supplier Analytics | 12+ | Performance, quality, delivery |
| Contract Health | 12+ | SLAs, quality, compliance |
| Data Governance | 15+ | Tags, classification, AI |
| Consumer & Lineage | 10+ | Dependencies, data flow |
| Alerts & Issues | 8+ | Active problems, changes |
| Combined (Data+Trust) | 8+ | Trusted analytics |

**Total: 125+ proven sample questions**

# ============================================================================
# SNOWFLAKE NOTEBOOK: Upload Semantic Models to Stage
# ============================================================================
# Copy this entire cell into a Snowflake Notebook to upload semantic models.
# ============================================================================

# Import Snowpark and get the active session
from snowflake.snowpark.context import get_active_session
from snowflake.snowpark.types import StructType, StructField, StringType, IntegerType, DateType, DoubleType
import random
import uuid
from datetime import date, timedelta

# Get the active Notebook session
session = get_active_session()

# Configuration
STAGE_PATH = "@SEM_DEV.SEM_SALES.SEMANTIC_MODELS"

# Set context
session.sql("USE ROLE ACCOUNTADMIN").collect()
session.sql("USE DATABASE SEM_DEV").collect()
session.sql("USE SCHEMA SEM_SALES").collect()
session.sql("USE WAREHOUSE ANALYTICS_WH").collect()

print("Uploading semantic models to stage...")
print(f"Target: {STAGE_PATH}")
print()

# ─────────────────────────────────────────────────────────────────────────────
# SALES ANALYTICS MODEL
# ─────────────────────────────────────────────────────────────────────────────

sales_model = """
name: sales_analytics
description: Sales analytics semantic model for Cortex Analyst. Enables natural language queries on orders, products, customers, and suppliers.

tables:
  - name: VW_SALES_ANALYTICS
    description: Core sales analytics view with order line items and full dimensional context
    base_table:
      database: SEM_DEV
      schema: SEM_SALES
      table: VW_SALES_ANALYTICS
    
    dimensions:
      - name: order_date
        description: Date the order was placed
        expr: ORDER_DATE
        data_type: DATE
        
      - name: year
        description: Year of the order
        expr: YEAR
        data_type: NUMBER
        
      - name: region
        synonyms:
          - region_name
          - geographic region
        description: Geographic region
        expr: REGION_NAME
        data_type: VARCHAR
        
      - name: market_segment
        synonyms:
          - segment
        description: Customer market segment
        expr: MARKET_SEGMENT
        data_type: VARCHAR
        
    measures:
      - name: total_revenue
        synonyms:
          - revenue
          - sales
        description: Total gross revenue
        expr: SUM(GROSS_REVENUE)
        data_type: NUMBER
        
      - name: net_revenue
        description: Revenue after discounts
        expr: SUM(NET_REVENUE)
        data_type: NUMBER
        
      - name: order_count
        synonyms:
          - orders
          - number of orders
        description: Count of distinct orders
        expr: COUNT(DISTINCT ORDER_KEY)
        data_type: NUMBER

verifiedQueries:
  - name: revenue_by_region
    question: Show me revenue by region
    sql: |
      SELECT REGION_NAME, SUM(NET_REVENUE) as revenue
      FROM SEM_DEV.SEM_SALES.VW_SALES_ANALYTICS
      GROUP BY REGION_NAME
      ORDER BY revenue DESC
      
  - name: revenue_by_segment
    question: Which market segment has the highest sales?
    sql: |
      SELECT MARKET_SEGMENT, SUM(GROSS_REVENUE) as total_sales
      FROM SEM_DEV.SEM_SALES.VW_SALES_ANALYTICS
      GROUP BY MARKET_SEGMENT
      ORDER BY total_sales DESC
"""

# Write to stage using a temporary file approach via SQL
session.sql(f"""
CREATE OR REPLACE TEMPORARY STAGE _temp_upload;
""").collect()

# For Snowflake Notebooks, we'll insert the YAML as a file
# Using the COPY INTO with inline data
import tempfile
import os

# Create temp file and upload
with tempfile.NamedTemporaryFile(mode='w', suffix='.yaml', delete=False) as f:
    f.write(sales_model)
    temp_path = f.name

try:
    session.file.put(temp_path, STAGE_PATH, auto_compress=False, overwrite=True)
    print("✓ Uploaded sales_analytics_model.yaml")
except Exception as e:
    print(f"Note: Direct file upload may not work in all notebook environments: {e}")
    print("  Alternative: Use Snowsight UI to upload files manually")

os.unlink(temp_path)

# ─────────────────────────────────────────────────────────────────────────────
# List files in stage
# ─────────────────────────────────────────────────────────────────────────────

print()
print("Files in stage:")
files = session.sql(f"LIST {STAGE_PATH}").collect()
for row in files:
    print(f"  {row['name']}")

print()
print("=" * 60)
print("IMPORTANT: For full functionality, upload all YAML files from")
print("the semantic_models/ folder using Snowsight UI:")
print("  1. Go to Data → Databases → SEM_DEV → SEM_SALES → Stages")
print("  2. Click on SEMANTIC_MODELS stage")
print("  3. Click 'Upload Files' button")
print("  4. Select all .yaml files from semantic_models/ folder")
print("=" * 60)

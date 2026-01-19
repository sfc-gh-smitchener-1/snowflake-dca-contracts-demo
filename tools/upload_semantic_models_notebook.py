# ============================================================================
# SNOWFLAKE NOTEBOOK: Upload Semantic Models to Stage
# ============================================================================
# Copy this entire cell into a Snowflake Notebook to upload semantic models.
# The 'session' variable is automatically available in Snowflake Notebooks.
# ============================================================================
# Generate synthetic data with Snowpark (in-notebook, in-Snowflake) using Faker
from snowflake.snowpark.types import StructType, StructField, StringType, IntegerType, DateType, DoubleType
import random
import uuid
from datetime import date, timedelta

# Use the active Notebook session
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
description: Sales analytics semantic model for Cortex Analyst
tables:
  - name: VW_SALES_ANALYTICS
    description: Core sales analytics view with order line items and full dimensional context
    base_table: SEM_DEV.SEM_SALES.VW_SALES_ANALYTICS
    
    dimensions:
      - name: ORDER_DATE
        description: Date the order was placed
        expr: ORDER_DATE
        data_type: DATE
        
      - name: YEAR
        description: Year of the order
        expr: YEAR
        data_type: NUMBER
        
      - name: QUARTER
        description: Quarter of the order (Q1-Q4)
        expr: QUARTER
        data_type: VARCHAR
        
      - name: MONTH_NAME
        description: Month name of the order
        expr: MONTH_NAME
        data_type: VARCHAR
        
      - name: REGION_NAME
        description: Geographic region
        expr: REGION_NAME
        data_type: VARCHAR
        
      - name: NATION_NAME
        description: Country name
        expr: NATION_NAME
        data_type: VARCHAR
        
      - name: MARKET_SEGMENT
        description: Customer market segment
        expr: MARKET_SEGMENT
        data_type: VARCHAR
        
      - name: ORDER_PRIORITY
        description: Order priority level
        expr: ORDER_PRIORITY
        data_type: VARCHAR
        
      - name: SHIP_MODE
        description: Shipping mode
        expr: SHIP_MODE
        data_type: VARCHAR
        
      - name: PART_NAME
        description: Product name
        expr: PART_NAME
        data_type: VARCHAR
        
      - name: PART_TYPE
        description: Product type
        expr: PART_TYPE
        data_type: VARCHAR
        
      - name: BRAND
        description: Product brand
        expr: BRAND
        data_type: VARCHAR
        
    measures:
      - name: TOTAL_REVENUE
        description: Total gross revenue
        expr: SUM(EXTENDED_PRICE)
        data_type: NUMBER
        
      - name: NET_REVENUE
        description: Revenue after discounts
        expr: SUM(NET_REVENUE)
        data_type: NUMBER
        
      - name: TOTAL_ORDERS
        description: Count of distinct orders
        expr: COUNT(DISTINCT ORDER_KEY)
        data_type: NUMBER
        
      - name: TOTAL_ITEMS
        description: Count of line items
        expr: COUNT(*)
        data_type: NUMBER
        
      - name: AVG_DISCOUNT
        description: Average discount percentage
        expr: AVG(DISCOUNT_PERCENT)
        data_type: NUMBER
        
      - name: TOTAL_TAX
        description: Total tax collected
        expr: SUM(TAX_AMOUNT)
        data_type: NUMBER

    sample_questions:
      - What were the top 10 countries by revenue last year?
      - Show me monthly revenue trends for 2024
      - Which market segments have the highest average order value?
      - What is the revenue breakdown by region?
      - Which products have the highest profit margins?
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

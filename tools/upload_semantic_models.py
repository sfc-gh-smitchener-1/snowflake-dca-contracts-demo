#!/usr/bin/env python3
"""
Upload Semantic Models to Snowflake Stage
==========================================
This script uploads all semantic model YAML files to the Snowflake stage
so they can be used by Cortex Analyst.

Usage in Snowflake Notebook:
    # The session is automatically available as 'session'
    from upload_semantic_models import upload_semantic_models_notebook
    upload_semantic_models_notebook(session)

Usage from command line:
    python tools/upload_semantic_models.py

For command line usage, set environment variables:
    SNOWFLAKE_ACCOUNT, SNOWFLAKE_USER, SNOWFLAKE_PASSWORD
"""

import os
import sys
from pathlib import Path

# Configuration
STAGE_DATABASE = "SEM_DEV"
STAGE_SCHEMA = "SEM_SALES"
STAGE_NAME = "SEMANTIC_MODELS"
FULL_STAGE_PATH = f"@{STAGE_DATABASE}.{STAGE_SCHEMA}.{STAGE_NAME}"

# Determine the semantic models directory
# Works both when run as a script and in interactive environments
try:
    SEMANTIC_MODELS_DIR = Path(__file__).parent.parent / "semantic_models"
except NameError:
    # Running in interactive environment (Jupyter, Snowflake Notebook, etc.)
    SEMANTIC_MODELS_DIR = Path.cwd() / "semantic_models"
    if not SEMANTIC_MODELS_DIR.exists():
        SEMANTIC_MODELS_DIR = Path.cwd().parent / "semantic_models"


def upload_semantic_models_notebook(session, semantic_models_dir=None):
    """
    Upload semantic models using Snowflake Notebook's native session.
    
    Usage in Snowflake Notebook:
        # session is automatically available
        from upload_semantic_models import upload_semantic_models_notebook
        upload_semantic_models_notebook(session)
        
    Or inline:
        # Cell 1: Define the YAML content and upload
        yaml_content = '''
        name: sales_analytics_model
        ...
        '''
        session.sql(f"PUT file://... @STAGE").collect()
    
    Args:
        session: Snowpark session (automatically available in Snowflake Notebooks)
        semantic_models_dir: Optional path to semantic models directory
    """
    models_dir = Path(semantic_models_dir) if semantic_models_dir else SEMANTIC_MODELS_DIR
    
    print("=" * 60)
    print("Uploading Semantic Models to Snowflake Stage")
    print("=" * 60)
    print(f"Stage: {FULL_STAGE_PATH}")
    print(f"Source: {models_dir}")
    print()
    
    # Check if directory exists
    if not models_dir.exists():
        print(f"⚠ Directory not found: {models_dir}")
        print()
        print("For Snowflake Notebooks, use the inline upload method instead.")
        print("See the upload_models_inline() function below.")
        return False
    
    # Get YAML files
    yaml_files = list(models_dir.glob("*.yaml")) + list(models_dir.glob("*.yml"))
    
    if not yaml_files:
        print(f"No YAML files found in {models_dir}")
        return False
    
    print(f"Found {len(yaml_files)} semantic model files:")
    for f in yaml_files:
        print(f"  - {f.name}")
    print()
    
    # Set context
    session.sql(f"USE DATABASE {STAGE_DATABASE}").collect()
    session.sql(f"USE SCHEMA {STAGE_SCHEMA}").collect()
    
    # Upload each file
    uploaded = 0
    failed = 0
    
    for yaml_file in yaml_files:
        try:
            put_cmd = f"PUT 'file://{yaml_file.absolute()}' @{STAGE_NAME} AUTO_COMPRESS=FALSE OVERWRITE=TRUE"
            print(f"Uploading {yaml_file.name}...")
            result = session.sql(put_cmd).collect()
            print(f"  ✓ Done")
            uploaded += 1
        except Exception as e:
            print(f"  ✗ Failed: {e}")
            failed += 1
    
    print()
    print(f"Complete: {uploaded} uploaded, {failed} failed")
    
    # List files in stage
    print()
    print("Files in stage:")
    files = session.sql(f"LIST @{STAGE_NAME}").collect()
    for row in files:
        print(f"  {row['name']}")
    
    return failed == 0


def upload_models_inline(session):
    """
    Upload semantic models by writing YAML content directly.
    Use this method when file system access is not available.
    
    Usage in Snowflake Notebook:
        upload_models_inline(session)
    """
    print("=" * 60)
    print("Uploading Semantic Models (Inline Method)")
    print("=" * 60)
    print()
    
    # The semantic model YAML files should be read and embedded here
    # For Snowflake Notebooks, copy the YAML content directly
    
    models = {
        'sales_analytics_model.yaml': '''# Copy content from semantic_models/sales_analytics_model.yaml''',
        'customer_analytics_model.yaml': '''# Copy content from semantic_models/customer_analytics_model.yaml''',
        'product_analytics_model.yaml': '''# Copy content from semantic_models/product_analytics_model.yaml''',
        'supplier_analytics_model.yaml': '''# Copy content from semantic_models/supplier_analytics_model.yaml''',
        'governance_analytics_model.yaml': '''# Copy content from semantic_models/governance_analytics_model.yaml''',
    }
    
    print("This function requires you to embed the YAML content.")
    print("Edit this function and replace the placeholder content with actual YAML.")
    print()
    print("Alternative: Upload files manually via Snowsight UI:")
    print("  1. Go to Data → Databases → SEM_DEV → SEM_SALES → Stages → SEMANTIC_MODELS")
    print("  2. Click 'Upload Files'")
    print("  3. Select YAML files from the semantic_models/ folder")
    print()
    
    return False


# ─────────────────────────────────────────────────────────────────────────────
# Command-line support (for running outside Snowflake Notebooks)
# ─────────────────────────────────────────────────────────────────────────────

def get_connector_session():
    """Create connection using snowflake-connector-python for CLI usage."""
    try:
        import snowflake.connector
    except ImportError:
        print("Error: snowflake-connector-python required for CLI usage")
        print("Install with: pip install snowflake-connector-python")
        sys.exit(1)
    
    return snowflake.connector.connect(
        account=os.environ.get("SNOWFLAKE_ACCOUNT"),
        user=os.environ.get("SNOWFLAKE_USER"),
        password=os.environ.get("SNOWFLAKE_PASSWORD"),
        warehouse=os.environ.get("SNOWFLAKE_WAREHOUSE", "ANALYTICS_WH"),
        role=os.environ.get("SNOWFLAKE_ROLE", "ACCOUNTADMIN"),
        database=STAGE_DATABASE,
        schema=STAGE_SCHEMA,
    )


class ConnectorSessionWrapper:
    """Wrapper to make snowflake-connector work like Snowpark session."""
    def __init__(self, conn):
        self.conn = conn
        self.cursor = conn.cursor()
    
    def sql(self, query):
        self.cursor.execute(query)
        return self
    
    def collect(self):
        return self.cursor.fetchall()
    
    def close(self):
        self.cursor.close()
        self.conn.close()


def main():
    """Main entry point for command-line usage."""
    print("=" * 60)
    print("Semantic Model Upload Tool (CLI Mode)")
    print("=" * 60)
    print()
    
    # Check for required env vars
    required = ["SNOWFLAKE_ACCOUNT", "SNOWFLAKE_USER", "SNOWFLAKE_PASSWORD"]
    missing = [v for v in required if not os.environ.get(v)]
    
    if missing:
        print("Missing environment variables:")
        for v in missing:
            print(f"  - {v}")
        print()
        print("Set these before running, or use Snowflake Notebook instead.")
        sys.exit(1)
    
    # Connect and upload
    print("Connecting to Snowflake...")
    try:
        conn = get_connector_session()
        session = ConnectorSessionWrapper(conn)
        print("Connected!")
        print()
    except Exception as e:
        print(f"Connection failed: {e}")
        sys.exit(1)
    
    success = upload_semantic_models_notebook(session)
    session.close()
    
    if success:
        print()
        print("=" * 60)
        print("SUCCESS: Semantic models uploaded!")
        print("=" * 60)
    else:
        print()
        print("WARNING: Some uploads failed")
        sys.exit(1)


if __name__ == "__main__":
    main()

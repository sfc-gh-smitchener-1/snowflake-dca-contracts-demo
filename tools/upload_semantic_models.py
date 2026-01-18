#!/usr/bin/env python3
"""
Upload Semantic Models to Snowflake Stage
==========================================
This script uploads all semantic model YAML files to the Snowflake stage
so they can be used by Cortex Analyst.

Usage:
    python tools/upload_semantic_models.py

Environment variables required:
    SNOWFLAKE_ACCOUNT   - Your Snowflake account identifier
    SNOWFLAKE_USER      - Your Snowflake username
    SNOWFLAKE_PASSWORD  - Your Snowflake password (or use key-pair auth)
    SNOWFLAKE_WAREHOUSE - Warehouse to use (default: ANALYTICS_WH)
    SNOWFLAKE_ROLE      - Role to use (default: ACCOUNTADMIN)

Or use a config file at ~/.snowflake/config.toml
"""

import os
import sys
from pathlib import Path

try:
    import snowflake.connector
except ImportError:
    print("Error: snowflake-connector-python is required")
    print("Install with: pip install snowflake-connector-python")
    sys.exit(1)


# Configuration
STAGE_DATABASE = "SEM_DEV"
STAGE_SCHEMA = "SEM_SALES"
STAGE_NAME = "SEMANTIC_MODELS"
SEMANTIC_MODELS_DIR = Path(__file__).parent.parent / "semantic_models"


def get_connection():
    """Create Snowflake connection from environment variables."""
    return snowflake.connector.connect(
        account=os.environ.get("SNOWFLAKE_ACCOUNT"),
        user=os.environ.get("SNOWFLAKE_USER"),
        password=os.environ.get("SNOWFLAKE_PASSWORD"),
        warehouse=os.environ.get("SNOWFLAKE_WAREHOUSE", "ANALYTICS_WH"),
        role=os.environ.get("SNOWFLAKE_ROLE", "ACCOUNTADMIN"),
        database=STAGE_DATABASE,
        schema=STAGE_SCHEMA,
    )


def upload_semantic_models():
    """Upload all YAML files from semantic_models directory to Snowflake stage."""
    
    # Check if directory exists
    if not SEMANTIC_MODELS_DIR.exists():
        print(f"Error: Semantic models directory not found: {SEMANTIC_MODELS_DIR}")
        sys.exit(1)
    
    # Get all YAML files
    yaml_files = list(SEMANTIC_MODELS_DIR.glob("*.yaml")) + list(SEMANTIC_MODELS_DIR.glob("*.yml"))
    
    if not yaml_files:
        print(f"No YAML files found in {SEMANTIC_MODELS_DIR}")
        sys.exit(1)
    
    print(f"Found {len(yaml_files)} semantic model files to upload:")
    for f in yaml_files:
        print(f"  - {f.name}")
    print()
    
    # Connect to Snowflake
    print("Connecting to Snowflake...")
    try:
        conn = get_connection()
        cursor = conn.cursor()
        print(f"Connected to {STAGE_DATABASE}.{STAGE_SCHEMA}")
        print()
    except Exception as e:
        print(f"Error connecting to Snowflake: {e}")
        print()
        print("Make sure these environment variables are set:")
        print("  SNOWFLAKE_ACCOUNT")
        print("  SNOWFLAKE_USER")
        print("  SNOWFLAKE_PASSWORD")
        sys.exit(1)
    
    # Upload each file
    uploaded = 0
    failed = 0
    
    for yaml_file in yaml_files:
        try:
            # Use PUT command to upload
            put_command = f"""
                PUT 'file://{yaml_file.absolute()}' 
                @{STAGE_NAME} 
                AUTO_COMPRESS=FALSE 
                OVERWRITE=TRUE
            """
            print(f"Uploading {yaml_file.name}...")
            cursor.execute(put_command)
            result = cursor.fetchone()
            print(f"  ✓ Uploaded: {result}")
            uploaded += 1
        except Exception as e:
            print(f"  ✗ Failed: {e}")
            failed += 1
    
    print()
    print(f"Upload complete: {uploaded} succeeded, {failed} failed")
    print()
    
    # List files in stage
    print("Files in stage:")
    cursor.execute(f"LIST @{STAGE_NAME}")
    for row in cursor.fetchall():
        print(f"  {row[0]} ({row[1]} bytes)")
    
    # Clean up
    cursor.close()
    conn.close()
    
    return failed == 0


def main():
    """Main entry point."""
    print("=" * 60)
    print("Semantic Model Upload Tool")
    print("=" * 60)
    print()
    
    success = upload_semantic_models()
    
    if success:
        print()
        print("=" * 60)
        print("SUCCESS: All semantic models uploaded to Snowflake stage")
        print("=" * 60)
        print()
        print("You can now use Cortex Analyst with these models.")
        print("Example query in Snowflake:")
        print()
        print("  SELECT SNOWFLAKE.CORTEX.COMPLETE(")
        print("    'snowflake-arctic',")
        print("    'What were the top 5 customers by revenue last quarter?',")
        print("    semantic_model_file => '@SEM_DEV.SEM_SALES.SEMANTIC_MODELS/sales_analytics_model.yaml'")
        print("  );")
        print()
    else:
        print()
        print("WARNING: Some files failed to upload")
        sys.exit(1)


if __name__ == "__main__":
    main()

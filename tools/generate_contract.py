#!/usr/bin/env python3
"""
Generic Contract Generator
==========================
This script generates data contracts by reading schema from:
1. Existing Snowflake tables
2. JSON/Parquet/CSV files
3. API schema definitions

Usage:
    python generate_contract.py --source snowflake --table DATABASE.SCHEMA.TABLE
    python generate_contract.py --source file --path /path/to/data.csv
    python generate_contract.py --source schema --path /path/to/schema.json
"""

import argparse
import json
import yaml
import hashlib
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Any
import re

ROOT = Path(__file__).resolve().parents[1]  # Project root


class ContractGenerator:
    """Generate data contracts from various sources."""
    
    # Default tag mappings based on column patterns
    PII_PATTERNS = {
        'HIGH': [
            r'.*ssn.*', r'.*social_security.*', r'.*tax_id.*', r'.*passport.*',
            r'.*driver.*license.*', r'.*credit_card.*', r'.*bank_account.*'
        ],
        'MODERATE': [
            r'.*email.*', r'.*phone.*', r'.*address.*', r'.*name.*(?!key)',
            r'.*dob.*', r'.*birth.*date.*', r'.*salary.*', r'.*income.*'
        ],
        'LOW': [
            r'.*ip_address.*', r'.*device_id.*', r'.*user_agent.*',
            r'.*location.*', r'.*zip.*', r'.*postal.*'
        ]
    }
    
    CONFIDENTIAL_PATTERNS = [
        r'.*price.*', r'.*cost.*', r'.*revenue.*', r'.*profit.*',
        r'.*balance.*', r'.*amount.*', r'.*salary.*', r'.*wage.*'
    ]
    
    def __init__(self, producer_team: str = "Data Engineering", 
                 producer_email: str = "data-eng@company.com"):
        self.producer_team = producer_team
        self.producer_email = producer_email
        
    def infer_pii_type(self, column_name: str) -> str:
        """Infer PII type from column name patterns."""
        col_lower = column_name.lower()
        
        for pii_level, patterns in self.PII_PATTERNS.items():
            for pattern in patterns:
                if re.match(pattern, col_lower):
                    return pii_level
        return 'NONE'
    
    def infer_classification(self, column_name: str, pii_type: str) -> str:
        """Infer data classification from column name and PII type."""
        col_lower = column_name.lower()
        
        if pii_type in ['HIGH', 'MODERATE']:
            return 'CONFIDENTIAL'
        
        for pattern in self.CONFIDENTIAL_PATTERNS:
            if re.match(pattern, col_lower):
                return 'CONFIDENTIAL'
        
        # Check for ID/key columns - usually internal
        if any(x in col_lower for x in ['_id', '_key', 'key_', 'id_']):
            return 'INTERNAL'
            
        return 'INTERNAL'
    
    def infer_ai_allowed(self, pii_type: str, classification: str) -> str:
        """Infer AI eligibility based on PII and classification."""
        if pii_type == 'HIGH':
            return 'FALSE'
        elif pii_type == 'MODERATE':
            return 'PSEUDONYMIZED_ONLY'
        elif classification == 'RESTRICTED':
            return 'FALSE'
        return 'TRUE'
    
    def map_snowflake_type(self, sf_type: str) -> str:
        """Map Snowflake internal types to standard types."""
        sf_type = sf_type.upper()
        
        # Handle parameterized types
        if 'VARCHAR' in sf_type or 'TEXT' in sf_type or 'STRING' in sf_type:
            return 'VARCHAR'
        elif 'NUMBER' in sf_type or 'DECIMAL' in sf_type or 'NUMERIC' in sf_type:
            return sf_type if '(' in sf_type else 'NUMBER(38,0)'
        elif 'INT' in sf_type:
            return 'NUMBER(38,0)'
        elif 'FLOAT' in sf_type or 'DOUBLE' in sf_type or 'REAL' in sf_type:
            return 'FLOAT'
        elif 'TIMESTAMP' in sf_type:
            return 'TIMESTAMP_NTZ'
        elif 'DATE' in sf_type:
            return 'DATE'
        elif 'BOOLEAN' in sf_type:
            return 'BOOLEAN'
        elif 'VARIANT' in sf_type:
            return 'VARIANT'
        elif 'ARRAY' in sf_type:
            return 'ARRAY'
        elif 'OBJECT' in sf_type:
            return 'OBJECT'
        else:
            return sf_type
    
    def generate_contract_id(self, table_name: str, system: str = "custom") -> str:
        """Generate a contract ID from table name."""
        # Clean the table name
        clean_name = re.sub(r'[^a-zA-Z0-9_]', '_', table_name.lower())
        clean_name = re.sub(r'_+', '_', clean_name)
        clean_name = clean_name.strip('_')
        
        return f"{system}_{clean_name}_v1"
    
    def generate_column_definition(self, column: Dict[str, Any]) -> Dict:
        """Generate a column definition with inferred tags."""
        col_name = column['name'].upper()
        col_type = self.map_snowflake_type(column.get('type', 'VARCHAR'))
        is_nullable = column.get('nullable', True)
        description = column.get('description', f"Column {col_name}")
        
        # Check if this is a system column
        is_system = col_name.startswith('_')
        
        # Infer tags
        pii_type = 'NONE' if is_system else self.infer_pii_type(col_name)
        classification = 'INTERNAL' if is_system else self.infer_classification(col_name, pii_type)
        ai_allowed = 'TRUE' if is_system else self.infer_ai_allowed(pii_type, classification)
        
        col_def = {
            'name': col_name,
            'type': col_type,
            'description': description,
            'constraints': [] if is_nullable else ['not_null']
        }
        
        if is_system:
            col_def['system_managed'] = True
        else:
            col_def['tags'] = {
                'DATA_CLASSIFICATION': classification,
                'PII_TYPE': pii_type,
                'AI_ALLOWED': ai_allowed
            }
            
            # Add residency for PII columns
            if pii_type in ['MODERATE', 'HIGH']:
                col_def['tags']['RESIDENCY_REGION'] = 'ORIGIN'
        
        return col_def
    
    def generate_quality_rules(self, columns: List[Dict], 
                               primary_key: Optional[str] = None) -> List[Dict]:
        """Generate default quality rules based on schema."""
        rules = []
        rule_id = 1
        
        # Primary key rule
        if primary_key:
            rules.append({
                'id': f'qr_{rule_id:03d}',
                'name': 'valid_primary_key',
                'type': 'column_check',
                'column': primary_key.upper(),
                'sql': f'{primary_key.upper()} IS NOT NULL',
                'severity': 'error'
            })
            rule_id += 1
            
            rules.append({
                'id': f'qr_{rule_id:03d}',
                'name': 'no_duplicate_keys',
                'type': 'table_check',
                'sql': f'COUNT(*) = COUNT(DISTINCT {primary_key.upper()})',
                'severity': 'error'
            })
            rule_id += 1
        
        # Add rules for specific column types
        for col in columns:
            col_name = col['name'].upper()
            col_type = col.get('type', '').upper()
            
            # Date columns shouldn't be in the future
            if 'DATE' in col_type or 'TIMESTAMP' in col_type:
                if any(x in col_name.lower() for x in ['created', 'updated', 'modified']):
                    rules.append({
                        'id': f'qr_{rule_id:03d}',
                        'name': f'{col_name.lower()}_not_future',
                        'type': 'column_check',
                        'column': col_name,
                        'sql': f'{col_name} <= CURRENT_TIMESTAMP()',
                        'severity': 'warning'
                    })
                    rule_id += 1
            
            # Email validation
            if 'email' in col_name.lower():
                rules.append({
                    'id': f'qr_{rule_id:03d}',
                    'name': f'valid_{col_name.lower()}_format',
                    'type': 'column_check',
                    'column': col_name,
                    'sql': f"{col_name} REGEXP '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{{2,}}$'",
                    'severity': 'warning'
                })
                rule_id += 1
        
        return rules
    
    def generate_contract(self, 
                         schema_info: Dict,
                         system_name: str = "CUSTOM",
                         contract_id: Optional[str] = None,
                         sla_freshness_minutes: int = 60) -> Dict:
        """Generate a complete data contract from schema information."""
        
        database = schema_info.get('database', 'RAW_${ENV}')
        schema = schema_info.get('schema', 'RAW_DATA')
        table = schema_info.get('table', 'TABLE_RAW')
        columns = schema_info.get('columns', [])
        primary_key = schema_info.get('primary_key')
        
        if not contract_id:
            contract_id = self.generate_contract_id(table, system_name.lower())
        
        # Process columns
        column_definitions = [
            self.generate_column_definition(col) for col in columns
        ]
        
        # Add system columns if not present
        system_cols = ['_LOADED_AT', '_SOURCE_FILE', '_ROW_HASH', '_IS_CURRENT']
        existing_cols = {c['name'] for c in column_definitions}
        
        for sys_col in system_cols:
            if sys_col not in existing_cols:
                if sys_col == '_LOADED_AT':
                    column_definitions.append({
                        'name': '_LOADED_AT',
                        'type': 'TIMESTAMP_NTZ',
                        'description': 'Snowflake ingestion timestamp',
                        'constraints': ['not_null'],
                        'system_managed': True
                    })
                elif sys_col == '_SOURCE_FILE':
                    column_definitions.append({
                        'name': '_SOURCE_FILE',
                        'type': 'VARCHAR(1024)',
                        'description': 'Source file or batch identifier',
                        'system_managed': True
                    })
                elif sys_col == '_ROW_HASH':
                    column_definitions.append({
                        'name': '_ROW_HASH',
                        'type': 'VARCHAR(64)',
                        'description': 'SHA256 hash of business columns for change detection',
                        'system_managed': True
                    })
                elif sys_col == '_IS_CURRENT':
                    column_definitions.append({
                        'name': '_IS_CURRENT',
                        'type': 'BOOLEAN',
                        'description': 'Flag indicating if this is the current record version',
                        'system_managed': True
                    })
        
        # Generate quality rules
        quality_rules = self.generate_quality_rules(columns, primary_key)
        
        # Determine overall classification
        classifications = [c.get('tags', {}).get('DATA_CLASSIFICATION', 'INTERNAL') 
                          for c in column_definitions if 'tags' in c]
        if 'RESTRICTED' in classifications:
            overall_classification = 'RESTRICTED'
        elif 'CONFIDENTIAL' in classifications:
            overall_classification = 'CONFIDENTIAL'
        else:
            overall_classification = 'INTERNAL'
        
        # Determine AI eligibility
        ai_values = [c.get('tags', {}).get('AI_ALLOWED', 'TRUE') 
                    for c in column_definitions if 'tags' in c]
        if 'FALSE' in ai_values:
            ai_eligibility = 'FALSE'
        elif 'PSEUDONYMIZED_ONLY' in ai_values:
            ai_eligibility = 'PSEUDONYMIZED_ONLY'
        else:
            ai_eligibility = 'TRUE'
        
        # Build the contract
        contract = {
            'contract': {
                'id': contract_id,
                'version': '1.0.0',
                'status': 'draft',
                'producer': {
                    'system': system_name,
                    'team': self.producer_team,
                    'owner': self.producer_email,
                    'slack_channel': '#data-contracts'
                },
                'schema': {
                    'database': database,
                    'schema': schema,
                    'table': table,
                    'columns': column_definitions
                },
                'sla': {
                    'freshness': {
                        'max_age_minutes': sla_freshness_minutes,
                        'measurement': 'MAX(_LOADED_AT) vs CURRENT_TIMESTAMP()'
                    },
                    'completeness': {
                        'threshold_percent': 99.0,
                        'critical_columns': [primary_key.upper()] if primary_key else []
                    },
                    'availability': {
                        'uptime_percent': 99.9,
                        'maintenance_window': 'Sunday 02:00-04:00 UTC'
                    },
                    'volume': {
                        'expected_daily_rows': {
                            'min': 1000,
                            'max': 1000000
                        },
                        'alert_on_variance_percent': 25
                    }
                },
                'quality_rules': quality_rules,
                'governance': {
                    'classification': overall_classification,
                    'residency_requirements': [],
                    'retention_days': 2555,
                    'ai_eligibility': ai_eligibility
                },
                'lineage': {
                    'source_systems': [{
                        'name': system_name,
                        'connection': f'{system_name}_CONNECTION',
                        'extraction': 'DIRECT_LOAD'
                    }],
                    'downstream_dependencies': []
                },
                'consumers': []
            }
        }
        
        return contract
    
    def generate_from_snowflake_describe(self, describe_output: List[Dict],
                                         database: str,
                                         schema: str,
                                         table: str,
                                         system_name: str = "SNOWFLAKE") -> Dict:
        """Generate contract from Snowflake DESCRIBE TABLE output."""
        columns = []
        primary_key = None
        
        for row in describe_output:
            col_name = row.get('name', row.get('COLUMN_NAME', ''))
            col_type = row.get('type', row.get('DATA_TYPE', 'VARCHAR'))
            nullable = row.get('null?', row.get('IS_NULLABLE', 'YES')) == 'YES'
            is_pk = row.get('primary key', row.get('IS_PRIMARY', 'N')) == 'Y'
            
            if is_pk:
                primary_key = col_name
            
            columns.append({
                'name': col_name,
                'type': col_type,
                'nullable': nullable,
                'description': row.get('comment', f'Column {col_name}')
            })
        
        schema_info = {
            'database': database,
            'schema': schema,
            'table': table,
            'columns': columns,
            'primary_key': primary_key
        }
        
        return self.generate_contract(schema_info, system_name)
    
    def save_contract(self, contract: Dict, output_path: str):
        """Save contract to YAML file."""
        with open(output_path, 'w') as f:
            yaml.dump(contract, f, default_flow_style=False, sort_keys=False, 
                     allow_unicode=True, width=120)
        print(f"Contract saved to: {output_path}")


def generate_snowflake_sql(database: str, schema: str, table: str) -> str:
    """Generate SQL to describe a Snowflake table for contract generation."""
    return f"""
-- Run this in Snowflake to get schema information for contract generation
SELECT 
    COLUMN_NAME as name,
    DATA_TYPE as type,
    IS_NULLABLE as "null?",
    COMMENT as comment,
    CASE WHEN COLUMN_NAME IN (
        SELECT COLUMN_NAME 
        FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS tc
        JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE kcu 
            ON tc.CONSTRAINT_NAME = kcu.CONSTRAINT_NAME
        WHERE tc.TABLE_CATALOG = '{database}'
          AND tc.TABLE_SCHEMA = '{schema}'
          AND tc.TABLE_NAME = '{table}'
          AND tc.CONSTRAINT_TYPE = 'PRIMARY KEY'
    ) THEN 'Y' ELSE 'N' END as "primary key"
FROM {database}.INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_CATALOG = '{database}'
  AND TABLE_SCHEMA = '{schema}'
  AND TABLE_NAME = '{table}'
ORDER BY ORDINAL_POSITION;
"""


def main():
    parser = argparse.ArgumentParser(
        description='Generate data contracts from various sources'
    )
    parser.add_argument('--source', choices=['snowflake', 'file', 'schema', 'sql'],
                       default='sql', help='Source type for schema information')
    parser.add_argument('--database', help='Database name')
    parser.add_argument('--schema', help='Schema name')
    parser.add_argument('--table', help='Table name')
    parser.add_argument('--system', default='CUSTOM', help='Source system name')
    parser.add_argument('--team', default='Data Engineering', help='Producer team name')
    parser.add_argument('--email', default='data-eng@company.com', help='Producer email')
    parser.add_argument('--output', help='Output file path')
    parser.add_argument('--freshness', type=int, default=60, 
                       help='SLA freshness in minutes')
    
    args = parser.parse_args()
    
    generator = ContractGenerator(
        producer_team=args.team,
        producer_email=args.email
    )
    
    if args.source == 'sql':
        # Generate helper SQL
        if args.database and args.schema and args.table:
            print("Run this SQL in Snowflake to get schema information:")
            print(generate_snowflake_sql(args.database, args.schema, args.table))
            print("\nThen use the JSON output with --source schema --path <json_file>")
        else:
            print("Please provide --database, --schema, and --table for SQL generation")
    
    elif args.source == 'schema':
        # Generate from JSON schema file
        if args.path:
            with open(args.path) as f:
                schema_info = json.load(f)
            contract = generator.generate_contract(schema_info, args.system)
            
            output_path = args.output or f"{ROOT}/contracts/data/{contract['contract']['id']}.yml"
            generator.save_contract(contract, output_path)
    
    else:
        print(f"Source '{args.source}' not yet implemented")
        print("Use --source sql to generate helper SQL for Snowflake tables")


if __name__ == '__main__':
    main()

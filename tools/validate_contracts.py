#!/usr/bin/env python3
"""
Data Contract Validation Tool
Validates contract YAML files against schema and governance requirements.
"""

import json
import sys
from pathlib import Path
from typing import Any

import yaml

try:
    from jsonschema import Draft7Validator, ValidationError
    HAS_JSONSCHEMA = True
except ImportError:
    HAS_JSONSCHEMA = False

ROOT = Path(__file__).resolve().parents[1]  # Project root

# Required tags for all columns (governance compliance)
REQUIRED_COLUMN_TAGS = ["DATA_CLASSIFICATION", "PII_TYPE", "AI_ALLOWED"]

# Valid tag values
VALID_TAG_VALUES = {
    "DATA_CLASSIFICATION": ["PUBLIC", "INTERNAL", "CONFIDENTIAL", "RESTRICTED"],
    "PII_TYPE": ["NONE", "LOW", "MODERATE", "HIGH"],
    "AI_ALLOWED": ["TRUE", "FALSE", "PSEUDONYMIZED_ONLY", "AGGREGATED_ONLY"],
    "RESIDENCY_REGION": ["GLOBAL", "ORIGIN", "EU_ONLY", "US_ONLY"],
}


def get_nested(d: dict, path: str) -> Any:
    """Get a nested value from a dict using dot notation."""
    cur = d
    for p in path.split("."):
        if not isinstance(cur, dict) or p not in cur:
            return None
        cur = cur[p]
    return cur


def validate_required_fields(doc: dict, required: list[tuple[str, type]], label: str) -> list[str]:
    """Validate that required fields exist and have correct types."""
    errors: list[str] = []
    for path, typ in required:
        val = get_nested(doc, path)
        if val is None:
            errors.append(f"{label}: missing required field '{path}'")
        elif not isinstance(val, typ):
            errors.append(f"{label}: field '{path}' should be {typ.__name__}, got {type(val).__name__}")
    return errors


def validate_column_tags(doc: dict, label: str) -> list[str]:
    """Validate that all columns have required governance tags."""
    errors: list[str] = []
    
    schema = doc.get("contract", {}).get("schema", {})
    columns = schema.get("columns", [])
    
    for col in columns:
        col_name = col.get("name", "UNKNOWN")
        
        # Skip system-managed columns
        if col.get("system_managed", False):
            continue
            
        tags = col.get("tags", {})
        
        # Check required tags
        for required_tag in REQUIRED_COLUMN_TAGS:
            if required_tag not in tags:
                errors.append(f"{label}: column '{col_name}' missing required tag '{required_tag}'")
            else:
                # Validate tag value
                tag_value = str(tags[required_tag]).upper()
                valid_values = VALID_TAG_VALUES.get(required_tag, [])
                if valid_values and tag_value not in valid_values:
                    errors.append(
                        f"{label}: column '{col_name}' has invalid value '{tags[required_tag]}' "
                        f"for tag '{required_tag}'. Valid values: {valid_values}"
                    )
        
        # Check PII columns have residency
        pii_type = str(tags.get("PII_TYPE", "NONE")).upper()
        if pii_type in ["MODERATE", "HIGH"] and "RESIDENCY_REGION" not in tags:
            errors.append(
                f"{label}: column '{col_name}' with PII_TYPE={pii_type} should have RESIDENCY_REGION tag"
            )
        
        # Check AI constraints for PII
        ai_allowed = str(tags.get("AI_ALLOWED", "FALSE")).upper()
        if pii_type in ["MODERATE", "HIGH"] and ai_allowed == "TRUE":
            errors.append(
                f"{label}: column '{col_name}' with PII_TYPE={pii_type} should not have AI_ALLOWED=TRUE. "
                f"Consider PSEUDONYMIZED_ONLY or FALSE"
            )
    
    return errors


def validate_sla(doc: dict, label: str) -> list[str]:
    """Validate SLA configuration."""
    errors: list[str] = []
    
    sla = doc.get("contract", {}).get("sla", {})
    
    # Freshness
    freshness = sla.get("freshness", {})
    max_age = freshness.get("max_age_minutes")
    if max_age is not None and (not isinstance(max_age, int) or max_age < 1):
        errors.append(f"{label}: sla.freshness.max_age_minutes must be a positive integer")
    
    # Completeness
    completeness = sla.get("completeness", {})
    threshold = completeness.get("threshold_percent")
    if threshold is not None and (not isinstance(threshold, (int, float)) or threshold < 0 or threshold > 100):
        errors.append(f"{label}: sla.completeness.threshold_percent must be between 0 and 100")
    
    return errors


def validate_quality_rules(doc: dict, label: str) -> list[str]:
    """Validate quality rule definitions."""
    errors: list[str] = []
    
    rules = doc.get("contract", {}).get("quality_rules", [])
    rule_ids = set()
    
    for rule in rules:
        rule_id = rule.get("id")
        
        # Check for duplicate IDs
        if rule_id in rule_ids:
            errors.append(f"{label}: duplicate quality rule ID '{rule_id}'")
        rule_ids.add(rule_id)
        
        # Check required fields
        if not rule.get("name"):
            errors.append(f"{label}: quality rule '{rule_id}' missing 'name'")
        if not rule.get("sql"):
            errors.append(f"{label}: quality rule '{rule_id}' missing 'sql'")
        if not rule.get("severity"):
            errors.append(f"{label}: quality rule '{rule_id}' missing 'severity'")
        elif rule.get("severity") not in ["error", "warning", "info"]:
            errors.append(f"{label}: quality rule '{rule_id}' has invalid severity")
    
    return errors


def validate_data_contract(filepath: Path) -> list[str]:
    """Validate a data contract file."""
    errors: list[str] = []
    label = filepath.name
    
    try:
        doc = yaml.safe_load(filepath.read_text()) or {}
    except yaml.YAMLError as e:
        return [f"{label}: Invalid YAML: {e}"]
    
    # Check it's a data contract (not product)
    if "contract" not in doc:
        return [f"{label}: Not a valid data contract (missing 'contract' key)"]
    
    # Required fields
    required = [
        ("contract.id", str),
        ("contract.version", str),
        ("contract.producer", dict),
        ("contract.producer.team", str),
        ("contract.producer.owner", str),
        ("contract.schema", dict),
        ("contract.schema.table", str),
        ("contract.sla", dict),
        ("contract.governance", dict),
    ]
    errors.extend(validate_required_fields(doc, required, label))
    
    # Column tags
    errors.extend(validate_column_tags(doc, label))
    
    # SLA validation
    errors.extend(validate_sla(doc, label))
    
    # Quality rules
    errors.extend(validate_quality_rules(doc, label))
    
    # Version format (semantic versioning)
    version = get_nested(doc, "contract.version")
    if version and not _is_valid_semver(version):
        errors.append(f"{label}: version '{version}' is not valid semantic version (MAJOR.MINOR.PATCH)")
    
    return errors


def validate_product_contract(filepath: Path) -> list[str]:
    """Validate a product contract file."""
    errors: list[str] = []
    label = filepath.name
    
    try:
        doc = yaml.safe_load(filepath.read_text()) or {}
    except yaml.YAMLError as e:
        return [f"{label}: Invalid YAML: {e}"]
    
    # Check it's a product contract
    if "product" not in doc:
        return [f"{label}: Not a valid product contract (missing 'product' key)"]
    
    # Required fields
    required = [
        ("product.id", str),
        ("product.version", str),
        ("product.owner", dict),
        ("product.owner.team", str),
        ("product.output", dict),
        ("product.guarantees", dict),
        ("product.access", dict),
    ]
    errors.extend(validate_required_fields(doc, required, label))
    
    # Check marketplace visibility
    access = doc.get("product", {}).get("access", {})
    if "visibility" not in access:
        errors.append(f"{label}: missing product.access.visibility")
    
    # AI constraints for products
    ai = doc.get("product", {}).get("ai_constraints", {})
    if ai.get("embedding_allowed") and ai.get("raw_pii_in_output", True):
        errors.append(
            f"{label}: embedding_allowed=true requires raw_pii_in_output=false"
        )
    
    return errors


def _is_valid_semver(version: str) -> bool:
    """Check if version string is valid semantic version."""
    parts = str(version).split(".")
    if len(parts) != 3:
        return False
    try:
        return all(int(p) >= 0 for p in parts)
    except ValueError:
        return False


def validate_schema_with_jsonschema(filepath: Path, schema_path: Path) -> list[str]:
    """Validate contract against JSON schema (if jsonschema is available)."""
    if not HAS_JSONSCHEMA:
        return []
    
    errors = []
    try:
        doc = yaml.safe_load(filepath.read_text())
        schema = json.loads(schema_path.read_text())
        
        validator = Draft7Validator(schema)
        for error in validator.iter_errors(doc):
            errors.append(f"{filepath.name}: Schema error at {'.'.join(str(p) for p in error.path)}: {error.message}")
    except Exception as e:
        errors.append(f"{filepath.name}: Schema validation failed: {e}")
    
    return errors


def main() -> int:
    """Main entry point."""
    all_errors: list[str] = []
    
    # Paths
    data_contracts_dir = ROOT / "contracts" / "data"
    product_contracts_dir = ROOT / "contracts" / "products"
    schema_path = ROOT / "schemas" / "data_contract_schema.json"
    
    # Create directories if they don't exist
    data_contracts_dir.mkdir(parents=True, exist_ok=True)
    product_contracts_dir.mkdir(parents=True, exist_ok=True)
    
    # Validate data contracts
    data_files = list(data_contracts_dir.glob("*.yml")) + list(data_contracts_dir.glob("*.yaml"))
    for f in data_files:
        print(f"Validating data contract: {f.name}")
        all_errors.extend(validate_data_contract(f))
        
        if schema_path.exists():
            all_errors.extend(validate_schema_with_jsonschema(f, schema_path))
    
    # Validate product contracts
    product_files = list(product_contracts_dir.glob("*.yml")) + list(product_contracts_dir.glob("*.yaml"))
    for f in product_files:
        print(f"Validating product contract: {f.name}")
        all_errors.extend(validate_product_contract(f))
    
    # Report results
    if all_errors:
        print("\n" + "=" * 60)
        print("VALIDATION FAILED")
        print("=" * 60)
        for err in all_errors:
            print(f"  ❌ {err}")
        print(f"\nTotal errors: {len(all_errors)}")
        return 1
    
    total = len(data_files) + len(product_files)
    if total == 0:
        print("\nNo contract files found to validate.")
        print(f"  Data contracts: {data_contracts_dir}")
        print(f"  Product contracts: {product_contracts_dir}")
        return 0
    
    print("\n" + "=" * 60)
    print("VALIDATION PASSED")
    print("=" * 60)
    print(f"  ✅ {len(data_files)} data contracts validated")
    print(f"  ✅ {len(product_files)} product contracts validated")
    return 0


if __name__ == "__main__":
    sys.exit(main())

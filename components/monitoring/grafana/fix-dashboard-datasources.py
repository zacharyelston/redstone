#!/usr/bin/env python3
"""
Script to fix hardcoded datasource UIDs in Grafana dashboards.
This ensures dashboards work across different environments by using standard datasource names.
"""

import json
import os
import glob
from pathlib import Path

# Standard datasource UIDs that match our provisioned datasources
DATASOURCE_MAPPINGS = {
    # Prometheus mappings
    "PBFA97CFB590B2093": "prometheus",
    "prometheus": "prometheus",
    
    # Loki mappings  
    "P8E80F9AEF21F6940": "loki",
    "loki": "loki"
}

def fix_datasource_references(dashboard_data):
    """Recursively fix datasource references in dashboard JSON."""
    if isinstance(dashboard_data, dict):
        for key, value in dashboard_data.items():
            if key == "datasource" and isinstance(value, dict):
                # Fix datasource object
                if "uid" in value:
                    old_uid = value["uid"]
                    if old_uid in DATASOURCE_MAPPINGS:
                        value["uid"] = DATASOURCE_MAPPINGS[old_uid]
                        print(f"  Fixed datasource UID: {old_uid} -> {value['uid']}")
            elif key == "uid" and isinstance(value, str):
                # Fix direct UID references
                if value in DATASOURCE_MAPPINGS:
                    dashboard_data[key] = DATASOURCE_MAPPINGS[value]
                    print(f"  Fixed direct UID: {value} -> {dashboard_data[key]}")
            else:
                # Recursively process nested structures
                fix_datasource_references(value)
    elif isinstance(dashboard_data, list):
        for item in dashboard_data:
            fix_datasource_references(item)

def process_dashboard_file(file_path):
    """Process a single dashboard JSON file."""
    print(f"Processing: {file_path}")
    
    try:
        with open(file_path, 'r') as f:
            dashboard = json.load(f)
        
        # Fix datasource references
        fix_datasource_references(dashboard)
        
        # Write back the fixed dashboard
        with open(file_path, 'w') as f:
            json.dump(dashboard, f, indent=2)
        
        print(f"  ✓ Updated {file_path}")
        
    except Exception as e:
        print(f"  ✗ Error processing {file_path}: {e}")

def main():
    """Main function to process all dashboard files."""
    dashboard_dir = Path(__file__).parent / "dashboards"
    
    if not dashboard_dir.exists():
        print(f"Dashboard directory not found: {dashboard_dir}")
        return
    
    # Find all JSON dashboard files
    json_files = list(dashboard_dir.glob("*.json"))
    
    if not json_files:
        print("No JSON dashboard files found")
        return
    
    print(f"Found {len(json_files)} dashboard files to process")
    print()
    
    for json_file in json_files:
        process_dashboard_file(json_file)
        print()
    
    print("Dashboard datasource fixing complete!")

if __name__ == "__main__":
    main()

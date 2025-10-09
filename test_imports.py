#!/usr/bin/env python3
"""
Test file for auto-import organization.
"""

# Imports are intentionally out of order and mixed
import json
import os
import re
import sys
from collections import defaultdict
from datetime import datetime
from pathlib import Path
from typing import Dict, List


def example_function() -> Dict[str, List[str]]:
    """Example function using the imports."""
    data = defaultdict(list)
    current_time = datetime.now()
    current_dir = Path(os.getcwd())

    print(f"Current directory: {current_dir}")
    print(f"Current time: {current_time}")
    print(f"Python version: {sys.version}")

    # Use regex
    pattern = re.compile(r"\d+")

    # Use json
    json_data = json.dumps({"test": "data"})

    return data


if __name__ == "__main__":
    result = example_function()
    print(result)

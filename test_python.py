#!/usr/bin/env python3
"""Test file for Python development setup with basedpyright and ruff."""

import sys
import os
from typing import Optional, List, Dict, Union
from dataclasses import dataclass
import json  # This import should be sorted by ruff


# Test basedpyright type checking
@dataclass
class Person:
    name: str
    age: int
    email: Optional[str] = None


def greet(person: Person) -> str:
    """Greet a person with type hints."""
    # Basedpyright should infer the return type
    return f"Hello, {person.name}!"


def process_data(data: Union[str, None]) -> str:
    """Test basedpyright's better None handling detection."""
    # Basedpyright should warn here about potential None
    # Try hovering over 'data' to see inferred type
    return data.upper()  # This should trigger a warning


def calculate_sum(numbers: List[int]) -> int:
    """Calculate sum with type hints."""
    total = 0
    for num in numbers:
        total += num  # Basedpyright should show inline type hints
    return total


def parse_config(config: Dict[str, any]) -> None:
    """Test type checking with dictionaries."""
    # 'any' should trigger a warning - should be 'Any' from typing
    for key, value in config.items():
        print(f"{key}: {value}")


# Test unused variable detection (ruff should warn)
def unused_function():
    unused_var = 42  # Ruff should warn about unused variable
    return None


# Test code formatting (ruff should format this)
def poorly_formatted(a, b, c):  # Missing spaces after commas
    result = a + b + c  # Missing spaces around operators
    return result  # Extra spaces


# Test import sorting (ruff should reorganize imports at the top)
class DataProcessor:
    def __init__(self):
        self.data = []

    def add_item(self, item: str) -> None:
        """Add an item to the processor."""
        self.data.append(item)

    def process(self) -> List[str]:
        """Process all items."""
        return [item.upper() for item in self.data]


def main():
    """Main function to test everything."""
    # Test Person class
    person = Person(name="Alice", age=30, email="alice@example.com")
    print(greet(person))

    # Test type inference
    numbers = [1, 2, 3, 4, 5]
    result = calculate_sum(numbers)
    print(f"Sum: {result}")

    # Test DataProcessor
    processor = DataProcessor()
    processor.add_item("hello")
    processor.add_item("world")
    print(processor.process())

    # This should trigger type warnings
    # process_data(None)

    # Test dictionary typing
    config = {"host": "localhost", "port": 8080}
    parse_config(config)


if __name__ == "__main__":
    main()

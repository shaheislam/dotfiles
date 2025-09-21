#!/usr/bin/env bash
# Test script to verify stern-splash integration

echo "Testing Stern + Splash integration..."
echo "Arguments received: $@"
echo ""
echo "Simulating stern output with timestamps and log levels..."
echo ""

# Simulate stern-like output
echo "2025-01-21T10:30:45.123Z pod-name-xyz container-1 INFO: Application started successfully"
echo "2025-01-21T10:30:46.456Z pod-name-xyz container-1 DEBUG: Processing request id=12345"
echo "2025-01-21T10:30:47.789Z pod-name-xyz container-1 WARN: High memory usage detected"
echo "2025-01-21T10:30:48.012Z pod-name-xyz container-1 ERROR: Failed to connect to database"
echo "2025-01-21T10:30:49.345Z pod-name-xyz container-1 INFO: Retrying connection..."
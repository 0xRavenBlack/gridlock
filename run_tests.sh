#!/bin/bash
# run_tests.sh - Run all automated tests for GRIDLOCK.
#
# Each suite exits non-zero on failure. We capture the codes, report a summary
# and only then exit, so a failing suite still prints its diagnostics.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR"

echo "============================================================"
echo "  GRIDLOCK - Test Runner"
echo "============================================================"
echo "  Project: $PROJECT_DIR"
echo "  Godot:   $(godot --version 2>/dev/null || echo 'not found')"
echo ""

if ! command -v godot &> /dev/null; then
    echo "ERROR: Godot is not installed or not in PATH"
    exit 1
fi

echo "------------------------------------------------------------"
echo "  Suite 1/2 - Rules unit tests"
echo "------------------------------------------------------------"
godot --headless --path "$PROJECT_DIR" --scene tests/test_runner.tscn
rules_status=$?

echo ""
echo "------------------------------------------------------------"
echo "  Suite 2/2 - Drag integration test"
echo "------------------------------------------------------------"
godot --headless --path "$PROJECT_DIR" --scene tests/smoke_drag.tscn
smoke_status=$?

echo ""
echo "============================================================"
if [ "$rules_status" -eq 0 ] && [ "$smoke_status" -eq 0 ]; then
    echo "  RESULT: ALL TESTS PASSED"
    echo "============================================================"
    exit 0
fi
echo "  RESULT: FAILED (rules=$rules_status, integration=$smoke_status)"
echo "============================================================"
exit 1

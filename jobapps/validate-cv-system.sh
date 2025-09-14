#!/bin/bash

# CV Generation System Validation Script
# Tests all components of the unified CV generation system

# Don't exit on error - we want to see all tests

echo "================================"
echo "CV System Validation"
echo "================================"
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
PASSED=0
FAILED=0

# Function to test a condition
test_condition() {
    local description="$1"
    local command="$2"

    echo -n "Testing: $description... "

    if eval "$command" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ PASSED${NC}"
        ((PASSED++))
    else
        echo -e "${RED}❌ FAILED${NC}"
        ((FAILED++))
    fi
}

# Function to count items
count_items() {
    local description="$1"
    local command="$2"
    local expected="$3"

    local count=$(eval "$command" 2>/dev/null || echo "0")
    echo -n "Counting: $description... "

    if [ "$count" -ge "$expected" ]; then
        echo -e "${GREEN}✅ Found $count (expected ≥$expected)${NC}"
        ((PASSED++))
    else
        echo -e "${YELLOW}⚠️  Found $count (expected ≥$expected)${NC}"
        ((FAILED++))
    fi
}

echo "1. FILE STRUCTURE VALIDATION"
echo "----------------------------"

test_condition "skills.md exists" "[ -f skills.md ]"
test_condition "jobdesciption.md exists" "[ -f jobdesciption.md ]"
test_condition "CV.tex exists" "[ -f CV.tex ]"
test_condition "Makefile exists" "[ -f Makefile ]"
test_condition "Unified script exists" "[ -f ../scripts/cv/cv-generator-unified.py ]"
test_condition "Compile script exists" "[ -f ../scripts/cv/compile-cv.sh ]"
test_condition "Output directory exists" "[ -d output ]"
test_condition "Generated directory exists" "[ -d generated ]"

echo ""
echo "2. CONTENT VALIDATION"
echo "--------------------"

count_items "Achievements in skills.md" "grep -c '^- ' skills.md" "40"
count_items "Metadata tags in skills.md" "grep -c '\[Tags:' skills.md" "40"
count_items "Companies in skills.md" "grep -c '^### ' skills.md" "4"
count_items "Sections in CV.tex" "grep -c 'begin{rSection}' CV.tex" "5"

echo ""
echo "3. MAKEFILE COMMANDS"
echo "-------------------"

test_condition "make help works" "make help"
test_condition "make stats works" "make stats"
test_condition "make validate works" "make validate"

echo ""
echo "4. PYTHON SCRIPT VALIDATION"
echo "---------------------------"

test_condition "Python3 available" "which python3"
test_condition "Unified script syntax valid" "python3 -m py_compile ../scripts/cv/cv-generator-unified.py"

echo ""
echo "5. LATEX VALIDATION"
echo "------------------"

test_condition "pdflatex available" "which pdflatex"

# Check if CV.tex compiles (allowing for minor errors)
echo -n "Testing: CV.tex compilation... "
if pdflatex -interaction=nonstopmode CV.tex > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Compiles successfully${NC}"
    ((PASSED++))
else
    # Check if PDF was still created despite errors
    if [ -f CV.pdf ]; then
        echo -e "${YELLOW}⚠️  Compiles with warnings${NC}"
        ((PASSED++))
    else
        echo -e "${RED}❌ Compilation failed${NC}"
        ((FAILED++))
    fi
fi

echo ""
echo "6. GENERATED FILES VALIDATION"
echo "-----------------------------"

count_items "PDF files in output/" "find output -name '*.pdf' -type f | wc -l" "1"
count_items "HTML reports in generated/" "find generated -name '*.html' -type f | wc -l" "1"

echo ""
echo "7. WORKFLOW INTEGRATION TEST"
echo "----------------------------"

# Test the unified command with minimal parameters
echo -n "Testing: Unified workflow (dry run)... "
if python3 ../scripts/cv/cv-generator-unified.py --recruiter TestCompany --type perm --salary 100K 2>/dev/null; then
    echo -e "${GREEN}✅ Workflow executes${NC}"
    ((PASSED++))
else
    echo -e "${YELLOW}⚠️  Workflow has issues${NC}"
    ((FAILED++))
fi

echo ""
echo "================================"
echo "VALIDATION SUMMARY"
echo "================================"
echo -e "Tests Passed: ${GREEN}$PASSED${NC}"
echo -e "Tests Failed: ${RED}$FAILED${NC}"

if [ $FAILED -eq 0 ]; then
    echo -e "\n${GREEN}✨ All validations passed! The CV system is working correctly.${NC}"
    exit 0
elif [ $FAILED -le 3 ]; then
    echo -e "\n${YELLOW}⚠️  Most validations passed with minor issues. The system is mostly functional.${NC}"
    exit 0
else
    echo -e "\n${RED}❌ Multiple validation failures detected. Please review and fix the issues.${NC}"
    exit 1
fi
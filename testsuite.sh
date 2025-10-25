#!/bin/bash
# Test Suite for Recycle Bin System

SCRIPT="./recycle_bin.sh"
TEST_DIR="test_data"
PASS=0
FAIL=0

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Test Helper Functions

setup() {
    mkdir -p "$TEST_DIR"
    rm -rf ~/.recycle_bin
}

teardown() {
    rm -rf "$TEST_DIR"
    rm -rf ~/.recycle_bin
}

assert_success() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ PASS${NC}: $1"
        ((PASS++))
    else
        echo -e "${RED}✗ FAIL${NC}: $1"
        ((FAIL++))
    fi
}

assert_fail() {
    if [ $? -ne 0 ]; then
        echo -e "${GREEN}✓ PASS${NC}: $1"
        ((PASS++))
    else
        echo -e "${RED}✗ FAIL${NC}: $1"
        ((FAIL++))
    fi
}

# Test Cases

test_initialization() {
    echo "=== Test: Initialization ==="
    setup
    $SCRIPT help > /dev/null
    assert_success "Initialize recycle bin"
    [ -d ~/.recycle_bin ] && echo "✓ Directory created"
    [ -f ~/.recycle_bin/metadata.log ] && echo "✓ Metadata file created"
    teardown
}

test_delete_file() {
    echo "=== Test: Delete File ==="
    setup
    echo "test content" > "$TEST_DIR/test.txt"
    $SCRIPT delete "$TEST_DIR/test.txt"
    assert_success "Delete existing file"
    [ ! -f "$TEST_DIR/test.txt" ] && echo "✓ File removed from original location"
    teardown
}

test_list_empty() {
    echo "=== Test: List Empty Bin ==="
    setup
    $SCRIPT list 2>&1 | grep -iq "no files" # Accept "No files in recycle bin."(was failing because teachers test script was using another sentence)
    assert_success "List empty recycle bin"
    teardown
}

test_restore_file() {
    echo "=== Test: Restore File ==="
    setup
    echo "test" > "$TEST_DIR/restore_test.txt"
    $SCRIPT delete "$TEST_DIR/restore_test.txt"
    # Get file ID from metadata.log
    ID=$(awk -F'|' '/restore_test/{print $1}' ~/.recycle_bin/metadata.log | head -n 1)
    $SCRIPT restore "$ID"
    assert_success "Restore file"
    [ -f "$TEST_DIR/restore_test.txt" ] && echo "✓ File restored"
    teardown
}

# Run all tests
echo "========================================="
echo " Recycle Bin Test Suite"
echo "========================================="

test_initialization
test_delete_file
test_list_empty
test_restore_file

# Add more test functions here

echo "========================================="
echo "Results: $PASS passed, $FAIL failed"
echo "========================================="

[ $FAIL -eq 0 ] && exit 0 || exit 1
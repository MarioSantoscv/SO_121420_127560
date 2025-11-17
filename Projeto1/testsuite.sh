#!/bin/bash
# Test Suite for Recycle Bin System

# Author: Mario Santos (127560), Kelvin Loforte (121420)
# Date: 2025-10-31


#TODO:
# ADD restore nonexistent file done
# empty empty recycle bin done
# delete nonexistent file done
# search for a file done
# search for a non existent file done
# 


SCRIPT="./recycle_bin.sh"
TEST_DIR="test_data"
PASS=0
FAIL=0

# Colors
GREEN='\033[0;92m' #light green ftw
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



test_nodelete_file(){
    echo "=== Test: Delete Non Existent File ==="
    setup
    $SCRIPT delete "$TEST_DIR/marioo.txt" |grep -iq "does not exist"
    assert_success "Can Not Delete Non-existent File"
    teardown
    [ ! -f "$TEST_DIR/marioo.txt" ] && echo "✓ File still does not exist"  
}

test_delete_bin() {
    echo "=== Test: Delete Recycle bin ==="
    setup
    $SCRIPT delete "$TEST_DIR" |grep -iq "cannot delete recycle bin"
    assert_fail "Could Not Delete Recycle Bin"
    teardown
    [ -d "$TEST_DIR" ] && echo "✓ Recycle Bin Still Exists"
    
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
    assert_success "List Empty Recycle Bin"
    teardown
}
test_norestore_file(){
    echo "===Test: Restore Non Existent File==="
    setup
    $SCRIPT restore "test.txt"| grep -iq "No entry"
    assert_success "Could Not restore file"
    [ ! -f "$TEST_DIR/restore_test.txt" ] && echo "✓ File restored"
    teardown

}
test_restore_file() {
    echo "=== Test: Restore File ==="
    setup
    echo "test" > "$TEST_DIR/restore_test.txt"
    $SCRIPT delete "$TEST_DIR/restore_test.txt" > /dev/null 2>&1 #just to make it quiet(not return if the delete worked or not)
    # Get file ID from metadata.log
    ID=$(awk -F'|' '/restore_test/{print $1}' ~/.recycle_bin/metadata.log | head -n 1)
    $SCRIPT restore "$ID"
    assert_success "Restore File"
    [ -f "$TEST_DIR/restore_test.txt" ] && echo "✓ File restored"
    teardown
}

test_search_file(){
    echo "=== Test: Search File ==="
    setup
    echo "tester" > "$TEST_DIR/search_test.txt"
    $SCRIPT delete "$TEST_DIR/search_test.txt" > /dev/null 2>&1
    $SCRIPT  search "search_test.txt"
    assert_success "Search File"
    teardown
}

test_nosearch_file(){
    echo "=== Test: Search Non Existent File ==="
    setup
    $SCRIPT  search "search_test.txt" | grep -iq "No matches"
    assert_success "Search non existent file"
    teardown
}

test_empty_empty(){
    echo "=== Test: Emptying An Already Empty Bin ==="
    setup 
    echo "tester" > "$TEST_DIR/search_test.txt"
    $SCRIPT delete "$TEST_DIR/search_test.txt" > /dev/null 2>&1
    $SCRIPT empty --force > /dev/null 2>&1
    $SCRIPT empty --force | grep -iq "no items"
    assert_success "Bin already empty"
    teardown
}

test_empty(){
    echo "=== Test: Empty Recicle Bin ==="
    setup
    echo "tester" > "$TEST_DIR/empty_test.txt"
    $SCRIPT delete "$TEST_DIR/empty_test.txt" > /dev/null 2>&1
    $SCRIPT empty --force 2>&1 |grep -Eiq 'Successfully deleted: *[1-9][0-9]*' 
    assert_success "Emptied Recycle Bin"
    teardown
}

test_quota_autocleanup(){
    echo "=== Test: Automatic Cleanup Activation ==="
    setup
    $SCRIPT initialize
    sed -i 's/MAX_SIZE_MB=.*/MAX_SIZE_MB=1/' ~/.recycle_bin/config
    dd if=/dev/zero of=$TEST_DIR/2mbfile.bin  bs=1M  count=2 #making a 2mb file
    $SCRIPT delete "$TEST_DIR/2mbfile.bin"> /dev/null 2>&1
    $SCRIPT quota | grep -iq "calling autocleanup"
    assert_success "Quota reached triggers autocleanup"
    teardown
}

test_autocleanup(){ #fix
    echo "=== Test: Auto Cleanup ==="
    setup
    $SCRIPT initialize
    sed -i 's/RETENTION_DAYS=.*/RETENTION_DAYS=0/' ~/.recycle_bin/config
    echo "tester" > "$TEST_DIR/old_file.txt"
    $SCRIPT delete "$TEST_DIR/old_file.txt" > /dev/null 2>&1
    # Get file ID from metadata.log
    ID=$(awk -F'|' '/old_file/{print $1}' ~/.recycle_bin/metadata.log | head -n 1)
    $SCRIPT cleanup |grep -iq "Items removed: 1"
    grep -q "$ID" ~/.recycle_bin/metadata.log
    if [ $? -eq 0 ]; then
        assert_success "File with retention 0 days was cleaned up"
    fi
    teardown

}

test_help(){
    echo "=== Test: Help Function ==="
    setup
    $SCRIPT help|grep -iq "Linux Recycle Bin - Usage Guide"
    assert_success "Help Was Provided"
    teardown

}
test_statistics(){
    echo "=== Test: Statistics Function ==="
    setup
    echo "tester" > "$TEST_DIR/statistics_file.txt"
    $SCRIPT delete "$TEST_DIR/statistics_file.txt" > /dev/null 2>&1
    $SCRIPT statistics |grep -iq "Total items: 1"
    assert_success "Statistics Shown Correctly"
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
test_nodelete_file
test_search_file
test_nosearch_file
test_empty_empty
test_norestore_file
test_quota_autocleanup
test_autocleanup
test_delete_bin
test_empty
test_help
test_statistics

# Add more test functions here

echo "========================================="
echo "Results: $PASS passed, $FAIL failed"
echo "========================================="

[ $FAIL -eq 0 ] && exit 0 || exit 1
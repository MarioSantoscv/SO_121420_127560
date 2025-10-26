### Test Case 1: Delete Single File
**Objective:** Verify that a single file can be deleted successfully
**Steps:**
1. Create test file: `echo "test" > test.txt`
2. Run: `./recycle_bin.sh delete test.txt`
3. Verify file is removed from current directory
4. Run: `./recycle_bin.sh list`
5. Verify file appears in recycle bin
**Expected Result:**
- File is moved to ~/.recycle_bin/files/
- Metadata entry is created
- Success message is displayed
- File appears in list output
**Actual Result:** [Fill in after testing]
**Status:** ☐ Pass ☐ Fail
**Screenshots:** ![Screenshot](/screenshots/singledelete_test.png)

### Test Case 1: Delete Single File
**Objective:** Verify that a single file can be deleted successfully
**Steps:**
1. Create test file: `echo "test" > test.txt`
2. Run: `./recycle_bin.sh delete test.txt`
3. Verify file is removed from current directory
4. Run: `./recycle_bin.sh list`
5. Verify file appears in recycle bin
**Expected Result:**
- File is moved to ~/.recycle_bin/files/
- Metadata entry is created
- Success message is displayed
- File appears in list output
**Actual Result:** [Fill in after testing]
**Status:** ☐ Pass ☐ Fail
**Screenshots:** ![Screenshot](/screenshots/singledelete_test.png)
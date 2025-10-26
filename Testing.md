
# Recycle Bin Testing Report



## Basic Functionality Tests

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
**Status:** ☒ Pass ☐ Fail
**Screenshots:** ![Screenshot](/screenshots/basic_functionality_cases/singledelete_test.png)

### Test Case 2: Delete Multiple Files
**Objective:** Verify that  Multiple files can be deleted successfully
**Steps:**
1. Create test files: `echo "test" > test.txt` `echo "test" > test1.txt` `echo "test" > test2.txt`
2. Run: `./recycle_bin.sh delete test.txt test1.txt test2.txt`
3. Verify files are removed from current directory
4. Run: `./recycle_bin.sh list`
5. Verify files appear in recycle bin
**Expected Result:**
- Files are moved to ~/.recycle_bin/files/
- Metadata entry is created (check with cat ~/.recycle_bin/metadata.log)
- Success message is displayed
- File appears in list output
**Actual Result:** Metada log update and list function shows the fils and they arent in the directory anymore
**Status:** ☒ Pass ☐ Fail
**Screenshots:** ![Screenshot](/screenshots/basic_functionality_cases/multiple_deletions(dirs%20and%20files).png)

### Test Case 3: List empty recycle bin
**Objective:** Verify that it doesnt list an empty recycle bin
**Steps:**
1. Run: `./recycle_bin.sh empty --force`
2. Run: `./recycle_bin.sh list`
**Expected Result:**
-Shows message: No files in recycle bin
**Actual Result:** Shows message: No files in recycle bin
**Status:** ☒ Pass ☐ Fail
**Screenshots:** ![Screenshot](/screenshots/basic_functionality_cases/listempty.png)

### Test Case 4: List recycle bin with items
**Objective:** Verify that list function works
**Steps:**
1. Create test file: `echo "test" > test.txt`
2. Run: `./recycle_bin.sh delete test.txt`
3. Verify file is removed from current directory
4. Run: `./recycle_bin.sh list`
**Expected Result:**
-A list with the metadata of the file that was deleted (could be detailed or basic depending on flag used)
**Actual Result:** A list with the metadata of the file
**Status:** ☒ Pass ☐ Fail
**Screenshots:** ![Screenshot](/screenshots/basic_functionality_cases/listtest.png)

### Test Case 5: Restore Single File
**Objective:** Verify that a single file can be restored
**Steps:**
1. Create test file: `echo "test" > test.txt`
2. Run: `./recycle_bin.sh delete test.txt`
3. Verify file is removed from current directory
4. Run: `./recycle_bin.sh restore test.txt`
5. Verify file is in the directory it was deleted from
**Expected Results:** File is in the same directory it was deleted from
**Actual Results:** File is in the same directory it was deleted from
**Status:** ☒ Pass ☐ Fail
**Screenshots:** ![Screenshot](/screenshots/basic_functionality_cases/restoretest.png)

### Test Case 6: Empty recycle bin
**Objective:** Verify that recycle bin can be emptied
**Steps:**
1. Create test file: `echo "test" > test.txt`
2. Run: `./recycle_bin.sh delete test.txt`
3. Verify file is removed from current directory
4. Run: `./recycle_bin.sh empty --force`
5. Run: `./recycle_bin.sh list`
**Expected Results** -Shows message: No files in recycle bin
**Actual Results** -Shows message: No files in recycle bin
**Status:** ☒ Pass ☐ Fail
**Screenshots:** ![Screenshot](/screenshots/basic_functionality_cases/empty_test1.png)
![Screenshot](/screenshots/basic_functionality_cases/empty_test2.png)

### Test Case 7: Search for existing file
**Objective:** Verify that existing file can be found
**Steps:**
1. Create test file: `echo "test" > test.txt`
2. Run: `./recycle_bin.sh delete test.txt`
3. Verify file is removed from current directory
4. Run: `./recycle_bin.sh search test.txt`

**Expected Results** -Shows metadata of the file
**Actual Results** -Shows metadata of the file
**Status:** ☒ Pass ☐ Fail
**Screenshots:** ![Screenshot](/screenshots/basic_functionality_cases/search_test.png)

### Test Case 8: Search for non existing file
**Objective:** Verify that non existing file cannot be found
**Steps:**
1. Run `./recycle_bin.sh search momosmd.txt`

**Expected Results** -Shows message: No matches found for momosmd.txt
**Actual Results** -Shows message: No matches found for momosmd.txt
**Status:** ☒ Pass ☐ Fail
**Screenshots:** ![Screenshot](/screenshots/basic_functionality_cases/searchnonexistent.png)

### Test Case 9: Display Help
**Objective:** Verify that help can be displayed
**Steps:**
1. Run `./recycle_bin.sh help`

**Expected Results** -Shows help message
**Actual Results** -Shows help message
**Status:** ☒ Pass ☐ Fail
**Screenshots:** ![Screenshot](/screenshots/basic_functionality_cases/helptest.png)


## Edge cases testing
-  **Delete non-existent file** — ☒ Pass ☐ Fail  
-  **Delete file without permissions** — ☒ Pass ☐ Fail  
-  **Restore when original location has same filename** — ☒ Pass ☐ Fail  
-  **Restore with ID that doesn't exist** — ☒ Pass ☐ Fail  
-  **Handle filenames with spaces** — ☒ Pass ☐ Fail  
-  **Handle filenames with special characters** (`!@#$%^&*()`) — ☒ Pass ☐ Fail  
-  **Handle very long filenames** (255+ characters) — ☐ Pass ☒ Fail  
-  **Handle very large files** (>100 MB) — ☒ Pass ☐ Fail  
-  **Handle symbolic links** — ☐ Pass ☒ Fail  
-  **Handle hidden files** (starting with `.`) — ☒ Pass ☐ Fail  
-  **Delete files from different directories** — ☒ Pass ☐ Fail  
-  **Restore files to read-only directories** — ☐ Pass ☒ Fail

    [View all screenshots here](/screenshots/edge_cases/)
## Performance Tests
-  **Delete 100+ files** — ☒ Pass ☐ Fail  
-  **List recycle bin with 100+ items** — ☒ Pass ☐ Fail  
-  **Search in large metadata file** — ☒ Pass ☐ Fail  
-  **Restore from bin with many items** — ☒ Pass ☐ Fail

    [View all screenshots here](/screenshots/perfomance_test_cases/)

## Test Summary
| Category | Total Tests | Passed | Failed | Pass Rate |
|----------|-------------|--------|--------|-----------|
| Basic Functionality | 13 | 13 | 0 | 100% |
| Edge Cases | 12 | 9 | 3 | 75% |
| Error Handling | 8 | 8 | 0 | 100% |
| Performance | 4 | 4 | 0 | 100% |
| **TOTAL** | **37** | **34** | **3** | **91%** |



## Known Bugs or Limitations
- Restore fails when original directory is **read-only** — file not restored and error message displayed.  
- **Symbolic links** are not handled correctly — links are deleted but not restored as links.  
- **Very long filenames (255+ characters)** cause unexpected behavior or errors.    
 
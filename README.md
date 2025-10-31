# Linux Recycle Bin System

## Author
Mario Santos (127560)  
Kelvin Loforte (121420)

## Description
A bash-based Linux Recycle Bin system implemented for the discipline "Sistemas Operativos." This project allows users to safely delete files with the ability to restore them before permanent deletion. The system mimics a desktop recycle bin but is accessible via shell commands, providing logging, statistics, auto-cleanup, and flexible configuration. 

## Installation

1. **Download the Script**  
   Clone or copy `recycle_bin.sh` to your home directory or preferred location.

2. **Make Executable**  
   ```bash
   chmod +x recycle_bin.sh

   ```


## Usage

Before using most commands, initialize the recycle bin:
```bash
./recycle_bin.sh initialize
```

**Delete files or directories:**
```bash
./recycle_bin.sh delete myfile.txt
./recycle_bin.sh delete file1.txt file2.txt directory/

**List recycled items:**
```bash
./recycle_bin.sh list
./recycle_bin.sh list --detailed
./recycle_bin.sh list --sort name
```

**Restore a file:**
```bash
./recycle_bin.sh restore <UUID-or-short-id-or-filename>
./recycle_bin.sh restore myfile.txt
```

**Search for files:**
```bash
./recycle_bin.sh search "report"
./recycle_bin.sh search "*.pdf"
```

**Empty the recycle bin:**
```bash
./recycle_bin.sh empty
./recycle_bin.sh empty --force
./recycle_bin.sh empty <UUID-or-short-id-or-filename>
```

**Show statistics:**
```bash
./recycle_bin.sh statistics
```

**Auto-cleanup old files:**
```bash
./recycle_bin.sh cleanup
```

**Check quota:**
```bash
./recycle_bin.sh quota
```

**Show help:**
```bash
./recycle_bin.sh help
./recycle_bin.sh --help
./recycle_bin.sh -h
```

## Zenity
We decided to make a short video with more or less 3 minutes, to show it:
![Zenity Video](Zenity.webm)

## Features

- Move files and directories to a safe recycle bin
- Restore deleted items to original location
- List all recycled items with sorting and detailed views (sorting is an optional feature added)
- Search recycled items by name or path (supports wildcards)
- Permanently empty the recycle bin (single or all items)
- **Optional/Extra:** Show detailed statistics (counts, sizes, oldest/newest items)
- **Optional/Extra:** Auto-cleanup items older than a retention period *(configurable) use this command nano ~/.recycle_bin/config (make sureyou are in the same dir)*
- **Optional/Extra:** Quota management: warns and triggers cleanup if full
- Logging for operations
- Configurable settings via a config file
- **Optional/Extra:** Preview text files before restoration (not yet implemented)

## Configuration

Default configuration file: `~/.recycle_bin/config`

Variables:
- `MAX_SIZE_MB`: Maximum allowed size of recycle bin (default: 1024 MB)
- `RETENTION_DAYS`: Number of days to keep items before auto-deletion (default: 30)

Edit this file to change limits: (use this nano ~/.recycle_bin/config)




## Examples


### 1. Deleting Files or Directories

```bash
./recycle_bin.sh delete ~/Documents/example.txt
```
![Screenshot](/screenshots/basic_functionality_cases/singledelete_test.png)
![Screenshot](/screenshots/basic_functionality_cases/multiple_deletions(dirs%20and%20files).png)

---

### 2. Listing Recycled Items (Compact and Detailed)

```bash
./recycle_bin.sh list
./recycle_bin.sh list --detailed
./recycle_bin.sh list --sort name
./recycle_bin.sh list --sort size --detailed
```
![Screenshot](/screenshots/basic_functionality_cases/listtest.png)
![Screenshot](/screenshots/basic_functionality_cases/list_test_of_sortflag.png)
---

### 3. Restoring Files or Directories

```bash
./recycle_bin.sh restore example.txt
./recycle_bin.sh restore 12345678
```
![Screenshot](/screenshots/basic_functionality_cases/restoretest.png)
---

### 4. Searching for Recycled Items

```bash
./recycle_bin.sh search "*.pdf"
./recycle_bin.sh search report
./recycle_bin.sh search -i "presentation" (case insensitive)
```
![Screenshot](/screenshots/basic_functionality_cases/search_test.png)
---

### 5. Emptying the Recycle Bin (All or Single Item)

```bash
./recycle_bin.sh empty
./recycle_bin.sh empty --force
./recycle_bin.sh empty example.txt
./recycle_bin.sh empty 12345678
```
![Screenshot](/screenshots/basic_functionality_cases/empty_test1.png)
![Screenshot](/screenshots/basic_functionality_cases/empty_test2.png)
---

### 6. Showing Statistics

```bash
./recycle_bin.sh statistics
```
![Screenshot](/screenshots/basic_functionality_cases/statistics_test.png)
---

### 7. Auto-cleanup (Removing Old Files Automatically)

```bash
./recycle_bin.sh cleanup
```
![Screenshot](/screenshots/basic_functionality_cases/autocleanup_test.png)
---

### 8. Quota Management (Check Space and Trigger Cleanup)

```bash
./recycle_bin.sh quota
```
![Screenshot](/screenshots/basic_functionality_cases/quotatest.png)
---

### 9. Previewing Files Before Restore

```bash
./recycle_bin.sh preview 12345678
```
![Screenshot](/screenshots/basic_functionality_cases/previewbinary.png)
![Screenshot](/screenshots/basic_functionality_cases/previewtext.png)
---

### 10. Help Command (Show Usage Info)

```bash
./recycle_bin.sh help
./recycle_bin.sh --help
./recycle_bin.sh -h
```
![Screenshot](/screenshots/basic_functionality_cases/helptest.png)
---

## Known Issues
- Cannot handle link resotoration.
- Cannot delelte files with a name that is over 255 letters.
- Restore fails when original directory is read-only — file not restored and error message displayed. 

## References

- [Bash scripting manual](https://www.gnu.org/software/bash/manual/)
- [Sistemas Operativos course materials]
- [Advanced Bash-Scripting Guide](https://tldp.org/LDP/abs/html/)
- [Stack Exchange](https://unix.stackexchange.com/questions/101332/generate-file-of-a-certain-size)
- [Gnome Zenity manual](https://help.gnome.org/users/zenity/stable/)
- [Medium Zenity guide](https://sonamthakur7172.medium.com/exploring-zenity-a-comprehensive-guide-to-dialog-boxes-ff61cb9bbcb0)
- [Zenity terminal manual]

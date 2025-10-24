# Linux Recycle Bin System
## Author
Mario Santos
1275650

Kelvin Loforte
121420


## Description

This project implements a **complete Linux Recycle Bin system** using Bash shell scripting. It was developed as part of the _Sistemas Operativos_ (Operating Systems) course to provide users with a safe alternative to permanent file deletion on Linux systems.

## Installation
[How to install/setup]
## Usage
How to use:
This section explains how to use the Linux Recycle Bin script (`recyclebin.sh`), with practical examples for each command.

---

### 1. **Initialize the Recycle Bin**

Before using any other commands, set up the recycle bin structure:
```bash
./recyclebin.sh initialize
```

---

### 2. **Delete Files or Directories**

Move files or directories to the recycle bin (instead of permanent deletion):
```bash
./recyclebin.sh delete /path/to/file.txt
./recyclebin.sh delete /path/to/file1.txt /path/to/file2.txt /path/to/directory/
```

---

### 3. **List Items in the Recycle Bin**

Show all recycled items:
```bash
./recyclebin.sh list
```
List with details:
```bash
./recyclebin.sh list --detailed
```
Sort by name or size(defaulted to date but can also add flag --sort date):
```bash
./recyclebin.sh list --sort name
./recyclebin.sh list --sort size
```

---

### 4. **Restore Files or Directories**

Restore an item by filename or ID (see IDs from the `list` command):
```bash
./recyclebin.sh restore file.txt
./recyclebin.sh restore 12345678      # Use short ID(optional feature i added to make it easier)
```

If the original location exists, the script will prompt to overwrite, rename, or cancel.

---

### 5. **Search in the Recycle Bin**

Find items by name or path (supports wildcards):
```bash
./recyclebin.sh search "report"
./recyclebin.sh search "*.pdf"
./recyclebin.sh search -i "FILE*.TXT"  # Case-insensitive search can be done with --insensitive-case too
```

---

### 6. **Empty the Recycle Bin (Permanent Delete)**

Delete all items (with confirmation):
```bash
./recyclebin.sh empty
```
Delete all items **without confirmation**:
```bash
./recyclebin.sh empty --force
```
Delete a specific item by ID or name:
```bash
./recyclebin.sh empty file.txt
./recyclebin.sh empty 12345678
```

---

### 7. **Show Statistics**

Display recycle bin statistics, usage, and quota:
```bash
./recyclebin.sh statistics
```

---

### 8. **Auto-Cleanup Old Files**

Remove files older than the configured retention period (set in config file as 30 days):
```bash
./recyclebin.sh cleanup
```

---

### 9. **Check Quota**

See if the recycle bin has reached its maximum allowed size (set in config as 1024 mb):
```bash
./recyclebin.sh quota
```

---

### 10. **Help**

Show all available commands and options:
```bash
./recyclebin.sh help
./recyclebin.sh --help
./recyclebin.sh -h
```

---

**Note:**  
- All deleted files are moved to `~/.recycle_bin`.
- You must run `initialize` at least once before other commands.
- Use the `list` and `search` commands to find the ID or name of items for restore or empty operations.


## Features

- [x] **Delete files and directories:**  
  Move files and folders to a hidden recycle bin instead of permanent deletion.

- [x] **Restore files and directories:**  
  Recover deleted items to their original locations, with handling for name conflicts.

- [x] **List recycled items:**  
  View all items in the recycle bin, with options for compact or detailed metadata.

- [x] **Search in recycle bin:**  
  Find items using flexible patterns (wildcards, case-insensitive matching).

- [x] **Empty recycle bin:**  
  Permanently delete all or specific items from the recycle bin, with confirmation prompts.

- [x] **Show statistics** **(optional):**  
  Display item count, total and average size, quota usage, oldest and newest item.

- [x] **Auto-cleanup old files** **(optional):**  
  Automatically purge items older than the retention period set in configuration.

- [x] **Quota check** **(optional):**  
  Check if the recycle bin exceeds configured limits and trigger cleanup if needed.
## Configuration
[How to configure settings]
## Examples
Below are detailed usage examples for the Linux Recycle Bin system.  


---

### **1. Initialize the Recycle Bin**

```bash
./recyclebin.sh initialize
```
**Screenshot:**  


---

### **2. Delete Files**

```bash
./recyclebin.sh delete ~/Documents/report.txt
```
**Screenshot:**  


---

### **3. List Recycled Items**

```bash
./recyclebin.sh list
```
```bash
./recyclebin.sh list --detailed
```
**Screenshot:**  


---

### **4. Restore a File**

```bash
./recyclebin.sh restore report.txt
```
**Screenshot:**  

---

### **5. Search for an Item**

```bash
./recyclebin.sh search "*.txt"
```
**Screenshot:**  


---

### **6. Empty the Recycle Bin**

```bash
./recyclebin.sh empty --force
```
**Screenshot:**  


---

### **7. Show Statistics**

```bash
./recyclebin.sh statistics
```
**Screenshot:**  


---
## Known Issues
[Any limitations or bugs]
## References
[Resources used]
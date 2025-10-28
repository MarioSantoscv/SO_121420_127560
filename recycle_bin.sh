#!/bin/bash

#ls ~/.recycle_bin/files
#cat ~/.recycle_bin/metadata.log
#TODO: add comments to functions, finish doing the functions, write a test script and a readme file 
#in the readme explain what all of the metadad bits are 

#helper function for human readable bytes

#################################################
# Script Header Comment
# Author: Mario Santos (127560), Kelvin Loforte (121420)
# Date: 2025-10-31
# Description: In this project we built a complete Linux Recycle Bin system using bash shell scripting. 
# This was built for the  discipline Sistemas Operativos with the goal to allow users to safely
# delete files with the ability to restore them before permanent deletion.
# Version: 1.0
#################################################



#this was what was causing the GUI bug ("out of sync with the terminal")

function set_recyclebin_vars() {
    # set_recyclebin_vars
    # Initializes and sets global variables for the recycle bin system.
    #
    # Args:
    #   (none)
    #
    # Returns:
    #   (none) - Sets the following global variables:
    #     RECYCLE_BIN: Path to the recycle bin directory in the user's home.
    #     FILES_DIR:   Path to the directory where recycled files are stored.
    #     METADATA_LOG: Path to the metadata log file.
    #     CONFIG:      Path to the recycle bin configuration file.
    #     LOG:         Path to the recycle bin log file.
    #
    # Example:
    #   set_recyclebin_vars
    RECYCLE_BIN="$HOME/.recycle_bin"
    FILES_DIR="$RECYCLE_BIN/files"
    METADATA_LOG="$RECYCLE_BIN/metadata.log"
    CONFIG="$RECYCLE_BIN/config"
    LOG="$RECYCLE_BIN/recyclebin.log"
}

function human_readable() {
    # human_readable
    # Turns the size into a human readable string
    #
    # Args:
    #   Size of the file
    #
    # Returns:
    #   A Human Readable String 
    #
    #Example:
    #   human_readable
    
        local bytes=$1
        if [ "$bytes" -lt 1024 ]; then
            echo "${bytes}B"
        elif [ "$bytes" -lt $((1024*1024)) ]; then
            printf "%dKB" $((bytes / 1024))
        elif [ "$bytes" -lt $((1024*1024*1024)) ]; then
            printf "%dMB" $((bytes / 1024 / 1024))
        else
            printf "%dGB" $((bytes / 1024 / 1024 / 1024))
        fi
}


function generate_unique_id() {
    local timestamp=$(date +%s%N)
    local random=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 6 | head -
    n 1)
    echo "${timestamp}_${random}"
}


function initialize_recyclebin() {
    # initialize_recyclebin
    # Initializes all necessary files and directories for the recycle bin.
    #
    # Args:
    #   (none)
    #
    # Returns:
    #   0 on success, 1 on error
    #
    # Example:
    #   initialize
    set_recyclebin_vars
   
    # create directories
    if ! mkdir -p "$FILES_DIR"; then
        echo "ERROR: Unable to create recycle bin directories at $FILES_DIR"
        return 1
    fi

    # initialize metadata.db with CSV header if missing or empty (matches the metadata log format of delete_file function)

    # header: ID|ORIGINAL_NAME|ORIGINAL_PATH|DELETION_DATE|FILE_SIZE|FILE_TYPE|PERMISSIONS|OWNER
    if [ ! -f "$METADATA_LOG" ] || [ ! -s "$METADATA_LOG" ]; then
        if ! printf "ID|ORIGINAL_NAME|ORIGINAL_PATH|DELETION_DATE|FILE_SIZE|FILE_TYPE|PERMISSIONS|OWNER\n" > "$METADATA_LOG"; then
            echo "ERROR: Unable to create $METADATA_LOG"
            return 1
        fi
    fi

    # create default config file only if it does not exist
    if [ ! -f "$CONFIG" ]; then
        if ! printf 'MAX_SIZE_MB=1024\nRETENTION_DAYS=30\n' > "$CONFIG"; then
            echo "ERROR: Unable to create config file $CONFIG"
            return 1
        fi
    fi

    # create empty recyclebin.log if not it does not exist (used touch just to make sure i wouldnt alter the file if it already existed)
    if ! touch "$LOG"; then 
        echo "ERROR: Unable to create log file $LOG"
        return 1
    fi

    return 0
}


function delete_file(){ 
    #fix 255 letter edge case




    # delete_file
    # Deletes the files adding them to the recycle bin and storing their metadata.
    #
    # Args:
    #   $@: Names of the files or directories you want to delete (could be multiple).
    #
    # Returns:
    #   1 if usage is incorrect or an error occurs, 0 otherwise.
    # Example:
    #   delete myfile.txt
    #   delete file1.txt file2.txt directory/
    
    set_recyclebin_vars
    
    #error handling: making sure user passes at least one file/dir as an argument
    if [ $# -eq 0 ]; then
        echo "usage: delete_file <file_or_folder>"
        return 1
    fi

    for path in "$@"; do 
        if [ ! -e "$path" ]; then 
        echo "File or directory does not exist: $path"
        continue
        fi

        # To make sure we cant delete the recycle bin or its contents
        abs_path="$(realpath "$path")"
        if [[ "$abs_path" == "$RECYCLE_BIN"* ]]; then
            echo "Error: cannot delete recycle bin or its contents: $path"
            continue
        fi

        #Permisson checks: (done in order of comments)
        #Regular files check read
        #DIRs check execute
        #also check if destination is writable 
        if [ -f "$path" ]; then
            if [ ! -r "$path" ]; then
                echo "Error: Permission denied for $path"
                continue
            fi
        elif [ -d "$path" ]; then
            if [ ! -x "$path" ]; then
                echo "Error: Permission denied for directory $path (no execute permission)"
                continue
            fi
        fi

        
        if [ ! -w "$FILES_DIR" ]; then
            echo "Error: Cannot write to recycle bin destination: $FILES_DIR"
            continue
        fi

        #preparing the file information for recycling
    
        abs_path="$(realpath "$path")" 
        base_name="$(basename "$path")"
        uuid_str="$(uuidgen)"
        uid_short="${uuid_str:0:8}" #after doing the other functions i realized its better to use a shorter id 
        ts="$(date +%d%m%Y%H%M%S)"
        recycle_name="${base_name}_${uuid_str}"
        dest_path="$FILES_DIR/$recycle_name"
        
        #Storing metadata (perrmissions, timestamps, owners)
        #(check stat --help for more info on formatting options)

        perms=$(stat -c '%a' "$path")
        owner=$(stat -c '%U' "$path")
        group=$(stat -c '%G' "$path")
       


        #getting file size and type (used copilot help)
        if [ -d "$path" ]; then
            ftype="directory"
            if du -sb "$path" >/dev/null 2>&1; then
                size=$(du -sb "$path" | cut -f1) #cut getsd me the first field which is the size
            else
                size_kb=$(du -s "$path" | cut -f1)
                size=$((size_kb * 1024))
            fi
        else
            ftype="file"
            size=$(stat -c '%s' "$path" 2>/dev/null || printf '0')
        fi


        #moving the file/dir

        if mv -- "$path" "$dest_path"; then
            echo "Recycled: $abs_path -> $dest_path"
            echo "$uid_short|$base_name|$abs_path|$ts|$size|$ftype|$perms|$owner" >> "$METADATA_LOG" || \
                echo "Warning: failed to write metadata for $path"
            echo "$(date +"%Y-%m-%d %H:%M:%S") MOVED $abs_path -> $dest_path size=${size} type=${ftype} uuid=${uuid_str}" >> "$LOG" 2>/dev/null
        else
            echo "Error: Failed to move $path to recycle bin."
            echo "$(date +"%Y-%m-%d %H:%M:%S") FAILED_MOVE $abs_path -> $dest_path" >> "$LOG" 2>/dev/null
        fi
    done


}
function list_recycled(){
    # list_recycled
    # Lists all files and directories in the recycle bin. Can show a detailed list (with full metadata) or a compact list (ID, name, deletion date, size).
    #
    # Args:
    #   --sort <date|name|size>   # Sorts output by date deleted (default), name, or size (extra feature)
    #   --detailed                # Shows detailed metadata (otherwise, compact view)
    #
    # Returns:
    #   0 on success, 1 on error/invalid usage
    # Example:
    #   list_recycled --sort size --detailed
    
    set_recyclebin_vars

    #I wanted to add a sorting flag to the function and made it sortable by date of deletion, name or size

    sort_by="date" #default sorting by date of deletion
    detailed=0
    while [[ $# -gt 0 ]]; do
        case $1 in
            --sort)
                sort_by="$2"
                shift 2 #removing the flag and its argument just to make handling easier if necessary (done by copilot)
                ;;
            --detailed)
                detailed=1
                shift
                ;;
            *)
                echo "Usage: list_recycled [--sort <date|name|size>] [--detailed]"
                return 1
                ;;
        esac
    done
    if [ ! -f "$METADATA_LOG" ]; then
        echo "No files in recycle bin."
        return 0
    fi

    entries=()
    total_count=0
    total_bytes=0

    # read metadata lines one by one
    while IFS= read -r line || [ -n "$line" ]; do
        #skip empty lines
        [ -z "$line" ] && continue

        #skip the header
        case "$line" in
            ID* ) continue ;;
        esac

        # expected format from the delete_file function:
        # id|name|orig_path|del_date|size|ftype|perms|owner
        IFS='|' read -r id name orig_path del_date size ftype perms owner <<< "$line"

        recycle_path="$(ls $FILES_DIR/${name}_${id}* 2>/dev/null | head -n 1)" #finding the first file that in files dir that matches that name

        # only include items that currently exist in the recycle bin
        [ -e "$recycle_path" ] || continue

        # size: files -> stat, directories -> du -sk (KB) converted to bytes using integer math 
        if [ -d "$recycle_path" ]; then
            if du -sb "$recycle_path" >/dev/null 2>&1; then
                size_bytes=$(du -sb "$recycle_path" | cut -f1)
            else
                echo "du failed on $recycle_path" >&2
                size_bytes=0
            fi
        else
            size_bytes=$(stat -c '%s' "$recycle_path" 2>/dev/null || echo 0)
        fi


        size_hr="$(human_readable "$size_bytes")"

        # convert timestamp ddmmyyyyHHMMSS -> "YYYY-MM-DD HH:MM:SS" (if matches expected format)
        if [[ $del_date =~ ^[0-9]{14}$ ]]; then
            del_date_fmt="${del_date:4:4}-${del_date:2:2}-${del_date:0:2} ${del_date:8:2}:${del_date:10:2}:${del_date:12:2}"
        else
            del_date_fmt="$del_date"
        fi

        id_short="${id:0:8}"   # #did this because uuids are very long so i decided to use a more compact form (used 8 chars just because it looks good and the odds of collision are slim)(why i changed the deletefunction too)
        size_hr="$(human_readable "$size_bytes")"  
        name="$(basename "$orig_path")"
        

        # store an entry with this format: $id|$name|$del_date|$size|$size_hr|$ftype|$perms|$owner|$orig_path
        entries+=( "$id_short|$name|$del_date_fmt|$size_bytes|$size_hr|$ftype|$perms|$owner|$orig_path|$id|$recycle_path" )
        total_count=$(( total_count + 1 ))
        total_bytes=$(( total_bytes + size_bytes ))

    done < "$METADATA_LOG"

    if [ ${#entries[@]} -eq 0 ]; then
        echo "No files in recycle bin."
        return 0
    fi

    # choose sort option (date: newest first thats why i put the r flag for reverse order, the n flag is for numeric so the size is done largest first)
    case "$sort_by" in
        name) sort_args=(-t'|' -k2,2) ;;          
        size) sort_args=(-t'|' -k4,4nr) ;;        
        date) sort_args=(-t'|' -k3,3r) ;;        
        *)
            echo "Invalid sort option. Valid options are: date, name, size."
            return 1
            ;;
    esac

    if [ "$detailed" -eq 0 ]; then
        # Compact table view
        printf "%-10s %-25s %-20s %-12s\n" "ID" "Filename" "Deleted" "Size"
        printf "%-10s %-25s %-20s %-12s\n" "----------" "-------------------------" "--------------------" "------------"
        printf "%s\n" "${entries[@]}" | sort "${sort_args[@]}" | while IFS='|' read -r id_short name del_date size_bytes size_hr _ftype _perms _owner _orig_path _id _recycle_path; do
            printf "%-10s %-25.25s %-20s %-12s\n" "$id_short" "$name" "$del_date" "$size_hr"
        done
    else
        # Detailed view
        printf "Detailed view of recycled items (sorted by %s):\n\n" "$sort_by"
        printf "%s\n" "${entries[@]}" | sort "${sort_args[@]}" | while IFS='|' read -r id_short name del_date size_bytes size_hr ftype perms owner orig_path id recycle_path; do
            printf "Unique ID: %s\n" "$id"
            printf "Display ID: %s\n" "$id_short"
            printf "Original filename: %s\n" "$name"
            printf "Original path: %s\n" "$orig_path"
            printf "Recycle path: %s\n" "$recycle_path"
            printf "Deleted: %s\n" "$del_date"
            printf "Size: %s (%d bytes)\n" "$size_hr" "$size_bytes"
            printf "Type: %s\n" "$ftype"
            printf "Permissions: %s\n" "$perms"
            printf "Owner: %s\n" "$owner"
            printf -- "----\n" #fixed mistake needed to add -- 
        done
    fi

    # totals(extra)
    total_hr="$(human_readable "$total_bytes")"
    echo
    printf "Total items: %d\n" "$total_count"
    printf "Total size: %s (%d bytes)\n" "$total_hr" "$total_bytes"

}

   #fix links handling
   #fix to restoree to read oonly files
   
function restore_file() {
    # restore_file
    # Restores a file or directory from the recycle bin to its original location, preserving metadata.
    #
    # Args:
    #   <UUID-or-short-id-or-filename>   # Specify the recycled item's full UUID, short ID, or original filename to restore.
    #
    # Returns:
    #   0 on success, 1 on error or invalid usage.
    #
    # Example:
    #   restore_file 12345678
    #   restore_file "my file with spaces.txt"


    set_recyclebin_vars

    # Helper to trim whitespace
    trim() { echo "$1" | awk '{$1=$1;print}'; }


    # Accept full argument (with spaces) first fix 
    local lookup="$(trim "$*")"
    local matches=()
    local idx=0

    if [ -z "$lookup" ]; then
        echo "Usage: restore_file <UUID-or-short-id-or-filename>"
        return 1
    fi

    if [ ! -f "$METADATA_LOG" ]; then
        echo "No metadata log found: $METADATA_LOG"
        return 1
    fi

    # collect matches
    while IFS= read -r line || [ -n "$line" ]; do
        [ -z "$line" ] && continue
        IFS='|' read -r id name orig_path del_date size ftype perms owner <<< "$line"

        # Trim all variables that will be compared
        id="$(trim "$id")"
        name="$(trim "$name")"
        orig_path="$(trim "$orig_path")"
        base_name="$(trim "$(basename "$orig_path")")"

        recycle_path="$(ls "$FILES_DIR"/"${name}_${id}"* 2>/dev/null | head -n 1)"

        # see if fields are not empty
        [ -z "$id" ] && continue
        [ -z "$recycle_path" ] && continue

        # Matching logic, with all variables quoted and trimmed(second fix)
        if [ "$lookup" = "$id" ] || [[ "$id" == "$lookup"* ]] || [ "$lookup" = "$base_name" ] || [ "$lookup" = "$orig_path" ] || [ "$lookup" = "$name" ]; then
            matches+=("$line")
        fi
    done < "$METADATA_LOG"

    if [ ${#matches[@]} -eq 0 ]; then
        echo "No entry found matching '$lookup' in $METADATA_LOG"
        return 1
    fi

    # if multiple matches, let user choose which one to restore
    local chosen_line
    if [ ${#matches[@]} -gt 1 ]; then
        echo "Multiple matches found:"
        for i in "${!matches[@]}"; do
            IFS='|' read -r id name orig_path del_date size ftype perms owner <<< "${matches[i]}"
            id="$(trim "$id")"
            name="$(trim "$name")"
            orig_path="$(trim "$orig_path")"
            base_name="$(trim "$(basename "$orig_path")")"
            # readable timestamp if possible (ddmmyyyyHHMMSS -> YYYY-MM-DD HH:MM:SS)
            if [[ $del_date =~ ^[0-9]{14}$ ]]; then
                del_date_fmt="${del_date:4:4}-${del_date:2:2}-${del_date:0:2} ${del_date:8:2}:${del_date:10:2}:${del_date:12:2}"
            else
                del_date_fmt="$del_date"
            fi
            size_bytes=0
            recycle_path="$(ls "$FILES_DIR"/"${name}_${id}"* 2>/dev/null | head -n 1)"
            if [ -e "$recycle_path" ]; then
                if [ -d "$recycle_path" ]; then
                    size_kb=$(du -sk "$recycle_path" 2>/dev/null | cut -f1)
                    size_bytes=$(( ${size_kb:-0} * 1024 ))
                else
                    size_bytes=$(stat -c '%s' "$recycle_path" 2>/dev/null || echo 0)
                fi
            fi
            if declare -f human_readable >/dev/null 2>&1; then
                size_hr=$(human_readable "$size_bytes")
            else
                size_hr="${size_bytes}B"
            fi
            echo "[$i] ID=${id:0:8}  Name=$base_name  Deleted=$del_date_fmt  Size=$size_hr  RecyclePath=$recycle_path"
        done

        while true; do
            read -rp "Select index to restore (or 'c' to cancel): " selected
            [ "$selected" = "c" ] && echo "Cancelled." && return 0
            if [[ "$selected" =~ ^[0-9]+$ ]] && [ "$selected" -ge 0 ] && [ "$selected" -lt "${#matches[@]}" ]; then
                chosen_line="${matches[selected]}"
                break
            fi
            echo "Invalid selection."
        done
    else
        chosen_line="${matches[0]}"
    fi

    # Re-parse chosen line and reconstruct recycle_path for restoration
    IFS='|' read -r id name orig_path del_date size ftype perms owner <<< "$chosen_line"
    id="$(trim "$id")"
    name="$(trim "$name")"
    orig_path="$(trim "$orig_path")"
    base_name="$(trim "$(basename "$orig_path")")"
    recycle_path="$(ls "$FILES_DIR"/"${name}_${id}"* 2>/dev/null | head -n 1)"

    if [ ! -e "$recycle_path" ]; then
        echo "Recycled item not found at: $recycle_path"
        return 1
    fi

    # using the same size calculation method to see if there is enough space to restore
    if [ -d "$recycle_path" ]; then
        size_kb=$(du -sk "$recycle_path" 2>/dev/null | cut -f1)
        size_bytes=$(( ${size_kb:-0} * 1024 ))
    else
        size_bytes=$(stat -c '%s' "$recycle_path" 2>/dev/null || echo 0)
    fi

    # ensure parent dir exists (create if necessary)
    dest_parent="$(dirname "$orig_path")"
    if [ ! -d "$dest_parent" ]; then
        echo "Parent directory $dest_parent does not exist."
        read -rp "Create parent directories and continue? [y/N]: " yn
        case "$yn" in
            [Yy]* ) mkdir -p "$dest_parent" || { echo "Failed to create $dest_parent (permission?)"; return 1; } ;;
            * ) echo "Cancelled."; return 0 ;;
        esac
    fi

    if [ ! -w "$dest_parent" ]; then #fixing the edge case error where i could restore to a 555 dir 
        echo "Error: Parent directory '$dest_parent' is not writable. Restore aborted."
        return 1
    fi

    # check disk space on destination filesystem
    avail_kb=$(df -P -k "$dest_parent" 2>/dev/null | awk 'END{print $4+0}')
    need_kb=$(( (size_bytes + 1023) / 1024 ))
    if [ -n "$avail_kb" ] && [ "$avail_kb" -lt "$need_kb" ]; then
        echo "Not enough disk space to restore (need ${need_kb}K, have ${avail_kb}K)."
        return 1
    fi

    dest="$orig_path"
    # handle conflicts if destination exists
    if [ -e "$dest" ]; then
        echo "A file or directory already exists at $dest"
        action="Choose action: "
        options=("Overwrite" "Restore with modified name" "Cancel")
        select opt in "${options[@]}"; do
            case "$REPLY" in
                1)
                    # Overwrite: remove existing (prompt for final confirmation)
                    read -rp "Are you sure you want to overwrite $dest ? [y/N]: " ok
                    case "$ok" in
                        [Yy]* )
                            if rm -rf -- "$dest"; then
                                echo "Existing item removed."
                                break
                            else
                                echo "Failed to remove existing item (permission?)."
                                return 1
                            fi
                            ;;
                        *)
                            echo "Cancelled by user."
                            return 0
                            ;;
                    esac
                    ;;
                2)
                    ts_now=$(date +%s)
                    dest="${orig_path}_restored_${ts_now}"
                    echo "Will restore to: $dest"
                    break
                    ;;
                3)
                    echo "Cancelled."
                    return 0
                    ;;
                *)
                    echo "Invalid selection."
                    ;;
            esac
        done
    fi

    # perform the move
    if mv -- "$recycle_path" "$dest"; then
        echo "Restored: $dest"
        # restore perms
        if [ -n "$perms" ]; then
            chmod "$perms" "$dest" 2>/dev/null || echo "Warning: chmod failed for $dest"
        fi

        # remove the metadata line (matching the exact ID)
        tmpf="$(mktemp "${RECYCLE_BIN:-/tmp}/restore.XXXXXXXX")" || tmpf="/tmp/restore.$$"
        awk -F'|' -v id="$id" '$1 != id { print }' "$METADATA_LOG" > "$tmpf" && mv "$tmpf" "$METADATA_LOG" || {
            echo "Warning: failed to update metadata log; metadata may still reference the restored item."
            [ -f "$tmpf" ] && rm -f "$tmpf"
        }

        # log operation
        LOG="${RECYCLE_BIN:-$HOME/.recycle_bin}/recyclebin.log"
        echo "$(date +"%Y-%m-%d %H:%M:%S") RESTORED $id -> $dest size=${size_bytes}" >> "$LOG" 2>/dev/null

        echo "Restore complete."
        return 0
    else
        echo "Failed to move $recycle_path -> $dest (permission or filesystem error)."
        echo "$(date +"%Y-%m-%d %H:%M:%S") FAILED_RESTORE $id -> $dest" >> "${RECYCLE_BIN:-$HOME/.recycle_bin}/recyclebin.log" 2>/dev/null
        return 1
    fi
}


function search_recycled(){
    # search_recycled
    # Searches for files or directories in the recycle bin by name or original path, supporting wildcards and case-insensitive matching.
    #
    # Args:
    #   [-i|--ignore-case]    # Optional: Ignore case in search pattern
    #   <pattern>             # Search pattern (wildcards * supported)
    #
    # Returns:
    #   0 on success, 1 on error/invalid usage
    #
    # Example:
    #   search_recycled "report"
    #   search_recycled -i "*.pdf"
    
    set_recyclebin_vars

    local case_insensitive=0
    local pattern

    # argument parsing and help
    while [[ $# -gt 0 ]]; do 
        case "$1" in 
            -i|--ignore-case)
                case_insensitive=1; shift ;;
            -h|--help)
                echo "Usage: search_recycled [-i|--ignore-case] <pattern>"
                echo "Examples:"
                echo "  search_recycled \"report\""
                echo "  search_recycled \"*.pdf\""
                return 0
                ;;
            -*) printf "Unknown option: %s\n" "$1"
                return 1
                ;;
            *) break;;
        esac
    done

    #remaining arguments are the pattern now
    pattern="$*"

    if [ -z "$pattern" ]; then 
        echo "Usage: search_recycled [-i|--ignore-case] <pattern>"
        return 1
    fi

    local metadata_file="$METADATA_LOG"
    if [ -z "$metadata_file" ]; then
        metadata_file="${RECYCLE_BIN:-$HOME/.recycle_bin}/metadata.log"
    fi

    if [ ! -f "$metadata_file" ]; then 
        echo "No metadata file found at: $metadata_file"
        return 1
    fi

    # set up grep style depending on pattern type
    local search_expr
    local mode_flag
    if [[ "$pattern" == *"*"* ]]; then 
        #converting the * into .* for regex use
        search_expr="${pattern//\*/.*}"
        mode_flag="-E" #-E, --extended-regexp     PATTERNS are extended regular expressions
    else
        search_expr="$pattern"
        mode_flag="-F" #-F, --fixed-strings       PATTERNS are strings
    fi

    #building the grep options (case insensitive or not)
    local grep_opts="$mode_flag"
    if [ "$case_insensitive" -eq 1 ]; then
        grep_opts+=" -i"
    fi

    local matches=()

    # read metadata lines one by one
    while IFS= read -r line || [ -n "$line" ]; do
        [ -z "$line" ] && continue

        # skip CSV header if present
        case "$line" in
            ID* ) continue ;;
        esac

        # expected format for lines: ID|ORIGINAL_NAME|ORIGINAL_PATH|DELETION_DATE|FILE_SIZE|FILE_TYPE|PERMISSIONS|OWNER
        IFS='|' read -r id name orig_path del_date size ftype perms owner <<< "$line"

        # For search, we want to match by name or orig_path
        local matched=0

        #actual searching logic using grep (copilot recommended using the flags -q for quiet and -- for end of options)
        if [ -n "$name" ] && printf '%s\n' "$name" | grep $grep_opts -q -- "$search_expr"; then
            matched=1
        fi
        if [ $matched -eq 0 ] && [ -n "$orig_path" ] && printf '%s\n' "$orig_path" | grep $grep_opts -q -- "$search_expr"; then
            matched=1
        fi

        if [ $matched -eq 1 ]; then
            # convert timestamp ddmmyyyyHHMMSS -> "YYYY-MM-DD HH:MM:SS" (if matches expected format)
            if [[ $del_date =~ ^[0-9]{14}$ ]]; then
                del_date_fmt="${del_date:4:4}-${del_date:2:2}-${del_date:0:2} ${del_date:8:2}:${del_date:10:2}:${del_date:12:2}"
            else
                del_date_fmt="$del_date"
            fi
            local uid_short="${id:0:8}"
            matches+=( "$uid_short|$name|$orig_path|$del_date_fmt|$size|$ftype|$perms|$owner|$id" )
        fi
    done < "$metadata_file"

    if [ ${#matches[@]} -eq 0 ]; then
        echo "No matches found for '$pattern'."
        return 0
    fi

    #print results in a table format (showing additional info)
    printf "%-10s %-25s %-50s %-20s %-8s %-8s %-8s %-8s\n" "ID" "Name" "Original Path" "Deleted" "Size" "Type" "Perms" "Owner"
    printf "%-10s %-25s %-50s %-20s %-8s %-8s %-8s %-8s\n" "----------" "-------------------------" "--------------------------------------------------" "--------------------" "--------" "------" "------" "------"

    for entry in "${matches[@]}"; do
        IFS='|' read -r id name orig_path del_date size ftype perms owner fullid <<< "$entry"
        printf "%-10s %-25.25s %-50.50s %-20s %-8s %-8s %-8s %-8s\n" "$id" "${name:-}" "${orig_path:-}" "${del_date:-}" "${size:-}" "${ftype:-}" "${perms:-}" "${owner:-}"
    done

    printf "\nTotal matches: %d\n" "${#matches[@]}"
    return 0
}

function empty_recyclebin(){ #ask teacher if this wouldnt be the same as the delete function when in single mode
    # empty_recyclebin
    # Permanently deletes items from the recycle bin, either all items or a specific item by ID or filename.
    #
    # Args:
    #   [--force]                    # Optional: Skip confirmation prompts
    #   [<UUID-or-short-id-or-filename>]  # Optional: Delete only the item matching this identifier; if omitted, deletes all items
    #
    # Returns:
    #   0 on success, 1 on error/invalid usage
    #
    # Example:
    #   empty_recyclebin
    #       # Asks for confirmation before deleting all items
    #   empty_recyclebin --force
    #       # Deletes ALL items without confirmation
    #   empty_recyclebin 12345678
    #       # Asks for confirmation before deleting item with that ID
    #   empty_recyclebin --force myfile.txt
    #       # Deletes item with that name/ID without confirmation
    #
    # Notes:
    #   - Removes matching files/directories and updates the metadata log
    #   - Prints summary of deletions and space freed
    #   - Prompts for confirmation unless --force is specified

    set_recyclebin_vars
    
    local idArg=""
    local force=false

    for a in "$@"; do
        case "$a" in
            --force) force=true ;;
            *) 
                if [[ -z "$idArg" ]]; then
                    idArg="$a"
                else
                    echo "Usage: empty_recyclebin [--force] [<UUID-or-short-id-or-filename>]"
                    return 1
                fi
                ;;
        esac
    done

    #quick check if recycle bin has been initailized just for good measure
    if [ -z "$RECYCLE_BIN" ] || [ -z "$METADATA_LOG" ] || [ -z "$FILES_DIR" ] || [ -z "$LOG" ]; then
        echo "Recycle bin variables are not initialized. Call initialize_recyclebin first." >&2
        return 1
    fi

    if [ ! -f "$METADATA_LOG" ]; then
        echo "No metadata file found at: $METADATA_LOG"
        return 0
    fi

    #determine deletion mode (single or all)
    local mode="all"
    if [[ -n "$idArg" ]]; then 
        mode="single"
    fi

    #confirming force since it is dangerous
    if [ "$force" != "true" ]; then
        if [ "$mode" = "all" ]; then
            read -rp "Permanently delete ALL items in the recycle bin? This cannot be undone. Type 'YES' to confirm: " confirm
            if [ "$confirm" != "YES" ]; then
                echo "Operation cancelled."
                return 0
            fi
        else
           read -rp "Permanently delete item matching ID '$idArg'? This cannot be undone. Type YES to confirm: " confirm
           if [ "$confirm" != "YES" ]; then
                echo "Operation cancelled."
                return 0
           fi
        fi
    fi

    #getting the lines that its supposed to delete
    local lines_to_delete=()
    while IFS= read -r line || [ -n "$line" ]; do
        [ -z "$line" ] && continue
        case "$line" in 
            ID* ) continue;;
        esac
        # expected format: ID|ORIGINAL_NAME|ORIGINAL_PATH|DELETION_DATE|FILE_SIZE|FILE_TYPE|PERMISSIONS|OWNER
        IFS='|' read -r id name orig_path del_date size ftype perms owner <<< "$line"
        [ -z "$id" ] && continue

        # reconstruct recycle_path to find the file in the recycle bin
        recycle_path="$(ls "$FILES_DIR"/${name}_${id}* 2>/dev/null | head -n 1)"

        if [ "$mode" = "all" ]; then
            lines_to_delete+=( "$id|$name|$orig_path|$del_date|$size|$ftype|$perms|$owner|$recycle_path" )
        else 
            local base_name_actual
            base_name_actual="$(basename "$orig_path")"
            if [ "$idArg" = "$id" ] || [[ "$id" == "$idArg"* ]] || [ "$idArg" = "$base_name_actual" ] || [ "$idArg" = "$orig_path" ]; then
                lines_to_delete+=( "$id|$name|$orig_path|$del_date|$size|$ftype|$perms|$owner|$recycle_path" )
            fi
        fi
    done < "$METADATA_LOG"

    if [ ${#lines_to_delete[@]} -eq 0 ]; then
        if [ "$mode" = "all" ]; then
            echo "No items found in recycle bin to delete."
        else
            echo "No matching item found for ID '$idArg' to delete."
        fi
        return 0
    fi

    local to_delete=()
    if [ "$mode" = "single" ] && [ ${#lines_to_delete[@]} -gt 1 ] && [ "$force" != "true" ]; then
        echo "Multiple matches found:"
        for i in "${!lines_to_delete[@]}"; do
            IFS='|' read -r id name orig_path del_date size ftype perms owner recycle_path <<< "${lines_to_delete[i]}"
            if [[ $del_date =~ ^[0-9]{14}$ ]]; then
                del_date_fmt="${del_date:4:4}-${del_date:2:2}-${del_date:0:2} ${del_date:8:2}:${del_date:10:2}:${del_date:12:2}"
            else
                del_date_fmt="$del_date"
            fi
            size_bytes=0
            if [ -e "$recycle_path" ]; then
                if [ -d "$recycle_path" ]; then
                    if du -sb "$recycle_path" >/dev/null 2>&1; then
                        size_bytes=$(du -sb "$recycle_path" | cut -f1)
                    else
                        kb=$(du -s "$recycle_path" 2>/dev/null | cut -f1)
                        size_bytes=$((kb * 1024))
                    fi
                else
                    size_bytes=$(stat -c '%s' "$recycle_path" 2>/dev/null || echo 0)
                fi
            fi
            hr="$(human_readable "$size_bytes")"
            echo "[$i] ID=${id:0:8}  Name=$name  Deleted=$del_date_fmt  Size=$hr  RecyclePath=$recycle_path"
        done

        while true; do
            read -rp "Select index to delete (or 'c' to cancel): " sel
            [ "$sel" = "c" ] && echo "Cancelled." && return 0
            if [[ "$sel" =~ ^[0-9]+$ ]] && [ "$sel" -ge 0 ] && [ "$sel" -lt "${#lines_to_delete[@]}" ]; then
                to_delete+=( "${lines_to_delete[$sel]}" )
                break
            fi
            echo "Invalid selection."
        done
    else
        to_delete=( "${lines_to_delete[@]}" )
    fi

    #doing the deletions
    local deleted_count=0
    local deleted_bytes=0
    local failed=()
    local removed_ids=()
    for line in "${to_delete[@]}"; do
        IFS='|' read -r id name orig_path del_date size ftype perms owner recycle_path <<< "$line"
        #calculating size before deletion
        size_bytes=0
        if [ -e "$recycle_path" ]; then
            if [ -d "$recycle_path" ]; then
                if du -sb "$recycle_path" >/dev/null 2>&1; then
                    size_bytes=$(du -sb "$recycle_path" | cut -f1)
                else
                    kb=$(du -s "$recycle_path" 2>/dev/null | cut -f1)
                    size_bytes=$((kb * 1024))
                fi
            else
                size_bytes=$(stat -c '%s' "$recycle_path" 2>/dev/null || echo 0)
            fi
        else
            size_bytes="${size:-0}"
        fi

        # Attempting to remove
        if [ -n "$recycle_path" ] && [ -e "$recycle_path" ]; then
            if rm -rf -- "$recycle_path"; then
                deleted_count=$((deleted_count + 1))
                deleted_bytes=$((deleted_bytes + size_bytes))
                removed_ids+=( "$id" )
                echo "$(date +"%Y-%m-%d %H:%M:%S") DELETED $id -> $recycle_path size=${size_bytes}" >> "$LOG" 2>/dev/null
            else
                failed+=( "$id|$recycle_path|failed_rm" )
                echo "$(date +"%Y-%m-%d %H:%M:%S") FAILED_DELETE $id -> $recycle_path" >> "$LOG" 2>/dev/null
            fi
        else
            # file already missing on filesystem - treat as removed but still remove metadata
            removed_ids+=( "$id" )
            deleted_count=$((deleted_count + 1))
            deleted_bytes=$((deleted_bytes + size_bytes))
            echo "$(date +"%Y-%m-%d %H:%M:%S") DELETED_META_ONLY $id -> $recycle_path (file missing) size=${size_bytes}" >> "$LOG" 2>/dev/null
        fi
    done

    # Update metadata.log: remove lines matching removed_ids
    if [ ${#removed_ids[@]} -gt 0 ]; then
        tmpf="$(mktemp "${RECYCLE_BIN:-/tmp}/empty.XXXXXXXX")" || tmpf="/tmp/empty.$$"
        awk -F'|' -v ids="$(IFS=,; echo "${removed_ids[*]}")" '
            BEGIN {
                split(ids, arr, ",");
                for (i in arr) idset[arr[i]] = 1;
            }
            $1 == "ID" { print; next }
            !($1 in idset) { print }
        ' "$METADATA_LOG" > "$tmpf" && mv "$tmpf" "$METADATA_LOG" || {
            echo "Warning: failed to update metadata log; metadata may still reference deleted items."
            [ -f "$tmpf" ] && rm -f "$tmpf"
        }
    fi

    #summary 
    echo 
    echo "Deletion summary:"
    echo "Requested mode: $mode"
    echo "Items processed: ${#to_delete[@]}"
    echo "Successfully deleted: $deleted_count"
    echo "Total space freed: $(human_readable "$deleted_bytes") ($deleted_bytes bytes)"
    if [ ${#failed[@]} -gt 0 ]; then
        echo "  Failures: ${#failed[@]}"
        for e in "${failed[@]}"; do
            IFS='|' read -r uu rec why <<< "$e"
            echo "    $uu -> $rec  ($why)"
        done
    fi

    return 0
}

function show_statistics() {
    # show_statistics
    # Displays statistics about the recycle bin: item counts, total and average size, quota, oldest/newest item.
    #
    # Args: none
    # Returns: 0 on success, 1 if not initialized or on error
    # Example: statistics

    set_recyclebin_vars

    if [ -z "$RECYCLE_BIN" ] || [ -z "$METADATA_LOG" ] || [ -z "$CONFIG" ]; then
        echo "Recycle bin variables are not initialized. Call initialize_recyclebin first." >&2
        return 1
    fi

    if [ ! -f "$METADATA_LOG" ]; then
        echo "No metadata file found at: $METADATA_LOG"
        echo "Total items: 0"
        echo "Total size: 0B"
        return 1
    fi

    local max_mb=1024
    if [ -f "$CONFIG" ]; then
        val=$(awk -F= '/^MAX_SIZE_MB=/ {print $2; exit}' "$CONFIG" 2>/dev/null)
        if [ -n "$val" ] && [[ "$val" =~ ^[0-9]+$ ]]; then
            max_mb=$val
        fi
    fi
    local quota_bytes=$(( max_mb * 1024 * 1024 ))

    # Variables for the counters
    local total=0
    local total_bytes=0
    local files=0
    local dirs=0
    local -a keys=()
    local oldest_ts=0
    local newest_ts=0

    # Cohesive metadata reading
    while IFS= read -r line || [ -n "$line" ]; do
        [ -z "$line" ] && continue
        case "$line" in 
            ID* ) continue;;
        esac

        # expected format: ID|ORIGINAL_NAME|ORIGINAL_PATH|DELETION_DATE|FILE_SIZE|FILE_TYPE|PERMISSIONS|OWNER
        IFS='|' read -r id name orig_path del_date size ftype perms owner <<< "$line"
        [ -z "$id" ] && continue

        total=$((total + 1))
        size=${size:-0}

        # Ensuring size is numeric
        if ! [[ "$size" =~ ^[0-9]+$ ]]; then
            size=0
        fi
        total_bytes=$(( total_bytes + size ))
        
        if [ "$ftype" = "directory" ]; then
            dirs=$((dirs + 1))
        else    
            files=$((files + 1))
        fi

        # Build sortable key YYYYMMDDHHMMSS and keep ISO form if del_date matches expected DDMMYYYYHHMMSS
        if [[ $del_date =~ ^[0-9]{14}$ ]]; then
            key="${del_date:4:4}${del_date:2:2}${del_date:0:2}${del_date:8:2}${del_date:10:2}${del_date:12:2}"
            iso="${del_date:4:4}-${del_date:2:2}-${del_date:0:2} ${del_date:8:2}:${del_date:10:2}:${del_date:12:2}"
            keys+=( "${key}|${iso}|${name}" )
        fi

    done < "$METADATA_LOG"


    if [ ${#keys[@]} -gt 0 ]; then  
        #fixed to show name not date
        IFS=$'\n' sorted=($(printf "%s\n" "${keys[@]}" | sort))
        oldest_name="${sorted[0]#*|}" #i have to include the | because it wasnt stripping away the | so it was giving an error
        newest_name="${sorted[$(( ${#sorted[@]} - 1 ))]#*|}" #-1 (array starts at 0)
    fi
        
    if [ "$total" -eq 0 ]; then
        echo "Total items: 0"
        echo "Total size: 0B (0%)"
        echo "Files: 0  Directories: 0"
        echo "Oldest item: N/A"
        echo "Newest item: N/A"
        echo "Average size: 0B"
        return 0
    fi

    local percent=0
    if [ "$quota_bytes" -gt 0 ]; then
        percent=$(echo "scale=2; ($total_bytes*100)/$quota_bytes" | bc)
    fi
    local avg=$(( total_bytes / total ))

    echo "Total items: $total"
    printf "Total size: %s (%d bytes) — quota: %dMB (%s%%)\n" "$(human_readable "$total_bytes")" "$total_bytes" "$max_mb" "$percent"
    echo "Files: $files  Directories: $dirs"
    [ -n "$oldest_ts" ] && echo "Oldest item: $oldest_name" || echo "Oldest item: N/A"
    [ -n "$newest_ts" ] && echo "Newest item: $newest_name" || echo "Newest item: N/A"
    printf "Average item size: %s (%d bytes)\n" "$(human_readable "$avg")" "$avg"

    return 0
}


function autocleanup(){
    # auto_cleanup
    # Automatically removes items from the recycle bin that are older than the configured retention period (30 days as per the config file).
    #
    # Args: none
    # Returns: 0 on success, 1 if not initialized or on error
    # Example: cleanup

    set_recyclebin_vars

    if [ -z "$RECYCLE_BIN" ] || [ -z "$METADATA_LOG" ] || [ -z "$CONFIG" ]; then
        echo "Recycle bin variables are not initialized. Call initialize_recyclebin first." >&2
        return 1
    fi

    if [ ! -f "$METADATA_LOG" ]; then
        echo "No metadata file found at: $METADATA_LOG"
        return 1
    fi

    local retention_days=30 # fallback default
    if [ -f "$CONFIG" ]; then
        val=$(awk -F= '/RETENTION_DAYS=/ {print $2; exit}' "$CONFIG" 2>/dev/null)
        if [ -n "$val" ] && [[ "$val" =~ ^[0-9]+$ ]]; then
            retention_days="$val"
        fi
    fi

    # Calculate threshold date as YYYYMMDDHHMMSS for easy comparison
    local threshold_date
    threshold_date=$(date -d "-${retention_days} days" "+%Y%m%d%H%M%S") || {
        echo "ERROR: date required (date -d)"
        return 1
    }

    local processed=0
    local removed_count=0
    local bytes_removed=0
    local -a ids_removed=()
    local -a failed=()

    while IFS= read -r line || [ -n "$line" ]; do 
        [ -z "$line" ] && continue
        case "$line" in
            ID* ) continue ;;
        esac
        # expected format: ID|ORIGINAL_NAME|ORIGINAL_PATH|DELETION_DATE|FILE_SIZE|FILE_TYPE|PERMISSIONS|OWNER
        IFS='|' read -r id name orig_path del_date size ftype perms owner <<< "$line"
        [ -z "$id" ] && continue
        processed=$((processed + 1))

        # Parse deletion date to sortable YYYYMMDDHHMMSS
        local item_date
        if [[ $del_date =~ ^[0-9]{14}$ ]]; then
            item_date="${del_date:4:4}${del_date:2:2}${del_date:0:2}${del_date:8:2}${del_date:10:2}${del_date:12:2}"
        else
            continue
        fi

        # Only remove if older than threshold
        if [[ "$item_date" < "$threshold_date" ]]; then
            # Reconstruct recycle_path
            recycle_path="$(ls "$FILES_DIR"/${name}_${id}* 2>/dev/null | head -n 1)"
            # Calculate size before removal
            local size_bytes="${size:-0}"
            if [ -n "$recycle_path" ] && [ -e "$recycle_path" ]; then
                if [ -d "$recycle_path" ]; then
                    if du -sb "$recycle_path" >/dev/null 2>&1; then
                        size_bytes=$(du -sb "$recycle_path" | cut -f1)
                    else
                        kb=$(du -s "$recycle_path" 2>/dev/null | cut -f1)
                        kb=${kb:-0}
                        size_bytes=$((kb * 1024))
                    fi
                else
                    size_bytes=$(stat -c '%s' "$recycle_path" 2>/dev/null || echo 0)
                fi
            fi
            # Attempt removal
            if [ -n "$recycle_path" ] && [ -e "$recycle_path" ]; then
                if rm -rf -- "$recycle_path"; then
                    removed_count=$((removed_count + 1))
                    bytes_removed=$((bytes_removed + size_bytes))
                    ids_removed+=( "$id" )
                else
                    failed+=( "$id|$recycle_path|remove_failed" )
                fi
            else
                ids_removed+=( "$id" )
                removed_count=$((removed_count + 1))
                bytes_removed=$((bytes_removed + size_bytes))
            fi
        fi
    done < "$METADATA_LOG"

    # updating the metadata log file
    if [ ${#ids_removed[@]} -gt 0 ]; then
        tmpf="$(mktemp "${RECYCLE_BIN:-/tmp}/cleanup.XXXXXXXX")" || tmpf="/tmp/cleanup.$$"
        while IFS= read -r line || [ -n "$line" ]; do
            [ -z "$line" ] && continue
            case "$line" in ID* ) echo "$line" >> "$tmpf"; continue ;; esac
            IFS='|' read -r id rest <<< "$line"
            local skip=0
            for u in "${ids_removed[@]}"; do
                if [ "$u" = "$id" ]; then skip=1; break; fi
            done
            if [ "$skip" -eq 0 ]; then echo "$line" >> "$tmpf"; fi
        done < "$METADATA_LOG"
        if ! mv "$tmpf" "$METADATA_LOG" 2>/dev/null; then 
            echo "Failed to update metadata file"
            [ -f "$tmpf" ] && rm "$tmpf"
        fi
    fi

    # summary
    echo "Auto-cleanup summary (older than ${retention_days} days):"
    echo "  Items scanned: $processed"
    echo "  Items removed: $removed_count"
    echo "  Space freed: $(human_readable "$bytes_removed") ($bytes_removed bytes)"
    
}

function check_quota(){ 
    # check_quota
    # Checks if the recycle bin has reached its configured quota, and calls autocleanup if necessary.
    #
    # Args: none
    # Returns: 0 on success, 1 if not initialized or on error
    # Example: quota
    
    set_recyclebin_vars

    if [ -z "$CONFIG" ] || [ -z "$RECYCLE_BIN" ] || [ -z "$METADATA_LOG" ]; then 
        echo "Recycle bin variables are not initialized. Call initialize_recyclebin first." >&2
        return 1
    fi
    
    local max_mb=1024 #defaults to 1024
    if [ -f "$CONFIG" ]; then 
        val=$(awk -F= '/MAX_SIZE_MB=/ {print $2; exit}' "$CONFIG" 2>/dev/null)
        if [ -n "$val" ] && [[ "$val" =~ ^[0-9]+$ ]]; then
            max_mb=$val
        fi
    fi

    local max_bytes=$((max_mb * 1024 * 1024))

    if [ ! -f "$METADATA_LOG" ]; then
        echo "No metadata file found at: $METADATA_LOG"
        return 1
    fi

    local total_size=0
    while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in
            ID* ) continue ;;
        esac
        # expected format: ID|ORIGINAL_NAME|ORIGINAL_PATH|DELETION_DATE|FILE_SIZE|FILE_TYPE|PERMISSIONS|OWNER
        IFS='|' read -r id name orig_path del_date size ftype perms owner <<< "$line"
        [ -z "$id" ] && continue
        #validating size and defaulting to 0
        if ! [[ "$size" =~ ^[0-9]+$ ]]; then
            size=0
        fi
        total_size=$((total_size + size))
    done < "$METADATA_LOG"

    #checking if there is a need to call auto cleanup
    if [ "$total_size" -ge "$max_bytes" ]; then
        echo "Reached maximum capacity... calling autocleanup"
        autocleanup
    else
        echo "Recycle bin quota not reached, feel free to keep using"
    fi
}


function preview_file() {
    #preview_file
    #Shows first 10 lines of a text files and displays file type information for binary files
    #
    #Args
    # $1:ID of the file you wish to preview
    # Returns: 0 on success, 1 if not initialized or on error
    #Example
    #preview 1234596


    set_recyclebin_vars

    local file_id="$1"
    
    while IFS= read -r line || [ -n "$line" ]; do
            #skip empty lines
            [ -z "$line" ] && continue

            #skip the header
            case "$line" in
                ID* ) continue ;;
            esac

            # expected format from the delete_file function:
            # id|name|orig_path|del_date|size|ftype|perms|owner
            IFS='|' read -r id name orig_path del_date size ftype perms owner <<< "$line"
            if [[ "$id" == "$file_id" ]]; then
                file_path="$(ls $FILES_DIR/${name}_${id}* 2>/dev/null | head -n 1)" #finding the first file that in files dir that matches that name
                file_id="$id" #re using the logic of only having 8 digits in the id
                # only include items that currently exist in the recycle bin
                [ -e "$file_path" ] || continue
        

                # Verificar o tipo de ficheiro (texto ou binário)
                local file_type=$(file -b --mime-type "$file_path")

                echo "-----------------------------------"
                echo "Pré-visualização do ficheiro: $file_id"
                echo "Tipo: $file_type"
                echo "-----------------------------------"

                # Se for texto, mostrar as 10 primeiras linhas
                if [[ "$file_type" == text/* ]]; then
                echo "Primeiras 10 linhas:"
                echo "-----------------------------------"
                head -n 10 "$file_path"
                echo "-----------------------------------"
                else
                echo "Ficheiro binário — pré-visualização não disponível."
                fi
            fi
    done < "$METADATA_LOG"
    return 0
}

function display_help(){ #using teacher suggestion(cat << EOF)

    local script_name="$(basename "$0")"
    local recycle_dir="${RECYCLE_BIN:-$HOME/.recycle_bin}"
    local metadata_file="${METADATA_LOG:-$recycle_dir/metadata.log}"
    local config_file="${CONFIG:-$recycle_dir/config}"
    local log_file="${LOG:-$recycle_dir/recyclebin.log}"

    cat <<-EOF

    Linux Recycle Bin - Usage Guide

    Usage: 
        ./recyclebin.sh <command> [options] [arguments]

    Commands:
        initialize
            Initialize the recycle bin dir structure and the files
            Example: 
                ./recyclebin.sh initialize
        
        delete <paths...>
            Move one or more files to the recycling bin
            Example: 
                ./recyclebin.sh delete /path/to/file.txt /path/to/dir
        
        list [--sort <date|name|size>] [--detailed]
            List recycled items. --sort is set to date by default (newest file firstr)
            --detailed shows full metadata
            Example: 
                ./recyclebin.sh list
                ./recyclebin.sh list --detailed
                ./recyclebin.sh list --sort name
                ./recyclebin.sh list --sort name --detailed

        restore <UUID-or-short-id-or-filename>
            Restores an item, identifying them through ID (may use the full ID or just the 8 first chars (created a shorter id for convinience)) or filename 
            Example:
                ./recycle_bin.sh restore 1696234567_abc123
                ./recycle_bin.sh restore myfile.txt
        search <pattern> [-i | --ignore-case]
            Searches for items in the bin through the user defined pattern that can be 
            a basename or original path. Supports '*' wildcards
            Example:
                ./recycle_bin.sh search "report"
                ./recycle_bin.sh search "*.pdf"
        
        empty [--force] [<UUID-or-short-id-or-filename>]
            Permanently delete items from the recycle bin. Without an id deletes all items.
            ./recycle_bin.sh empty
            ./recycle_bin.sh empty 1696234567_abc123
            ./recycle_bin.sh empty --force
                
        help, -h, --help
            Shows this help text.
            Example:
                ./recycle_bin.sh help
                ./recycle_bin.sh --help
                ./recycle_bin.sh -h
        
    Extra commands:

        statistics
            Shows total number of files/storage used,  does a type breakdown (file or dir), 
            shows oldest and newest items and the file size aswell

            Example:
               ./recycle_bin.sh statistics
        
        cleanup
            Removes files older than RETENTION_DAYS

        quota
            Checks MAX_SIZE_MB quota; optionally triggers autocleanup.
            Example:
               ./recycle_bin.sh quota
        
        preview <ID>
            Prints first 10 lines for text files or shows file type for binaries.
            Example:
                ./recycle_bin.sh preview 9f8a7b6c
            
    GLOBAL OPTIONS 
        --detailed              Detailed view for 'list'.
        --force                 Skip confirmation for destructive actions (e.g., 'empty').
        --case-insensitive      Case-insensitive search (for 'search').
        -h, --help              Show this help.


    Files & configuration (defaults):
        Recycle bin directory:    $recycle_dir
        Metadata log:             $metadata_file
        Config file:              $config_file
        Log file:                 $log_file

    Config file variables:
        MAX_SIZE_MB    Maximum allowed size of recycle bin in megabytes (default: 1024)
        RETENTION_DAYS Number of days to keep items before purging (default: 30)

    Metadata format (pipe '|' delimited):
        ID|ORIGINAL_NAME|ORIGINAL_PATH|DELETION_DATE|FILE_SIZE|FILE_TYPE|PERMISSIONS|OWNER


EOF
    return 0
}
main() {
    # Initialize recycle bin (only for commands that need it)
    cmd="$1"
    case "$cmd" in
        initialize)
            initialize_recyclebin
            ;;
        delete)
            initialize_recyclebin || exit 1
            shift
            delete_file "$@"
            ;;
        list)
            initialize_recyclebin || exit 1
            shift
            list_recycled "$@"
            ;;
        restore)
            initialize_recyclebin || exit 1
            shift
            restore_file "$@"
            ;;
        search)
            initialize_recyclebin || exit 1
            shift
            search_recycled "$@"
            ;;
        empty)
            initialize_recyclebin || exit 1
            shift
            empty_recyclebin "$@"
            ;;
        statistics)
            initialize_recyclebin || exit 1
            show_statistics
            ;;
        cleanup)
            initialize_recyclebin || exit 1
            autocleanup
            ;;
        quota)
            initialize_recyclebin || exit 1
            check_quota
            ;;
        preview)
            initialize_recyclebin || exit 1
            shift
            preview_file "$1"
            
            ;;
        help|--help|-h)
            display_help
            ;;
        *)
            echo "Invalid option: '$cmd'. Use 'help' for usage information."
            exit 1
            ;;
    esac
}

# Execute main function with all arguments
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

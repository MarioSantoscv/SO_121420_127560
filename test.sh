function delete_file(){ 
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
        echo "usage: recycle_bin.sh delete <file_or_folder>"
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
                size=$(du -sb "$path" | cut -f1) #cut gets me the first field which is the size
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
           
            echo "$uuid_str|$base_name|$abs_path|$ts|$size|$ftype|$perms|$owner" >> "$METADATA_LOG" || \
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
                shift 2 
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

        # Use full UUID for lookup, not just the short
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

        
        id_short="${id:0:8}"   # only done for display
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

    # choose sort option (date: newest last thats why i put the r flag for reverse order, the n flag is for numeric so the size is done largest first)
    case "$sort_by" in
        name) sort_args=(-t'|' -k2,2) ;;      #-k, --key=KEYDEF          sort via a key; KEYDEF gives location and type     
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
    #   restore_file f5bbd0c4-6f48-4bbd-bd8d-6bd9b9b4bfa4
    #   restore_file "my file with spaces.txt"

    set_recyclebin_vars

    # Helper to trim whitespace
    trim() { echo "$1" | awk '{$1=$1;print}'; }

    # Accept full argument (with spaces)
    local lookup="$(trim "$*")"
    local matches=()
    local idx=0

    if [ -z "$lookup" ]; then
        echo "Usage: recycle_bin.sh restore <UUID-or-short-id-or-filename>"
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

        [ -z "$id" ] && continue
        [ -z "$recycle_path" ] && continue

        # Matching logic
        
        if [ "$lookup" = "$id" ] || [[ "$id" == "$lookup"* ]] || [ "$lookup" = "$base_name" ] || [ "$lookup" = "$orig_path" ] || [ "$lookup" = "$name" ]; then
            if [ "$ftype" = "directory" ]; then
                matches+=("$line")
            elif [ "$ftype" = "file" ]; then
                matches+=("$line")
            fi
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

    if [ ! -w "$dest_parent" ]; then 
        echo "Error: Parent directory '$dest_parent' is not writable. Restore aborted."
        return 1
    fi

    #added awk to remove weird output
    avail_kb=$(df -P -k "$dest_parent" 2>/dev/null |awk 'NR==2 {print $4}')
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
        if [ -n "$perms" ]; then
            chmod "$perms" "$dest" 2>/dev/null || echo "Warning: chmod failed for $dest"
        fi

        tmpf="/tmp/restore.$$"
        while IFS= read -r line || [ -n "$line" ]; do
            [ -z "$line" ] && continue
            case "$line" in ID* ) echo "$line" >> "$tmpf"; continue ;; esac
            IFS='|' read -r entry_id rest <<< "$line"
            skip=0
            if [ "$entry_id" = "$id" ]; then
                skip=1
            fi
            if [ "$skip" -eq 0 ]; then
                echo "$line" >> "$tmpf"
            fi
        done < "$METADATA_LOG"
        if ! mv "$tmpf" "$METADATA_LOG" 2>/dev/null; then 
            echo "Warning: failed to update metadata log; metadata may still reference the restored item."
            [ -f "$tmpf" ] && rm -f "$tmpf"
        fi

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
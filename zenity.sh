#!/bin/bash
# Author: Mario Santos (127560), Kelvin Loforte (121420)
# Date: 2025-10-31

source ./recycle_bin.sh

check_initialized() {
    if [ ! -d "$HOME/.recycle_bin/files" ] || [ ! -f "$HOME/.recycle_bin/metadata.log" ]; then
        initialize_recyclebin
        if [ ! -d "$HOME/.recycle_bin/files" ] || [ ! -f "$HOME/.recycle_bin/metadata.log" ]; then
            zenity --warning \
            --title="Recycle Bin Not Initialized" \
            --text="Recycle bin could not be initialized. Please run 'Initialize Bin' manually."
            return 1
        fi
    fi
    return 0
}

while true; do 
    action=$(zenity --list \
        --title="Linux Recycle Bin" --width=700 --height=400 \
        --column="Features"  \
        "Delete File(s)" \
        "List Recycled" \
        "Restore Item" \
        "Search" \
        "Empty Bin" \
        "Show Statistics" \
        "Cleanup" \
        "Check Quota" \
        "Preview File" \
        "Help/About"
    )

    #checking if user closed the window or choose cancel
    [ -z "$action" ] && break

    case "$action" in
        "Delete File(s)") #works
            check_initialized || continue
            files=$(zenity --file-selection --multiple --separator="|" --title="Select files to be recycled")
            [ -z "$files" ] && continue
            IFS="|" read -ra filelist <<< "$files"
            output=$(delete_file "${filelist[@]}")
            zenity --info --text="$output"
            ;;
        "List Recycled") #fixed the now text showing bug(--text expects single line output while the list is multiple line so we store the text in a tmp file and display the file instead)
            check_initialized || continue
            output=$(list_recycled)
            tmpfile=$(mktemp)
            echo "$output" > "$tmpfile"
            zenity --text-info --title="Recycled items" --width=1000 --height=800 --filename="$tmpfile"
            rm -f "$tmpfile"
            ;;
        "Restore Item") #works
            check_initialized || continue
            id=$(zenity --entry --title="Restore file" --width=700 --height=400 --text="Please enter the UUID or short ID or filename of the file you want to restore: ")
            [ -z "$id" ] && continue
            output=$(restore_file "$id")
            zenity --info --text="$output"
            ;;
        "Search")
            check_initialized || continue
            pattern=$(zenity --entry --title="Search for a file" --width=700 --height=400 --text="Enter the search pattern (enter -i or --ignore-case for case insensitive): ")
            [ -z "$pattern" ] && continue
            output=$(search_recycled "$pattern")
            tmpfile=$(mktemp)
            echo "$output" > "$tmpfile"
            zenity --text-info --title="Search Results" --width=700 --height=400 --filename="$tmpfile"
            rm -f "$tmpfile"
            ;;
        "Empty Bin") #action is needed to check if u want to empty the whole thing or not
            check_initialized || continue
            action=$(zenity --list --width=700 --height=400\
                --title="Select Empty mode" \
                --column="Action" \
                "Delete ALL files" \
                "Delete a single file"
            ) || continue 
            [ -z "$action" ] && continue
            if [ "$action" = "Delete ALL files" ]; then
                zenity --question --title="Confirm delete all" \
                    --text="Are you sure you want to delete every item from the recycle bin?"
                if [ $? -eq 0 ]; then
                    output=$(empty_recyclebin --force)
                    zenity --info --text="$output"
                fi
            else
                id=$(zenity --entry --title="Delete Specific Item" --text="Enter the ID or name of the file you want to delete: ")
                [ -z "$id" ] && continue
                zenity --question --text="Are you sure you want to delete '$id' from the Recycle Bin?"
                if [ $? -eq 0 ]; then
                    output=$(empty_recyclebin --force "$id")
                    zenity --info --text="$output"
                fi
            fi
            ;;
        "Show Statistics") #works
            check_initialized || continue
            output=$(show_statistics)
            zenity --info --title="Recycle Bin Statistics" --width=700 --height=400 --text="$output"
            ;;
        "Cleanup")
            check_initialized || continue
            output=$(autocleanup)
            zenity --info --title="Auto Cleanup" --text="$output"
            ;;
        "Check Quota") #works
            check_initialized || continue
            output=$(check_quota)
            zenity --info --title="Quota Check" --text="$output"
            ;;
        "Preview File")
            check_initialized || continue
            id=$(zenity --entry --title="Preview File" --width=700 --height=400 --text="Please enter the UUID of the file you want to preview: ")
            [ -z "$id" ] && continue
            output=$(preview_file "$id")
            tmpfile=$(mktemp)
            echo "$output" > "$tmpfile"
            zenity --text-info --title="Preview" --width=700 --height=400 --filename="$tmpfile"
            rm -f "$tmpfile"
            ;;
        "Help/About")
            output=$(display_help)
            tmpfile=$(mktemp)
            echo "$output" > "$tmpfile"
            zenity --text-info --title="Help / About" --width=700 --height=500 --filename="$tmpfile"
            rm -f "$tmpfile"
            ;;
        *)
            break
            ;;
    esac
done
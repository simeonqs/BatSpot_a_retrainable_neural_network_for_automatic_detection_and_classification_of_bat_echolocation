#!/bin/bash

# Ensure arguments are provided
if [[ -z "$1" || -z "$2" ]]; then
    echo "Usage: $0 <temp_dir> <batch_id>"
    exit 1
fi

# Load relevant modules and only report errors to main output (>/dev/null 2>&1)
module use /appl/local/csc/modulefiles/ >/dev/null 2>&1
module load pytorch >/dev/null 2>&1

# echo "[RCC DEBUG] [$(date '+%Y-%m-%d %H:%M:%S')] Starting run create clips."

# Assign arguments to variables and add local variables
temp_dir="$1"
batch_id="$2"
predict_dir="$temp_dir/predictions"
selection_table_dir="$temp_dir/selection_tables"

# Ensure directories exist
# if not (!) predict_dir is a directory (-d) exit with error or (||) same for 
# selection_table_dir
if [[ ! -d "$predict_dir" || ! -d "$selection_table_dir" ]]; then
    echo "[RCC ERROR] [$(date '+%Y-%m-%d %H:%M:%S')] One or both required directories do not exist."
    exit 1
fi

# List all predict files and selection tables, removing extensions
predict_files=()
# an almost normal for loop running over all file swith the _predict_output.log
# extension
for predict_file in "$predict_dir"/*_predict_output.log; do
    # append the basename of the file without extension to the array
    predict_files+=("$(basename "$predict_file" "_predict_output.log")")
done

# Same thing for the selection tables
selection_tables=()
for table_file in "$selection_table_dir"/*_predict_output.log.annotation.result.txt; do
    selection_tables+=("$(basename "$table_file" "_predict_output.log.annotation.result.txt")")
done

# Report any predict file for which there is no selection table
missing_tables=0
# run accross all prediction files
for predict in "${predict_files[@]}"; do
    # if the prediction file is not (!) in (=~) the selection table array then warn
    # for that table
    if [[ ! " ${selection_tables[*]} " =~ " ${predict} " ]]; then
        echo "[RCC WARNING] [$(date '+%Y-%m-%d %H:%M:%S')] No selection table found for predict file: ${predict}_predict_output.log"
        missing_tables=1
    fi
done

# If any tables are missing (-eq 1: equal to one) exit with error
if [[ "$missing_tables" -eq 1 ]]; then
    echo "[RCC ERROR] [$(date '+%Y-%m-%d %H:%M:%S')] Missing selection tables for some predict files. Exiting."
    exit 1
fi

# Define the temporary Python script path
temp_script="$temp_dir/temp_create_clips_$batch_id.py"

# Ensure the original Python script exists
if [[ ! -f create_clips.py ]]; then
    echo "[RCC ERROR] [$(date '+%Y-%m-%d %H:%M:%S')] Original create_clips.py script not found."
    exit 1
fi

# Copy the original Python script to the temporary directory, if fails (||) exit
# with error
cp create_clips.py "$temp_script" || { echo "Failed to copy create_clips.py"; exit 1; }

# Update paths in the temporary Python script, basically replaces the placeholders
# with the correcth path specifications: edit file (sed) in place (-i) and 
# substitute (s|) the place holder with the following line (|) for the temp_script file
sed -i "s|path_detections = ''|path_detections = '$selection_table_dir'|" "$temp_script"
sed -i "s|path_audio = ''|path_audio = '$temp_dir/audio'|" "$temp_script"
sed -i "s|path_out = ''|path_out = '$temp_dir/clips'|" "$temp_script"

# Run the temporary Python script and throw error if it fails
if ! python "$temp_script"; then
    echo "[RCC ERROR] [$(date '+%Y-%m-%d %H:%M:%S')] Failed to execute the Python script."
    rm "$temp_script"  # Clean up in case of failure
    exit 1
fi

# Clean up: delete the temporary script
rm "$temp_script"
# echo "[RCC DEBUG] [$(date '+%Y-%m-%d %H:%M:%S')] Temporary script removed successfully."

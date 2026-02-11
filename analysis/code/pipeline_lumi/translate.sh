#!/bin/bash

# Load relevant modules and only report errors to main output (>/dev/null 2>&1)
module use /appl/local/csc/modulefiles/ >/dev/null 2>&1
module load pytorch >/dev/null 2>&1

# Ensure arguments are provided
# if number arguments provided ($#) is not equal (-ne) 2 exit with error
if [[ $# -ne 2 ]]; then
    echo "Usage: $0 <temp_dir> <batch_id>"
    exit 1
fi

# Assign arguments to variables and add local variables
temp_dir="$1"
batch_id="$2"
config_template="config_translate"
trans_script="/scratch/project_465001446/screening_option/ANIMAL-SPOT-master/EVALUATION/start_evaluation.py"

# Ensure temp_dir exists
# if not (!) temp_dir is a directory (-d) exit with error
if [[ ! -d "$temp_dir" ]]; then
    echo "[T   ERROR] [$(date '+%Y-%m-%d %H:%M:%S')] Directory '$temp_dir' does not exist."
    exit 1
fi

# Create a temporary config file
# create path for the file
temp_config_translate="$temp_dir/temp_config_translate_$batch_id"
# copy the original configuration file to temp_config_translate and exit with error
# if it fails
if ! cp "$config_template" "$temp_config_translate"; then
    echo "[T   ERROR] [$(date '+%Y-%m-%d %H:%M:%S')] Failed to copy the config template."
    exit 1
fi

# Add the required lines to the temporary config file
# {} is a block of commands to be executed sequentially with "$temp_config_translate"
# appended (>>) to the end of each command; \" is used to write ", which would other-
# wise have ended the echo string
{
    echo "prediction_dir=$temp_dir/predictions"
    echo "output_dir=$temp_dir/selection_tables"
} >> "$temp_config_translate"

# Call the Python script with the temporary config file
# the output it written to a temporary output file, which can be used if something 
# inside Animal Spot goes wrong; if the call fails, exit with error
if ! python3 "$trans_script" "$temp_config_translate"> "$temp_dir/output_translate_$batch_id.txt" 2>&1; then
    echo "[T   ERROR] [$(date '+%Y-%m-%d %H:%M:%S')] Python script execution failed."
    rm "$temp_config_translate"  # Ensure cleanup even if the script fails
    exit 1
fi

# Remove the temporary config file after use
rm "$temp_config_translate"
# echo "[T   DEBUG] [$(date '+%Y-%m-%d %H:%M:%S')] Temporary config file removed successfully."

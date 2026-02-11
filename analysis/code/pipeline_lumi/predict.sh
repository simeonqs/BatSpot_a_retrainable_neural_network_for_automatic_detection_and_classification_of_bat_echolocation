#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e  

# Load relevant modules and only report errors to main output (>/dev/null 2>&1)
module use /appl/local/csc/modulefiles/ >/dev/null 2>&1
module load pytorch >/dev/null 2>&1

# Ensure arguments are provided
# if number arguments provided ($#) is not equal (-ne) 2 exit with error
if [[ $# -ne 2 ]]; then
    echo "[Pr  ERROR] [$(date '+%Y-%m-%d %H:%M:%S')] Usage: $0 <temp_dir> <batch_id>"
    exit 1
fi

# Set local variables
temp_dir="$1" # comes from the arguments in the bash call
batch_id="$2" # comes from the arguments in the bash call
config_template="config_predict"

# Ensure temp_dir exists
# if not (!) temp_dir is a directory (-d) exit with error
if [[ ! -d "$temp_dir" ]]; then
    echo "[Pr  ERROR] [$(date '+%Y-%m-%d %H:%M:%S')] Directory '$temp_dir' does not exist."
    exit 1
fi

# Create temp config file name for this batch
temp_config_predict="$temp_dir/temp_config_predict_$batch_id"

# echo "[Pr  DEBUG] [$(date '+%Y-%m-%d %H:%M:%S')] Creating temporary config file: $temp_config_predict"

# Copy the original configuration file to temp_config_predict and exit with error
# if it fails
if ! cp "$config_template" "$temp_config_predict"; then
    echo "[Pr  ERROR] [$(date '+%Y-%m-%d %H:%M:%S')] Failed to copy config file. Exiting."
    exit 1
fi

# Add the required lines to temp_config_predict
# {} is a block of commands to be executed sequentially with "$temp_config_predict"
# appended (>>) to the end of each command; \" is used to write ", which would other-
# wise have ended the echo string
{
    echo "log_dir=\"$temp_dir/predictions\""
    echo "output_dir=\"$temp_dir/predictions\""
    echo "input_file=\"$temp_dir/audio\""
} >> "$temp_config_predict"

# echo "[Pr  DEBUG] [$(date '+%Y-%m-%d %H:%M:%S')] Config file updated."

# Set directory to the PREDICTION folder and exit with error if it fails.
if ! cd "/scratch/project_465001446/screening_option/ANIMAL-SPOT-master/PREDICTION"; then
    echo "[Pr  ERROR] [$(date '+%Y-%m-%d %H:%M:%S')] Failed to change directory. Exiting."
    exit 1
fi

# Call the Python script with the temporary config file
# the output it written to a temporary output file, which can be used if something 
# inside Animal Spot goes wrong; if the call fails, exit with error
echo "[Pr  DEBUG] [$(date '+%Y-%m-%d %H:%M:%S')] Running prediction."
if ! python3 start_prediction.py "$temp_config_predict" > "$temp_dir/output_predict_$batch_id.txt" 2>&1; then
    echo "[Pr  ERROR] [$(date '+%Y-%m-%d %H:%M:%S')] Prediction script failed. Exiting."
    rm "$temp_config_predict"  # Ensure cleanup even if the script fails
    exit 1
fi

echo "[Pr  DEBUG] [$(date '+%Y-%m-%d %H:%M:%S')] Prediction completed successfully."

# Cleanup the temporary config file
rm "$temp_config_predict"
# echo "[Pr  DEBUG] [$(date '+%Y-%m-%d %H:%M:%S')] Temporary config file removed."

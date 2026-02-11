#!/bin/bash -l

# Ensures safe execution
set -euo pipefail  

# Check if local directory argument is provided
# if number arguments provided ($#) is not equal (-ne) 3 exit with error
if [ $# -ne 3 ]; then
  echo "Usage: $0 <deployment_dir> <database_directory> <deployment>"
  exit 1
fi

# Arguments from the bash call
deployment_dir="$1"
database_dir="$2"
deployment="$3"
timeout=480000 # timeout for sqlite in milliseconds

# Variables
batch_count=16  # number of parallel batch scripts

# Ensure the local base directory exists
mkdir -p "$deployment_dir/audio_data" # create if not exists (-p)
echo "[D   INFO] [$(date '+%Y-%m-%d %H:%M:%S')] Created directory: $deployment_dir/audio_data"

# Fetch file paths from the database and create a temporary file for splitting
temp_list=$(mktemp) # creates a temporary file
# reads the database, selects file_path and new_file_name for the current deployment
# where processing == 0, then generates a curl command for each file to download it
# via the ERDA share link, writing the commands to temp_list
sqlite3 "$database_dir" "PRAGMA busy_timeout = $timeout; \
  SELECT file_path, new_file_name FROM audio_files \
  WHERE deployment = '$deployment' AND processing = 0" \
| tail -n +2 | awk -F'|' -v outdir="$deployment_dir/audio_data" -v link="im6sJ0HiMn" \
'{gsub(/^\/+/, "", $1); print "curl -s -L -C - -o \"" outdir "/" $2 "\" \"https://anon.erda.au.dk/share_redirect/" link "/screening_option2_data/data_for_aspot/" $1 "\""}' \
> "$temp_list"

# Debug: print the first 10 curl commands and stop the script
echo "[D   DEBUG] First 10 curl commands generated:"
head -n 10 "$temp_list"

# Count lines and determine batch sizes
# needed to divide all the downloads across batch files for parallel execution
total_lines=$(wc -l < "$temp_list") # number of curl commands
lines_per_batch=$((total_lines / batch_count)) # integer division
remainder=$((total_lines % batch_count)) # leftover commands

# Split into batch files
echo "[D   DEBUG] [$(date '+%Y-%m-%d %H:%M:%S')] Total lines: $total_lines"
batch_files=() # array to store batch file paths
start=1
for i in $(seq 1 "$batch_count"); do
  batch_file=$(mktemp) # create temp file for this batch
  batch_files+=("$batch_file") # add it to the array

  # Determine the range of lines for this batch
  if [ "$i" -le "$remainder" ]; then
    end=$((start + lines_per_batch))
  else
    end=$((start + lines_per_batch - 1))
  fi

  # Append the correct range of curl commands
  # write the lines from start until and including end from temp_list to current batch file
  sed -n "${start},${end}p" "$temp_list" >> "$batch_file"
  lines_batch=$(wc -l < "$batch_file")
  echo "[D   DEBUG] [$(date '+%Y-%m-%d %H:%M:%S')] Lines batch: $lines_batch, start: $start, end: $end"
  start=$((end + 1)) # update start for next loop
done

# Run each batch file in parallel
# Each batch file is executed as a shell script, running all curl commands in it
# Output is discarded (>) to /dev/null
printf "%s\n" "${batch_files[@]}" | xargs -P "$batch_count" -I {} bash {} > /dev/null

# Clean up temporary files
rm -f "$temp_list" "${batch_files[@]}"

echo "[D   INFO] [$(date '+%Y-%m-%d %H:%M:%S')] Download script completed."

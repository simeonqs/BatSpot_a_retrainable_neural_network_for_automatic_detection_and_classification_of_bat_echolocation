#!/bin/bash -l

# Ensures safe execution
set -euo pipefail  

# Check if local directory argument is provided
# if number arguments provided ($#) is not equal (-ne) 4 exit with error
if [ $# -ne 3 ]; then
  echo "Usage: $0 <deployment_dir> <database_directory> <deployment>"
  exit 1
fi

# Come from the arguments in the bash call
deployment_dir="$1"
database_dir="$2"
deployment="$3"
timeout=480000 # timeout for sql in milliseconds

# Variables
remote_server="io.erda.au.dk"
batch_count=2  # number of parallel batch scripts

# Ensure the local base directory exists
mkdir -p "$deployment_dir/audio_data" # create if not exists (-p)
echo "[D   INFO] [$(date '+%Y-%m-%d %H:%M:%S')] Created directory: $deployment_dir/audio_data"

# Fetch file paths from the database and create a temporary file for splitting
temp_list=$(mktemp) # creates a temporary file
# reads the database, selects filepath and new_file_name for the curent deployment
# where processing == 0, this the output is piped (|) into the next step (\ is just
# breaking the code into two lines); in the next step the two outputs are combined 
# an sftp line saying 'get remote_file new_file', which is then written (>) to
# temp_list; so, basically this is writing all the file downloads to the temp file
sqlite3 "$database_dir" "PRAGMA busy_timeout = $timeout; SELECT file_path, new_file_name FROM audio_files WHERE deployment = '$deployment' AND processing = 0" \
| tail -n +2 | awk -F'|' '{print "get \"" $1 "\" \"'"$deployment_dir/audio_data/"'" $2 "\""}' > "$temp_list"


# Count lines and determine batch sizes
# this is needed to devide all the downloads across the batch files, so that the 
# script can run multiple dowloads in parallel
total_lines=$(wc -l < "$temp_list") # word count (wc) lines (-l) in temp_list
lines_per_batch=$((total_lines / batch_count)) # integer devision (e.g., 5/2=2)
remainder=$((total_lines % batch_count)) # remainder of devision (e.g., 5%2=1)

# Split into batch files
echo "[D   DEBUG] [$(date '+%Y-%m-%d %H:%M:%S')] Total lines: $total_lines"
batch_files=() # empty array to store batch files
start=1
for i in $(seq 1 "$batch_count"); do
  batch_file=$(mktemp) # create temp file for this batch
  batch_files+=("$batch_file") # add it to the array

  # Each batch file starts with the `cd` command
  # to download it first needs to set the workind direcotry, write this to 
  # current batch file
  echo "cd /Bat_wo_men/screening_option2_data/data_for_aspot" > "$batch_file"

  # Determine the range of lines for this batch
  # if i is less or equal (-le) than the remainder, set end to start+lines_per_batch
  # else substract one (so the first files get an extra line to make sure the 
  # remainder is also included)
  if [ "$i" -le "$remainder" ]; then
    end=$((start + lines_per_batch))
  else
    end=$((start + lines_per_batch - 1))
  fi

  # Append the correct range of `get` commands
  # write the lines from start until and including end from temp_list to current
  # batch file
  sed -n "${start},${end}p" "$temp_list" >> "$batch_file"
  lines_batch=$(wc -l < "$batch_file")
  echo "[D   DEBUG] [$(date '+%Y-%m-%d %H:%M:%S')] Lines batch: $lines_batch, start: $start, end: $end"
  start=$((end + 1)) # update start for next loop

  # Debugging output
  # echo "[D   DEBUG] [$(date '+%Y-%m-%d %H:%M:%S')] Created batch file $i:"
  # cat "$batch_file"
done

# Run each batch file in parallel with its own sftp session
# echo "[D   INFO] [$(date '+%Y-%m-%d %H:%M:%S')] Starting parallel SFTP sessions..."
# run each batch file; printf prints each entry on a new line; batch_files[@] returns
# all the batch_files in the array, this is then piped (|) to xargs, which runs 
# batch_count processes in parallel (-P) and uses the lines from before the pipe (-I)
# to run an sftp session on the batchfile (-b), basically starting an sftp session
# on the remote_server and then executing all the lines in the batch file; finally
# all output from the sessions is not displayed, but written (>) to /dev/null (discarded)
printf "%s\n" "${batch_files[@]}" | xargs -P "$batch_count" -I {} sftp -b {} "$remote_server" > /dev/null

# Clean up (remove without warnings) the temp_list and all files in the batch
# files array
rm -f "$temp_list" "${batch_files[@]}"

echo "[D   INFO] [$(date '+%Y-%m-%d %H:%M:%S')] Download script completed."

#!/bin/bash -l
#SBATCH --job-name=parent
#SBATCH --output=log_p.o%j
#SBATCH --error=log_p.o%j
#SBATCH --partition=small
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=10
#SBATCH --mem=8G
#SBATCH --time=2-00:00:00
#SBATCH --mail-type=all
#SBATCH --account=project_465001446
#SBATCH --mail-user=simeon_smeele@ecos.au.dk

# Ensure safe execution
set -euo pipefail  

# Load relevant modules and only report errors to main output (>/dev/null 2>&1)
module use /appl/local/csc/modulefiles/ >/dev/null 2>&1
module load LUMI/24.03  partition/C >/dev/null 2>&1
module load SQLite/3.43.1-cpeCray-24.03 >/dev/null 2>&1

# Variables
batch_size=222
max_iterations=1000
iteration=0
timeout=480000 # timeout for sql in milliseconds

echo "[P   INFO] [$(date '+%Y-%m-%d %H:%M:%S')] Starting while loop."

# Run while loop while iteration is less than (-lt) max_iterations
# note the script is also exited if "$count" -eq 0, further down
while [ "$iteration" -lt "$max_iterations" ]; do
    # Check if there are any unprocessed files
    # set the count to the number of entries for the current deployment where 
    # processing is 0
    
    # Set the busy timeout and execute the query
    echo "[P   DEBUG] [$(date '+%Y-%m-%d %H:%M:%S')] Getting count."
    output=$(sqlite3 "$database_dir" "PRAGMA busy_timeout = $timeout; SELECT COUNT(*) FROM audio_files WHERE deployment = '$deployment' AND processing = 0;") || {
        echo "[C   ERROR] [$(date '+%Y-%m-%d %H:%M:%S')] Failed to retrieve count. Exiting."
        exit 1
    }

    # Remove the timeout value from the output
    count=$(echo "$output" | tail -n +2)
    echo "[P   INFO] [$(date '+%Y-%m-%d %H:%M:%S')] Unprocessed files count: $count"

    # Exit the script without error if the count is equal to (-eq) 0 
    if [ "$count" -eq 0 ]; then
        echo "[P   INFO] [$(date '+%Y-%m-%d %H:%M:%S')] No unprocessed files remaining. Exiting parent batch script."
        exit 0
    fi

    # echo "[P   DEBUG] [$(date '+%Y-%m-%d %H:%M:%S')] Generating batch ID."

    # Generate batch ID of 10 random alphanumerics
    # generates 20 random -base64 bytes of data, pipes them (|) to trimming (tr)
    # where everything not (-c) an alphanumeric is deleted (-d), then it takes the 
    # ten first (head) bytes (-c) 
    batch_id=$(openssl rand -base64 20 | tr -dc 'A-Za-z0-9' | head -c 10)

    echo "[P   DEBUG] [$(date '+%Y-%m-%d %H:%M:%S')] Updating database with batch ID: $batch_id."

    # Set batch_id to the generated batch_id and the processing to 1 for the 
    # first batch_size entries of the current deployment where processing == 0 
    echo "[P   DEBUG] [$(date '+%Y-%m-%d %H:%M:%S')] Adding batch_id."
    sqlite3 "$database_dir" "PRAGMA busy_timeout = $timeout; \
                             BEGIN IMMEDIATE TRANSACTION; \
                             UPDATE audio_files \
                             SET processing = 1, batch_id = '$batch_id' \
                             WHERE rowid IN ( \
                                 SELECT rowid FROM audio_files \
                                 WHERE deployment = '$deployment' AND processing = 0 \
                                 LIMIT $batch_size \
                             ); \
                             COMMIT;" > /dev/null


    # Generate a temporary directory to the audio to be processed and all results
    temp_dir="$deployment_dir/tmp_$batch_id" # name of the directory
    # If the directory does not exist, create it (-p) for all relevant directories;
    # in case it fails (||) exit the script an throw an error (exit 1)
    mkdir -p "$temp_dir/audio" "$temp_dir/predictions" "$temp_dir/selection_tables" "$temp_dir/clips" || {
        echo "[P   ERROR] Failed to create temporary directories. Exiting."
        exit 1
    }

    # echo "[P   DEBUG] [$(date '+%Y-%m-%d %H:%M:%S')] Copying files to temp folder."
    # Write (>) all the files where the batch_id is the current batch_id to 
    # file_list.txt
    echo "[P   DEBUG] [$(date '+%Y-%m-%d %H:%M:%S')] Getting file names."
    sqlite3 "$database_dir" -batch -cmd "
        SELECT new_file_name FROM audio_files WHERE batch_id = '$batch_id';
    " > "$temp_dir/file_list.txt"

    # Copy the files from the file list to the audio_data directory
    # runs the copy (cp) for each file in the file list inserting the file in 
    # the {} part; if it fails exit the script an throw an error (exit 1)
    if ! xargs -a "$temp_dir/file_list.txt" -I {} cp "$deployment_dir/audio_data/{}" "$temp_dir/audio/"; then
        echo "[P   ERROR] Failed to copy some files. Exiting."
        exit 1
    fi

    # echo "[P   DEBUG] [$(date '+%Y-%m-%d %H:%M:%S')] Running predict.sh."
    # Run the predict.sh script with relevant variables, if it fails exit the 
    # script an throw an error (exit 1); the parent will wait for the prediction
    # to finish and the predict.sh runs on the same node 
    echo "[P   DEBUG] [$(date '+%Y-%m-%d %H:%M:%S')] Predicting."
    if ! bash predict.sh "$temp_dir" "$batch_id"; then
        echo "[P   ERROR] [$(date '+%Y-%m-%d %H:%M:%S')] predict.sh failed. Exiting."
        exit 1
    fi

    echo "[P   INFO] [$(date '+%Y-%m-%d %H:%M:%S')] Starting child batch script."
    # Submit child_batch_script.sh and export relevant variables; note it inherits the
    # batch_id for this specific batch; also note that it runs on it's own note
    # and the parent does not wait for it to finish
    sbatch --export=temp_dir="$temp_dir",batch_id="$batch_id",deployment_dir="$deployment_dir",deployment="$deployment",database_dir="$database_dir" child_batch_script.sh

    # Update iteration number
    iteration=$((iteration + 1))
    sleep 1
    # echo "[P   DEBUG] [$(date '+%Y-%m-%d %H:%M:%S')] Iteration $iteration completed."

done

# If this is reached, it means the loop ran out of iterations,
# this usually means something is hanging, because 1000 iteratoins of 222 files 
# should cover a deployment many times!
echo "[P   INFO] [$(date '+%Y-%m-%d %H:%M:%S')] Maximum iterations reached. Exiting."
exit 0

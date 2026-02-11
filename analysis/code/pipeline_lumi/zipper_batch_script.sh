#!/bin/bash -l
#SBATCH --job-name=zipper   # Job name
#SBATCH --output=log_z.o%j # Name of stdout output file
#SBATCH --error=log_z.o%j  # Name of stderr error file
#SBATCH --partition=small
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=10
#SBATCH --mem=8G
#SBATCH --time=2-00:00:00       # Run time (d-hh:mm:ss)
#SBATCH --mail-type=all         # Send email at begin and end of job
#SBATCH --account=project_465001446  # Project for billing
#SBATCH --mail-user=simeon_smeele@ecos.au.dk

# Load relevant modules and only report errors to main output (>/dev/null 2>&1)
module use /appl/local/csc/modulefiles/ >/dev/null 2>&1
module load LUMI/24.03 partition/C >/dev/null 2>&1
module load SQLite/3.43.1-cpeCray-24.03 >/dev/null 2>&1

echo "[Z   INFO] [$(date '+%Y-%m-%d %H:%M:%S')] Zipping deployment folders."

# Variables
database_dir="/flash/project_465001446/audio_database_ERDA.db"

# Function to validate the predictions (make sure full duration is predicted on)
validate_predictions() {
    local deployment_name="$1"
    local deployment_dir="$2"
    local error_occurred=0
    local counter=0
    local log_interval=1000

    while IFS='|' read -r new_file_name duration; do
        counter=$((counter + 1))
        if (( counter % log_interval == 0 )); then
            echo "[Z   DEBUG] [$(date '+%Y-%m-%d %H:%M:%S')] $deployment_name: Checked $counter prediction files."
        fi
        # define the predition file to read
        prediction_file="$deployment_dir/results/predictions/${new_file_name%.wav}_predict_output.log"
        # if it does not exist, set error and break the loop
        if [ ! -f "$prediction_file" ]; then
            echo "[Z   ERROR] [$(date '+%Y-%m-%d %H:%M:%S')] Prediction file missing: $prediction_file" >&2
            error_occurred=1
            break
        fi
        # count number of lines (wc = word count, -l = lines, < = in this file)
        line_count=$(wc -l < "$prediction_file")
        # if less than (-lt) 10 the file is too short, set error and break
        if [ "$line_count" -lt 10 ]; then
            echo "[Z   ERROR] [$(date '+%Y-%m-%d %H:%M:%S')] Prediction file too short: $prediction_file" >&2
            error_occurred=1
            break
        fi
        # find last line and return (tail is last part of the file -n 1 returns one 
        # line)
        last_line=$(tail -n 1 "$prediction_file")
        # exract the last prediction windows end time
        # pipe the last line | to grep, which matches using Perl-compatible regular 
        # expressions (-P) and only returns the matching part (-o), basically looking
        # for something like "time=2.1-2.3" and return the 2.3 part
        extracted_duration=$(echo "$last_line" | grep -oP 'time=[0-9\.]+-\K[0-9\.]+')
        # if the extracted duration isn't found, empty (-z), set error and break
        if [ -z "$extracted_duration" ]; then
            echo "[Z   ERROR] [$(date '+%Y-%m-%d %H:%M:%S')] Could not extract duration from: $prediction_file" >&2
            error_occurred=1
            break
        fi
        # calculate the difference between found duration and duration in database
        # yeah, bash is very weird sometimes, it pipes the calclation (|) to the 
        # standard math library (bc -l), and pipes the result to the stream editor 
        # (sed) to removed the leading -, making it the absolute difference
        duration_diff=$(echo "$extracted_duration - $duration" | bc -l | sed 's/^-//')
        # if the differnce is greater or equal 0.01 (again using the standard math 
        # libarary), then set error and break
        if (( $(echo "$duration_diff >= 0.01" | bc -l) )); then
            echo "[Z   ERROR] [$(date '+%Y-%m-%d %H:%M:%S')] Duration mismatch in $prediction_file (expected: $duration, found: $extracted_duration)" >&2
            error_occurred=1
            break
        fi
    done < <(sqlite3 "$database_dir" "SELECT new_file_name, duration FROM audio_files WHERE deployment='$deployment_name' AND is_broken=0 AND no_audio=0;")
    # and finally, the line above does the reading in the database, which is piped
    # in the oposite direction (<<), not sure why that's so smart
    # if any of the above set the error, exit the script with an error
    if [ "$error_occurred" -eq 1 ]; then
        exit 1
    fi
}

# function to check if a folder is found as deployment
table_check() {
    # define local variable from function argument
    local deployment_name="$1"
    # read in the table and return the count of the entries where the deployment
    # matches
    result=$(sqlite3 "$database_dir" "SELECT COUNT(*) FROM audio_files WHERE deployment='$deployment_name';")
    # return whether or not the are lines (count greater than, -gt, 0)
    [[ "$result" -gt 0 ]]
}

# Loop over all directories
for deployment_dir in /scratch/project_465001446/screening_option/*/; do
    deployment_name=$(basename "$deployment_dir")
    # first check if the directory is a deployment directory with table_check
    if table_check "$deployment_name"; then
        echo "[Z   INFO] [$(date '+%Y-%m-%d %H:%M:%S')] Processing $deployment_name."
        count=$(sqlite3 "$database_dir" "SELECT COUNT(*) FROM audio_files WHERE deployment='$deployment_name' AND is_broken=0 AND no_audio=0;")
        echo "[Z   INFO] [$(date '+%Y-%m-%d %H:%M:%S')] $deployment_name: $count valid audio files found."
        # then check if all prediction logs have the correct duration
        validate_predictions "$deployment_name" "$deployment_dir"
        # remove the audio directory from the deployment directory recursively (-r)
        echo "[Z   INFO] [$(date '+%Y-%m-%d %H:%M:%S')] Removing audio_data."
        rm -r "$deployment_dir/audio_data"
        # zip the three results directories if they exist (-d)
        for folder in selection_tables predictions clips; do
            folder_path="$deployment_dir/results/$folder"
            if [ -d "$folder_path" ]; then
                echo "[Z   INFO] [$(date '+%Y-%m-%d %H:%M:%S')] Zipping $folder."
                # go in folder (cd) and zip recursively (-r) and quiet (-q) and
                # remove the original folder recursively (-r) without warnings (-f)
                (cd "$folder_path" && zip -rq "../$folder.zip" .) && rm -rf "$folder_path"
                echo "[Z   INFO] [$(date '+%Y-%m-%d %H:%M:%S')] Removed original folder $folder."
            fi
        done
    else
        echo "[Z   INFO] [$(date '+%Y-%m-%d %H:%M:%S')] Skipping $deployment_name (not in database)."
    fi
done

echo "[Z   INFO] [$(date '+%Y-%m-%d %H:%M:%S')] Finished zipping deployment folders."

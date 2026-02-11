#!/bin/bash -l
#SBATCH --job-name=child   # Job name
#SBATCH --output=log_c.o%j # Name of stdout output file
#SBATCH --error=log_c.o%j  # Name of stderr error file
#SBATCH --partition=small
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=10
#SBATCH --mem=8G
#SBATCH --time=2-00:00:00       # Run time (d-hh:mm:ss)
#SBATCH --mail-type=all         # Send email at begin and end of job
#SBATCH --account=project_465001446  # Project for billing
#SBATCH --mail-user=simeon_smeele@ecos.au.dk

# Exit on error and treat unset variables as errors
set -eu  

# Load relevant modules and only report errors to main output (>/dev/null 2>&1)
module use /appl/local/csc/modulefiles/ >/dev/null 2>&1
module load LUMI/24.03  partition/C >/dev/null 2>&1
module load SQLite/3.43.1-cpeCray-24.03 >/dev/null 2>&1

# Variables
timeout=240000 # timeout for sql in milliseconds

# Check prediction file durations against database
echo "[C   DEBUG] [$(date '+%Y-%m-%d %H:%M:%S')] Checking prediction file durations."

# Retrieve filenames and durations
output=$(sqlite3 "$database_dir" "PRAGMA busy_timeout = $timeout; \
    SELECT new_file_name, duration FROM audio_files WHERE batch_id = '$batch_id';") || {
    echo "[C   ERROR] [$(date '+%Y-%m-%d %H:%M:%S')] Failed to retrieve filenames and durations. Exiting."
    exit 1
}
output=$(echo "$output" | tail -n +2)

# Process and verify each prediction file
while IFS='|' read -r new_file_name duration; do
    prediction_file="$temp_dir/predictions/${new_file_name%.wav}_predict_output.log"

    if [ ! -f "$prediction_file" ]; then
        echo "[C   ERROR] [$(date '+%Y-%m-%d %H:%M:%S')] Prediction file missing: $prediction_file"
        exit 1    
    fi

    line_count=$(wc -l < "$prediction_file")
    if [ "$line_count" -lt 10 ]; then
        echo "[C   ERROR] [$(date '+%Y-%m-%d %H:%M:%S')] Prediction file too short: $prediction_file"
        exit 1
    fi

    last_line=$(tail -n 1 "$prediction_file")
    extracted_duration=$(echo "$last_line" | grep -oP 'time=[0-9\.]+-\K[0-9\.]+')

    if [ -z "$extracted_duration" ]; then
        echo "[C   ERROR] [$(date '+%Y-%m-%d %H:%M:%S')] Could not extract duration from: $prediction_file"
        exit 1
    fi

    duration_diff=$(echo "$extracted_duration - $duration" | bc -l | sed 's/^-//')
    if (( $(echo "$duration_diff >= 0.01" | bc -l) )); then
        echo "[C   ERROR] [$(date '+%Y-%m-%d %H:%M:%S')] Duration mismatch in $prediction_file (expected: $duration, found: $extracted_duration)"
        exit 1
    fi
done <<< "$output"

# Run translation
echo "[C   DEBUG] [$(date '+%Y-%m-%d %H:%M:%S')] Running translate.sh."
# run translate.sh with required arguments on same node, if fails exit with error
if ! bash translate.sh "$temp_dir" "$batch_id"; then
    echo "[C   ERROR] [$(date '+%Y-%m-%d %H:%M:%S')] translate.sh failed. Exiting."
    exit 1
fi

# Check if there are selection tables before running run_create_clips.sh
echo "[C   DEBUG] [$(date '+%Y-%m-%d %H:%M:%S')] Running run_create_clips.sh."
if ! bash run_create_clips.sh "$temp_dir" "$batch_id"; then
    echo "[C   ERROR] [$(date '+%Y-%m-%d %H:%M:%S')] run_create_clips.sh failed. Exiting."
    exit 1
fi

echo "[C   DEBUG] [$(date '+%Y-%m-%d %H:%M:%S')] Removing audio folder from temp dir."
rm -rf "$temp_dir/audio"

# Retrieve filenames from database
echo "[C   DEBUG] [$(date '+%Y-%m-%d %H:%M:%S')] Selecting new_file_names."
output=$(sqlite3 "$database_dir" "PRAGMA busy_timeout = $timeout; SELECT new_file_name FROM audio_files WHERE batch_id = '$batch_id';") || {
    echo "[C   ERROR] [$(date '+%Y-%m-%d %H:%M:%S')] Failed to retrieve filenames. Exiting."
    exit 1
}
new_file_names=$(echo "$output" | tail -n +2)

# Arrays to store results
declare -A n_detections_array=()
declare -A detections_array=()

# Process each file
for new_file_name in $new_file_names; do
    selection_table_file=$(find "$temp_dir/selection_tables" -name \
        "${new_file_name%.*}_predict_output.log.annotation.result.txt" -print -quit)
    
    if [[ -n "$selection_table_file" ]]; then
        line_count=$(wc -l < "$selection_table_file")
        
        if [[ "$line_count" -gt 1 ]]; then
            n_detections=$((line_count - 1))
            n_detections_array["$new_file_name"]=$n_detections

            tmp_lines_file="$temp_dir/tmp_selection_lines.txt"
            tail -n +2 "$selection_table_file" > "$tmp_lines_file"

            while IFS=$'\t' read -r selection _ _ start_s end_s _ _; do
                new_file_sel="${new_file_name}_${selection}"
                detections_array["$new_file_sel"]="$new_file_name $start_s $end_s"
            done < "$tmp_lines_file"

            rm -f "$tmp_lines_file"
        else
            n_detections_array["$new_file_name"]=0
            rm -f "$selection_table_file"
        fi
    fi
done

# echo "[C   DEBUG] Finished processing selection tables."
# echo "[C   DEBUG] Contents of n_detections_array:"
# for key in "${!n_detections_array[@]}"; do
#     echo "  $key -> ${n_detections_array[$key]}"
# done

# echo "[C   DEBUG] Contents of detections_array:"
# for key in "${!detections_array[@]}"; do
#     echo "  $key -> ${detections_array[$key]}"
# done

echo "[C   DEBUG] [$(date '+%Y-%m-%d %H:%M:%S')] Total detections: ${#detections_array[@]}"


# Update the n_detections
echo "[C   DEBUG] [$(date '+%Y-%m-%d %H:%M:%S')] Updating n_detections."
sql="PRAGMA busy_timeout = $timeout;
BEGIN IMMEDIATE TRANSACTION;"
for new_file_name in "${!n_detections_array[@]}"; do
    n_detections=${n_detections_array["$new_file_name"]}
    # Escape single quotes in filenames
    escaped_name=${new_file_name//\'/\'\'}
    sql+="UPDATE audio_files SET n_detections = $n_detections WHERE new_file_name = '$escaped_name';"
done
sql+="COMMIT;"
echo "[C   DEBUG] [$(date '+%Y-%m-%d %H:%M:%S')] Writing n_detections."
echo "$sql" | sqlite3 "$database_dir" > /dev/null

# Insert detections
echo "[C   DEBUG] [$(date '+%Y-%m-%d %H:%M:%S')] Inserting detections."
sql="PRAGMA busy_timeout = $timeout;
BEGIN IMMEDIATE TRANSACTION;"
for new_file_sel in "${!detections_array[@]}"; do
    IFS=' ' read -r new_file_name start_s end_s <<< "${detections_array["$new_file_sel"]}"
    
    # Escape single quotes for SQLite
    escaped_sel=${new_file_sel//\'/\'\'}
    escaped_name=${new_file_name//\'/\'\'}

    # echo "[C   DEBUG] Parsing detection: new_file_sel=$new_file_sel, start_s=$start_s, end_s=$end_s"
    sql+="INSERT INTO detections (new_file_sel, new_file_name, start_s, end_s, annotation)
          VALUES ('$escaped_sel', '$escaped_name', $start_s, $end_s, NULL)
          ON CONFLICT(new_file_sel) DO NOTHING;"
done
sql+="COMMIT;"

echo "$sql" | sqlite3 "$database_dir" > /dev/null

echo "[C   DEBUG] [$(date '+%Y-%m-%d %H:%M:%S')] Done with inserting detections."

# Create result directories
mkdir -p "$deployment_dir/results/predictions"
mkdir -p "$deployment_dir/results/selection_tables"
mkdir -p "$deployment_dir/results/clips"

# Move files, ensuring no errors if directories are empty
echo "[C   DEBUG] [$(date '+%Y-%m-%d %H:%M:%S')] Moving results."
find "$temp_dir/predictions" -type f -exec mv {} "$deployment_dir/results/predictions/" \; 2>/dev/null || echo "[C   WARNING] [$(date '+%Y-%m-%d %H:%M:%S')] No predictions to move."
find "$temp_dir/selection_tables" -type f -exec mv {} "$deployment_dir/results/selection_tables/" \; 2>/dev/null || echo "[C   WARNING] [$(date '+%Y-%m-%d %H:%M:%S')] No selection tables to move."
find "$temp_dir/clips" -type f -exec mv {} "$deployment_dir/results/clips/" \; 2>/dev/null || echo "[C   WARNING] [$(date '+%Y-%m-%d %H:%M:%S')] No clips to move."

# Remove temp directory
rm -rf "$temp_dir"

# Update processing status in database
echo "[C   DEBUG] [$(date '+%Y-%m-%d %H:%M:%S')] Updating processing."
sqlite3 "$database_dir" "PRAGMA busy_timeout = $timeout; \
                         BEGIN IMMEDIATE TRANSACTION; \
                         UPDATE audio_files SET processing = 2 WHERE batch_id = '$batch_id'; \
                         COMMIT;" > /dev/null

echo "[C   INFO] [$(date '+%Y-%m-%d %H:%M:%S')] Child script finished."

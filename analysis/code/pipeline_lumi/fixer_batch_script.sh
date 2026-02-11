#!/bin/bash -l
#SBATCH --job-name=zipper
#SBATCH --output=log_f.o%j
#SBATCH --error=log_f.o%j
#SBATCH --partition=small
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=10
#SBATCH --mem=8G
#SBATCH --time=2-00:00:00
#SBATCH --mail-type=all
#SBATCH --account=project_465001446
#SBATCH --mail-user=simeon_smeele@ecos.au.dk

module use /appl/local/csc/modulefiles/ >/dev/null 2>&1
module load LUMI/24.03 partition/C >/dev/null 2>&1
module load SQLite/3.43.1-cpeCray-24.03 >/dev/null 2>&1

echo "[F   INFO] [$(date '+%Y-%m-%d %H:%M:%S')] Starting fixer."

# Variables
database_dir="/flash/project_465001446/audio_database_ERDA_HalsBarre10_Seabat133.db"
scratch_dir="/scratch/project_465001446/screening_option"
deployment="HalsBarre10_Seabat133"
predict_dir="$scratch_dir/$deployment/results/predictions"

# Temporary file to store query results
tmpfile=$(mktemp)

# Step 1: Read relevant rows from DB into temp file
sqlite3 "$database_dir" <<EOF > "$tmpfile"
SELECT file_path, new_file_name
FROM audio_files
WHERE deployment = '$deployment' AND batch_id IS NOT NULL;
EOF

# Step 2: Loop through file and do the check and write
while IFS='|' read -r file_path new_file_name; do
    # Skip empty lines
    if [ -z "$file_path" ] || [ -z "$new_file_name" ]; then
        continue
    fi

    base_name="${new_file_name%.wav}"
    log_file="$predict_dir/${base_name}_predict_output.log"

    if [ ! -f "$log_file" ]; then
        echo "[F   DEBUG] [$(date '+%Y-%m-%d %H:%M:%S')] Missing log file for $new_file_name, updating processing=1"
        sqlite3 "$database_dir" "UPDATE audio_files SET processing=1 WHERE file_path='$file_path';"
    fi
done < "$tmpfile"

rm "$tmpfile"
echo "[F   INFO] [$(date '+%Y-%m-%d %H:%M:%S')] Done."

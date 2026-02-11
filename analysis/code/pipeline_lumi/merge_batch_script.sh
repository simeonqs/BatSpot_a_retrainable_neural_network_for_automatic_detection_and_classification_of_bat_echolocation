#!/bin/bash -l
#SBATCH --job-name=merge_db
#SBATCH --output=log_m.o%j
#SBATCH --error=log_m.o%j
#SBATCH --partition=small
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --time=12:00:00
#SBATCH --mail-type=all
#SBATCH --account=project_465001446
#SBATCH --mail-user=simeon_smeele@ecos.au.dk

# Stop if errors occur
set -euo pipefail

# Load SQLite
module use /appl/local/csc/modulefiles/ >/dev/null 2>&1
module load LUMI/24.03 partition/C >/dev/null 2>&1
module load SQLite/3.43.1-cpeCray-24.03 >/dev/null 2>&1

# Paths
main_db="/flash/project_465001446/audio_database_ERDA.db"
screening_dir="/scratch/project_465001446/screening_option"
timeout=6000000 # timeout for SQL in milliseconds

# Function to check if deployment exists in main database
table_check() {
    local deployment_name="$1"
    local result
    result=$(sqlite3 "$main_db" "SELECT COUNT(*) FROM audio_files WHERE deployment='$deployment_name';")
    [[ "$result" -gt 0 ]]
}

# Loop over directories in screening_dir
for dir in "$screening_dir"/*/; do
    deployment=$(basename "$dir")
    deployment_db="/flash/project_465001446/audio_database_${deployment}.db"

    if ! table_check "$deployment"; then
        echo "[SKIP] Deployment '$deployment' not found in database. Skipping."
        continue
    fi

    if [ ! -f "$deployment_db" ]; then
        echo "[MERGE ERROR] Deployment database not found: $deployment_db"
        continue
    fi

    echo "[MERGE INFO] Merging from $deployment_db into $main_db"

    # Generate update clause for all columns except file_path
    update_clause=$(sqlite3 "$main_db" "PRAGMA table_info(audio_files);" \
        | awk -F'|' '$2 != "file_path" {printf "%s=excluded.%s,", $2, $2}' \
        | sed 's/,$//')

    sqlite3 "$main_db" <<EOF
PRAGMA busy_timeout = $timeout;
ATTACH DATABASE '$deployment_db' AS dep;

BEGIN IMMEDIATE TRANSACTION;

-- 1. Merge detections (insert only if new_file_sel not already present)
INSERT INTO detections
SELECT * FROM dep.detections d
WHERE NOT EXISTS (
    SELECT 1 FROM detections m WHERE m.new_file_sel = d.new_file_sel
);

-- 2. Merge audio_files (replace on conflict to update all columns)
INSERT OR REPLACE INTO audio_files
SELECT * FROM dep.audio_files;

COMMIT;

DETACH DATABASE dep;
EOF

    echo "[MERGE INFO] Merge complete for $deployment."
done

echo "[MERGE INFO] All done!"
#!/bin/bash -l
#SBATCH --job-name=grand_parent
#SBATCH --output=log_gp.o%j
#SBATCH --error=log_gp.o%j
#SBATCH --partition=small
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=10
#SBATCH --mem=8G
#SBATCH --time=2-00:00:00
#SBATCH --mail-type=all
#SBATCH --account=project_465001446
#SBATCH --mail-user=simeon_smeele@ecos.au.dk

# Stop if errors occur
set -e

if [ "$#" -ne 1 ]; then
    echo "Usage: sbatch $0 <deployment_db>"
    exit 1
fi


# Loading modules and only report errors to main output (>/dev/null 2>&1)
module use /appl/local/csc/modulefiles/ >/dev/null 2>&1
module load LUMI/24.03 partition/C >/dev/null 2>&1
module load SQLite/3.43.1-cpeCray-24.03 >/dev/null 2>&1

# Variables
scratch_dir="/scratch/project_465001446/screening_option"
deployment="$1"
deployment_dir="$scratch_dir/$deployment"
database_dir="/flash/project_465001446/audio_database_ERDA.db"
deployment_db="/flash/project_465001446/audio_database_${deployment}.db"
timeout=6000000 # timeout for sql in milliseconds

echo "[GP  INFO] [$(date '+%Y-%m-%d %H:%M:%S')] Creating deployment directory: $deployment_dir."
mkdir -p "$deployment_dir"

# remove any tmp folders from earlier runs
echo "[GP  INFO] [$(date '+%Y-%m-%d %H:%M:%S')] Removing tmp folders."
find "$deployment_dir" -type d -name 'tmp*' -print0 | xargs -0 rm -rf

# Create a deployment-specific database only if it doesn't already exist
if [ ! -f "$deployment_db" ]; then
    echo "[GP  INFO] [$(date '+%Y-%m-%d %H:%M:%S')] Creating deployment database: $deployment_db."

    # Copy schema from main database
    sqlite3 "$database_dir" ".schema" | sqlite3 "$deployment_db"

    # Copy only rows for this deployment into audio_files
    sqlite3 "$database_dir" <<EOF
PRAGMA busy_timeout = $timeout;
ATTACH DATABASE '$deployment_db' AS dep;
INSERT INTO dep.audio_files
SELECT * FROM main.audio_files WHERE deployment = '$deployment';
DETACH DATABASE dep;
EOF

    # Ensure detections table exists but is empty
    sqlite3 "$deployment_db" "DELETE FROM detections;"
else
    echo "[GP  INFO] [$(date '+%Y-%m-%d %H:%M:%S')] Deployment database already exists: $deployment_db (skipping creation)."
fi

# Use SQLite transaction to update database safely
# this resets all processing == 1 to 0 and batch_id to NULL, making sure 
# unfinished batches will be rerun
echo "[GP  INFO] [$(date '+%Y-%m-%d %H:%M:%S')] Updating database."
sqlite3 "$deployment_db" "PRAGMA busy_timeout = $timeout; BEGIN IMMEDIATE TRANSACTION; UPDATE audio_files SET batch_id = NULL, processing = 0 WHERE processing = 1 AND deployment = '$deployment'; COMMIT;" > /dev/null

# run download script with deployment-specific database
echo "[GP  INFO] [$(date '+%Y-%m-%d %H:%M:%S')] Running download script."
bash download_from_ERDA.sh "$deployment_dir" "$deployment_db" "$deployment"

# submit parent scripts with deployment-specific database
echo "[GP  INFO] [$(date '+%Y-%m-%d %H:%M:%S')] Starting parent batch scripts."
for i in {1..30}; do
    echo "[GP  INFO] [$(date '+%Y-%m-%d %H:%M:%S')] Submitting parent batch script $i."
    sbatch --export=deployment_dir="$deployment_dir",deployment="$deployment",database_dir="$deployment_db" parent_batch_script.sh
    sleep 30
done

echo "[GP  INFO] [$(date '+%Y-%m-%d %H:%M:%S')] Grand parent script finished."

database_dir="/home/au472091/Desktop/audio_database_ERDA.db"

database_dir="/users/smeelesi/pipeline_lumi/audio_database_ERDA.db"



sqlite3 "$database_dir" "UPDATE audio_files SET batch_id = NULL, processing = 0 WHERE processing = 1;"


sqlite3 "audio_database_ERDA.db" "UPDATE audio_files SET batch_id = NULL, processing = 0 WHERE processing = 1;"

sqlite3 "audio_database_ERDA.db" "PRAGMA busy_timeout = 5000; BEGIN IMMEDIATE TRANSACTION; UPDATE audio_files SET batch_id = NULL, processing = 0 WHERE processing = 1; COMMIT;"


sqlite3 "$database_dir" "SELECT COUNT(*) FROM audio_files WHERE deployment = '$deployment' AND processing = 0;"

sqlite3 "$database_dir" "PRAGMA busy_timeout = 5000; SELECT COUNT(*) FROM audio_files WHERE deployment = '$deployment' AND processing = 0;" | 
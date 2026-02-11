# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
# Project: screening option  
# Author: Simeon Q. Smeele
# Description: Reads all audio files, tests if they are broken, checks if they
# contain audio, reads their duration, and stores all results in a SQL 
# database. If rerun, it skips existing paths. The output contains a table for
# all audio files (audio_files) and an empty table for all detections
# detections. This version runs a single instance and gives feedback on 
# progress. This version mounts ERDA for faster processing. 
# Alternative with share-link:
# with IOHandler(user="link", password="link") as io:
# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

import os
import sqlite3
import wave
import numpy as np
from datetime import datetime
from pyremotedata.implicit_mount import IOHandler, RemotePathIterator
from pyremotedata.config import remove_config

# Path specifications
database_path = '/home/au472091/Desktop/audio_database_ERDA_final.db'

os.environ['PYREMOTEDATA_REMOTE_USERNAME'] = 'simeon_smeele@ecos.au.dk'
os.environ['PYREMOTEDATA_REMOTE_URI'] = 'io.erda.au.dk'
os.environ['PYREMOTEDATA_REMOTE_DIRECTORY'] = (
    '/Bat_wo_men/screening_option2_data/data_for_aspot'
)
os.environ['PYREMOTEDATA_AUTO'] = 'yes'

remove_config()

def create_database(db_path):
    """
    Creates an SQLite database with a table for audio file information.
    """
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    cursor.execute(
        '''
        CREATE TABLE IF NOT EXISTS audio_files (
            file_path TEXT UNIQUE PRIMARY KEY,
            file_name TEXT,
            new_file_name TEXT UNIQUE,
            batch_id TEXT,
            location TEXT,
            deployment TEXT,
            duration REAL,
            is_broken BOOLEAN,
            no_audio BOOLEAN,
            processing INTEGER,
            n_detections INTEGER,
            bats_present INTEGER
        )
        '''
    )
    cursor.execute(
    '''
    CREATE TABLE IF NOT EXISTS detections (
        new_file_sel TEXT UNIQUE PRIMARY KEY,
        new_file_name TEXT,
        start_s REAL,
        end_s REAL,
        annotation TEXT,
        FOREIGN KEY (new_file_name) 
          REFERENCES audio_files(new_file_name) 
          ON DELETE CASCADE
    )
    '''
    )
    conn.commit()
    conn.close()

def process_wav_file(file_path, remote_file):
    """
    Process a single WAV file and return the data to be inserted into the 
    database. This function checks for file integrity, extracts metadata, and 
    returns a tuple matching the database schema.
    """
    file_name = os.path.basename(file_path)
    
    # Extract location and deployment from the file path
    parts = remote_file.split('/')
    if len(parts) >= 2:
        location = parts[0]
        deployment = parts[1]
        new_file_name = f"{location}_{deployment}_{file_name.lower()}"
    else:
        raise ValueError(f"Unexpected path format: {parts}")

    try:
        # Check if the file is 0 bytes
        if os.path.getsize(file_path) == 0:
            return (remote_file, file_name, new_file_name, None, location, 
                    deployment, 0, True, True, 2, None, None)

        # Open and analyze the WAV file
        with wave.open(file_path, 'rb') as wf:
            frames = wf.getnframes()
            rate = wf.getframerate()
            duration = frames / float(rate)

            # Read and decode audio frames
            audio_frames = wf.readframes(frames)
            sample_width = wf.getsampwidth()

            # Convert raw audio frames to numpy array
            dtype = {1: np.int8, 2: np.int16, 4: np.int32}.get(sample_width)
            if dtype is None:
                raise ValueError(f"Unsupported sample width: {sample_width}")

            audio_array = np.frombuffer(audio_frames, dtype=dtype)

            # Check if all samples are effectively silent
            no_audio = int(np.all(np.abs(audio_array) <= 1))

            return (remote_file, file_name, new_file_name, None, location, 
                    deployment, duration, False, no_audio, no_audio * 2, 
                    None, None)

    except Exception as e:
        # print(f"Error processing {file_path}: {e.__class__.__name__} - {e}")
        return (remote_file, file_name, new_file_name, None, location, 
                deployment, 0, True, True, 2, None, None)

def index_audio_files(db_path):
    """
    Indexes all WAV files in the directory and its subdirectories.
    """
    current_time = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    print(f'[INFO] [{current_time}] creating database.')
    create_database(db_path)

    # Get file paths already in the database
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    cursor.execute('SELECT file_path FROM audio_files')
    existing_files = {row[0] for row in cursor.fetchall()}
    conn.close()

    current_time = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    print(f'[INFO] [{current_time}] starting file processing.')

    processed_count = 0

    with IOHandler(clean=True) as io:
        for file_path, remote_file in RemotePathIterator(io, override=True):
            if (file_path in existing_files or 
                    not file_path.lower().endswith('.wav')):
                continue
            
            if processed_count % 10000 == 0:
                if processed_count > 0:
                    conn.commit()
                    conn.close()
                conn = sqlite3.connect(db_path)
                cursor = conn.cursor()

            result = process_wav_file(file_path, remote_file)
            try:
                cursor.execute(
                    '''
                    INSERT INTO audio_files (
                        file_path, file_name, new_file_name, batch_id, 
                        location, deployment, duration, is_broken, no_audio, 
                        processing, n_detections, bats_present
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    ''',
                    result
                )
            except sqlite3.IntegrityError:
                pass  # Skip duplicates

            processed_count += 1

            if processed_count % 10000 == 0:
                current_time = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                print(f'[INFO] [{current_time}] processed ' 
                f'{processed_count // 1000}k files.')

    conn.commit()
    conn.close()

if __name__ == '__main__':
    index_audio_files(database_path)
    current_time = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    print(f'[DONE] [{current_time}] Indexing complete.')

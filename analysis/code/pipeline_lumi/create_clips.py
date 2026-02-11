# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
# Project: pam bats  
# Author: Simeon Q. Smeele
# Description: Extract audio clips for all detections from folder and store
# wav clips in the same folder.
# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

# Loading libraries
import os
import pandas as pd
import wave
import numpy as np
import sys
from datetime import datetime

# Settings
wing = 0.01  # how much to add before and after detection

# Paths, placeholders to be filled out by run_create_clips.sh
path_detections = ''
path_audio = ''
path_out = ''

# Create output directory if it doesn't exist
if not os.path.exists(path_out):
    os.makedirs(path_out)

# Load and merge selection tables
all_files = [os.path.join(path_detections, f) for f in os.listdir(path_detections) if f.endswith('.txt')]
detections_list = []

# Run for each file
for file in all_files:
    # Read the selection table, which is tab seperated (\t)
    df = pd.read_csv(file, sep='\t')
    # If it's not empty do
    if not df.empty:
        # Remove .txt extension from the file name
        base_name = os.path.splitext(os.path.basename(file))[0]
        # Remove _predict_output.log.annotation.result from the file name
        clean_name = base_name.replace('_predict_output.log.annotation.result', '')
        # Add the cleaned 'file' column
        df['file'] = clean_name  
        # Add the df to the list
        detections_list.append(df)

# If no valid files are found, exit the script
if not detections_list:
    print(f"[CC  INFO] [{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] No valid detection files found. Exiting.")
    sys.exit()

# Combine all selection tables into one data frame
detections = pd.concat(detections_list, ignore_index=True)

# Function to extract and save audio clips
def extract_audio_clip(detection_row, path_audio=None, path_out=None):
    file_name = detection_row['file']
    begin_time = detection_row['Begin time (s)'] - wing
    end_time = detection_row['End time (s)'] + wing
    
    # Read the wav file
    file_path = os.path.join(path_audio, f"{file_name}.wav")
    with wave.open(file_path, 'rb') as wav_file:
        samplerate = wav_file.getframerate()
        n_channels = wav_file.getnchannels()
        sampwidth = wav_file.getsampwidth()
        n_frames = wav_file.getnframes()
        
        # Calculate start and stop frames
        start_frame = max(1, int(begin_time * samplerate))
        end_frame = min(n_frames, int(end_time * samplerate))
        
        # Set position and read frames
        wav_file.setpos(start_frame)
        frames = wav_file.readframes(end_frame - start_frame)
        
        # Convert frames to numpy array
        data = np.frombuffer(frames, dtype=np.int16)
        if n_channels > 1:
            data = data.reshape(-1, n_channels)
    
    # Write the wav clip
    output_file_path = os.path.join(path_out, f"{file_name}_{detection_row['Selection']}.wav")
    with wave.open(output_file_path, 'wb') as out_wav_file:
        out_wav_file.setnchannels(n_channels)
        out_wav_file.setsampwidth(sampwidth)
        out_wav_file.setframerate(samplerate)
        out_wav_file.writeframes(data.tobytes())

# Run function on all detections
for i in range(len(detections)):
    extract_audio_clip(detections.iloc[i], path_audio, path_out)

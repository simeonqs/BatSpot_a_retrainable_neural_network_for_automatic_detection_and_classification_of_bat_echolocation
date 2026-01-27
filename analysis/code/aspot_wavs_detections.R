# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
# Project: BatSpot  
# Author: Simeon Q. Smeele
# Description: Creates single wav file per detection. Files are stored with 
# the naming convention "originalname_detectionnumber.wav" where the original
# name does not include the extension. 
# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

# Loading libraries
libraries = c('callsync', 'stringr', 'seewave', 'tuneR')
for(lib in libraries){
  if(! lib %in% installed.packages()) lapply(lib, install.packages)
  lapply(libraries, require, character.only = TRUE)
}

# Clean R
rm(list=ls()) 

# Settings
wing = 0.01 # how much to add before and after detection

# Paths 
path_detections = 'aspot/models_call_detector/m03/selection_tables'
path_audio = 'analysis/data/call_detector/validation_data/audio/denmark'
path_out = 'aspot/models_call_detector/m03/wavs_detections'

# Load selection tables
detections = load.selection.tables(path_detections)

# Function to export clips
export.clip = function(detection_row, path_audio = NULL, path_out = NULL){
  wave = readWave(sprintf('%s/%s.wav', path_audio, detection_row$file), 
                  from = detection_row$Begin.time..s. - wing, 
                  to = detection_row$End.time..s. + wing,
                  units = 'seconds')
  writeWave(wave, sprintf(sprintf('%s/%s_%s.wav', 
                                  path_out, 
                                  detection_row$file,
                                  detection_row$Selection)))
}

# Run function on all detections
lapply(seq_len(nrow(detections)), function(i) 
  export.clip(detections[i,], path_audio, path_out))

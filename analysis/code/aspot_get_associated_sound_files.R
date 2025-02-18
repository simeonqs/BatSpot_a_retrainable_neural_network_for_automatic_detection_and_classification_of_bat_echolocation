# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
# Project: aspot bats  
# Author: Simeon Q. Smeele
# Description: Copy sound files that are needed to create training data from 
# selection tables to audio folder. 
# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

# Loading libraries
libraries = c('callsync', 'stringr')
for(lib in libraries){
  if(! lib %in% installed.packages()) lapply(lib, install.packages)
  lapply(libraries, require, character.only = TRUE)
}

# Clean R
rm(list=ls()) 

# Paths 
path_selection_tables = 
  '/home/au472091/OneDrive/au/projects/aspot_bats/analysis/data/buzz_detector/training_data/target/denmark'
path_audio = 
  '/home/au472091/OneDrive/au/projects/pam_bats/analysis/data/audio/additional_training_data'
path_output = 
  '/home/au472091/OneDrive/au/projects/aspot_bats/analysis/data/buzz_detector/training_data/audio/denmark'

# Run through files and copy
sts = load.selection.tables(path_selection_tables)
for(file in unique(sts$file)){
  file.copy(sprintf('%s/%s.wav', path_audio, file),
            sprintf('%s/%s.wav', path_output, file))
  file.copy(sprintf('%s/%s.WAV', path_audio, file),
            sprintf('%s/%s.wav', path_output, file))
}





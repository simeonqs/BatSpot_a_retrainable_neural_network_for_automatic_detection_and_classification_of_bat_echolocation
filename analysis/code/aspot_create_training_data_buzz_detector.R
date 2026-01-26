# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
# Project: aspot bats  
# Author: Simeon Q. Smeele
# Description: Takes Raven selection tables and raw audio and creates audio
# clips with the correct file names for Animal Spot.
# Also takes clips from early model run (errors and correct detections) and 
# renames them as training data. 
# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

# Loading libraries
libraries = c('stringr', 'seewave', 'tuneR')
for(lib in libraries){
  if(! lib %in% installed.packages()) lapply(lib, install.packages)
  lapply(libraries, require, character.only = TRUE)
}

# Clean R
rm(list=ls()) 

# Settings
data_set = 7
n_aug_noise = 200

# Run for types
for(type in c('target', 'noise')){
  
  # Paths 
  path_selections = 
    sprintf('analysis/data/buzz_detector/training_data/%s/konstanz', type)
  path_wavs = 'analysis/data/audio'
  path_results = 
    sprintf('aspot/data_sets_buzz_detector/data_%s/data', data_set)
  path_aug = sprintf('aspot/data_sets_buzz_detector/data_%s/aug_data', 
                     data_set)
  path_early_run_clips = 
    sprintf('%s/%s', 
            'analysis/data/buzz_detector/training_data/from_runs_konstanz',
            type)
  
  # Creates paths
  if(!dir.exists(sprintf('%s/%s', path_results, type))) 
    dir.create(sprintf('%s/%s', path_results, type), recursive = TRUE)
  
  # List files
  audio_files = c(list.files(path_wavs,  '*wav', full.names = TRUE, 
                             recursive = TRUE), 
                  list.files(path_wavs,  '*WAV', full.names = TRUE, 
                             recursive = TRUE))
  
  # Find the selection tables
  selection_tables = list.files(path_selections, '*txt', full.names = TRUE, 
                                recursive = TRUE)
  
  # The function for each selection
  export.selection = function(selection, selection_table, wave, file_name){
    
    # Get start and end
    start = round((selection_table$Begin.Time..s.[selection]) * wave@samp.rate)
    if(length(start) == 0) 
      start = round((selection_table$Begin.time..s.[selection]) * 
                      wave@samp.rate)
    end = round((selection_table$End.Time..s.[selection]) * wave@samp.rate)
    if(length(end) == 0) 
      end = round((selection_table$End.time..s.[selection]) * wave@samp.rate)
    
    # Create new name 
    ID = round(runif(1) * 1e7)
    year = 2020
    tape_name = str_replace_all(file_name, '_', '-')
    start_name = round(start / wave@samp.rate * 1000)
    end_name = round(end / wave@samp.rate * 1000)
    new_name = paste0(type, '-bat', '_', ID, '_', year, '_', 
                      tape_name, '_', start_name, '_', end_name)
    
    # Create new wave and save
    new_wave = wave[start:end]
    if(length(new_wave@left)/new_wave@samp.rate > 0.1){
      new_name = paste0(path_results, '/', type, '/', new_name, '.wav')
      writeWave(new_wave, new_name, extensible = FALSE)
    }
    
  }
  
  # The running per selection table
  export.selections = function(path_selection_table){
    
    # Read the table
    selection_table = read.csv(path_selection_table, sep = '\t')
    selection_table = 
      selection_table[str_detect(selection_table$View, 'Spectrogram'),]
    
    # Only keep 0.2 selections if there is a mix
    if(length(unique(selection_table$Annotation)) > 1)
      selection_table = selection_table[which(selection_table$Annotation == 
                                                '.2sdeltatime'),]
    
    # Find wav file name
    file_name = path_selection_table |>
      basename() |>
      str_remove('.Table.1.selections.txt') |>
      str_remove('.Table.2.selections.txt') |>
      str_remove('_predict_output.log.annotation.result.txt') |>
      str_remove('_ST.txt') |>
      str_remove('_Nlep') |>
      str_remove('_Molmol') |>
      str_remove('.Band.Limited.Energy.Detector.selections.txt') 
    file_name = sub('\\.\\d+\\.selections\\.txt$', '', file_name)
    
    print(file_name)
    
    # Read the wave
    wave = readWave(audio_files[ grepl(paste0(file_name, '.wav'), audio_files,
                                       ignore.case = TRUE) ])
    
    # Export for each piece
    sapply(seq_len(nrow(selection_table)), export.selection, 
           selection_table, wave, file_name)
  }
  
  # Calls the function
  sapply(selection_tables, export.selections)
  
  # Copy files from early runs with new names
  files = list.files(path_early_run_clips, full.names = TRUE)
  new_names = sprintf('%s/%s/%s-bat_%s_%s_%s_%s_%s.wav',
                      path_results,
                      type,
                      type,
                      round(runif(length(files), 1, 1e7)),
                      2020,
                      str_replace_all(str_remove(basename(files), '.WAV'), 
                                      '_', '-'),
                      1, 
                      2)
  file.copy(files, new_names)
  
} # end type loop

# Move some noise to aug data
if(!dir.exists(path_aug)) dir.create(path_aug)
files = sprintf('%s/noise', path_results) |>
  list.files(full.names = TRUE) |>
  sample(n_aug_noise)
file.rename(files, str_replace(files, 'data/noise', 'aug_data'))

# Message
message('Exported all selections.')

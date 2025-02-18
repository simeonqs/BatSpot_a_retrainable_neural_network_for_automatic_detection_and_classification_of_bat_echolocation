# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
# Project: aspot bats  
# Author: Simeon Q. Smeele
# Description: Takes Raven selection tables and raw audio and creates audio
# clips with the correct file names for Animal Spot.
# NOTE: social calls are treated as noise, and actual noise it not included.
# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

# Loading libraries
libraries = c('stringr', 'seewave', 'tuneR', 'callsync')
for(lib in libraries){
  if(! lib %in% installed.packages()) lapply(lib, install.packages)
  lapply(libraries, require, character.only = TRUE)
}

# Clean R
rm(list=ls()) 

# Settings
data_set = 7
samp_rate_lower_limit = 192000

# Paths 
path_results = sprintf('aspot/data_sets_call_classifier/data_%s', data_set)
path_selections = 'analysis/data/call_classifier/trainings_data/species'
path_selections_bs = 
  'analysis/data/call_classifier/trainings_data/buzz_and_social'
path_selections_noise = 'analysis/data/call_classifier/trainings_data/noise'
path_wavs = 'analysis/data/audio'

# Create directories
if(!file.exists(path_results)) dir.create(path_results, recursive = TRUE)

# Find the selection tables
selection_tables = load.selection.tables(path_selections, recursive = TRUE)
selection_tables_bs = load.selection.tables(path_selections_bs, 
                                            recursive = TRUE)
selection_tables_noise = load.selection.tables(path_selections_noise,
                                               recursive = TRUE)

# Remove some noise
selection_tables_noise = 
  selection_tables_noise[sample(nrow(selection_tables_noise), 200),]

# List files
audio_files = c(list.files(path_wavs,  '*wav', full.names = TRUE, 
                           recursive = TRUE), 
                list.files(path_wavs,  '*WAV', full.names = TRUE, 
                           recursive = TRUE))

# The function for each selection
export.selection = function(selection, selection_table, wave, file_name, 
                            buzz_and_social = FALSE, noise = FALSE){
  
  # Get start and end
  start = round((selection_table$Begin.Time..s.[selection]) * wave@samp.rate)
  if(length(start) == 0) 
    start = round((selection_table$Begin.time..s.[selection]) * wave@samp.rate)
  end = round((selection_table$End.Time..s.[selection]) * wave@samp.rate)
  if(length(end) == 0) 
    end = round((selection_table$End.time..s.[selection]) * wave@samp.rate)
  
  # Create new name
  # if(str_detect(file_name, '_')) {
  #   type = file_name |> str_replace_all(' ', '_') |> strsplit('_') |> 
  #     sapply(`[`, 6)
  # } else {
  #   type = file_name |> strsplit(' ') |> sapply(`[`, 1)
  # }
  # type = type |> str_remove('-')
  types_detected = c()
  if(noise) types_detected = 'noise'
  if(str_detect(tolower(file_name), 'bbar')) 
    types_detected = c(types_detected, 'bbar')
  if(str_detect(tolower(file_name), 'enil')) 
    types_detected = c(types_detected, 'enil')
  if(str_detect(tolower(file_name), 's4u1')) 
    types_detected = c(types_detected, 'enil')
  if(str_detect(tolower(file_name), 'eser')) 
    types_detected = c(types_detected, 'eser')
  if(str_detect(tolower(file_name), 'mbra')) 
    types_detected = c(types_detected, 'mbramys')
  if(str_detect(tolower(file_name), 'mdas')) 
    types_detected = c(types_detected, 'mdas')
  if(str_detect(tolower(file_name), 'mdau')) 
    types_detected = c(types_detected, 'mdau')
  if(str_detect(tolower(file_name), 'mnat')) 
    types_detected = c(types_detected, 'mnat')
  if(str_detect(tolower(file_name), 'nnoc')) 
    types_detected = c(types_detected, 'nnoc')
  if(str_detect(tolower(file_name), 'paur')) 
    types_detected = c(types_detected, 'paur')
  if(str_detect(tolower(file_name), 'ppyg')) 
    types_detected = c(types_detected, 'ppyg')
  if(str_detect(tolower(file_name), 'ppip')) 
    types_detected = c(types_detected, 'ppip')
  if(str_detect(tolower(file_name), 'pnat')) 
    types_detected = c(types_detected, 'pnat')
  if(str_detect(tolower(file_name), 'vmur')) 
    types_detected = c(types_detected, 'vmur')
  if(buzz_and_social) {
    if(selection_table$Annotation[selection] == 's') type = 's' else 
      type = 'B'
  } else {
    if(is.null(types_detected)) stop('No type detected.')
    if(length(types_detected) > 1) stop('Multiple types detected.')
    type = types_detected
    # if(type == 'MbraMmys') type = 'Mbramys'
    # if(type %in% c('Mdau', 'Mbramys', 'Mnat', 'Mdas')) type = 'M'
    # if(type %in% c('Vmur', 'Eser', 'Nnoc')) type = 'NVE'
  }
  
  ID = round(runif(1) * 1e7)
  year = 2023
  tape_name = str_replace_all(file_name, '_', '-')
  start_name = round(start / wave@samp.rate * 1000)
  end_name = round(end / wave@samp.rate * 1000)
  new_name = paste0(type, '-bat', '_', ID, '_', year, '_', 
                    tape_name, '_', start_name, '_', end_name)
  
  # Create new wave and save
  new_wave = wave[start:end]
  if(length(new_wave@left)/new_wave@samp.rate > 0.005){
    if(wave@samp.rate > samp_rate_lower_limit){
      if(!type %in% c('enil')){
      new_name = paste0(path_results, '/', new_name, '.wav')
      writeWave(new_wave, new_name, extensible = FALSE)
      }
    }
  }
  
}

# The running per selection table
export.selections = function(file, buzz_and_social = FALSE, noise = FALSE){
  
  # Read the table
  selection_table = selection_tables[selection_tables$file == file,]
  if(buzz_and_social) 
    selection_table = selection_tables_bs[selection_tables_bs$file == file,]
  if(noise) 
    selection_table = 
      selection_tables_noise[selection_tables_noise$file == file,]
  
  # Find wav file name
  file_name = file |>
    basename() |>
    str_remove('.Table.1.selections.txt') |>
    str_remove('.Table.2.selections.txt') |>
    str_remove('_predict_output.log.annotation.result.txt') 
  file_name = sub('\\.\\d+\\.selections\\.txt$', '', file_name)
  
  print(file_name)
  
  # Read the wave
  wave = readWave(audio_files[ grepl(paste0(
    file_name |> 
      str_remove('.Mdaub.selections.txt') |> 
      str_remove('.Mnat.selections.txt') |> 
      str_remove('.Nnoc.selections.txt') |> 
      str_remove('.bat_Pippyg.selections.txt') |> 
      str_remove('.Eser.selections.txt'), 
    '.wav'), 
    audio_files,
    ignore.case = TRUE) ])
  
  # Export for each piece
  sapply(seq_len(nrow(selection_table)), export.selection, 
         selection_table, wave, file_name, buzz_and_social, noise)
}

# Call the function
sapply(unique(selection_tables$file), export.selections)
sapply(unique(selection_tables_bs$file), export.selections, 
       buzz_and_social = TRUE)
sapply(unique(selection_tables_noise$file), export.selections,
       noise = TRUE)

# Message
files_stored = list.files(path_results, '*wav')
types = files_stored |> strsplit('_') |> sapply(`[`, 1)
message(sprintf('Exported %s selections with following types:',
                length(files_stored)))
print(table(types))

files_stored = list.files(path_results, '*wav', full.names = TRUE)
srs = sapply(files_stored, function(x){
  wave = readWave(x)
  return(wave@samp.rate)
})
message('Sample rates:')
print(table(srs))

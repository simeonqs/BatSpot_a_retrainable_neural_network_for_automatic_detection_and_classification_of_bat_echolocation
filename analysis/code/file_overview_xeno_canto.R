# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
# Project: aspot bats  
# Author: Simeon Q. Smeele
# Description: Creates file overview for Xeno Canto.
# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

# Loading libraries
libraries = c('stringr')
for(lib in libraries){
  if(! lib %in% installed.packages()) lapply(lib, install.packages)
  lapply(libraries, require, character.only = TRUE)
}

# Clean R
rm(list=ls()) 

# Paths 
path_selection_tables = 'analysis/data/call_classifier/training_data/species'
path_csv = 'analysis/results/file_overview_xeno_canto.csv'

# List files and remove extension
files = path_selection_tables |> 
  list.files() |> 
  str_remove('.Table.1.selections.txt') |>
  str_remove('.bat_Pippyg.selections.txt') |>
  str_remove('.bat_Nnoc.selections.txt') |>
  str_remove('.bat_Mdaub.selections.txt') |>
  str_remove('.bat_Eser.selections.txt') |>
  str_remove('.bat_Mnat.selections.txt') |>
  str_remove('.Nnoc.selections.txt') |>
  str_remove('.Mdaub.selections') |>
  str_remove('.Mnat.selections.txt') |>
  str_remove('.Eser.selections.txt')

# Write csv
write.csv(as.data.frame(files), path_csv, row.names = FALSE)





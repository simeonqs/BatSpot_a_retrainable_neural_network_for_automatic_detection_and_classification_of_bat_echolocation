library(tuneR)
library(stringr)
files = list.files("analysis/data/buzz_detector/validation_data/audio/konstanz", 
                   pattern = '*WAV', recursive = T, full.names = T)
for(file in files) file.rename(file, str_replace(file, 'WAV', 'wav'))

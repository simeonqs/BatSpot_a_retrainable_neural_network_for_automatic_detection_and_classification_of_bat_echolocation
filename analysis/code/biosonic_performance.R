# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
# Project: aspot bats  
# Author: Simeon Q. Smeele
# Description: Plots confusion matrix for call detector.
# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

# Loading libraries
libraries = c('stringr', 'callsync', 'caret', 'dplyr')
for(lib in libraries){
  if(! lib %in% installed.packages()) lapply(lib, install.packages)
  lapply(libraries, require, character.only = TRUE)
}

# Clean R
rm(list=ls()) 

stop('This script has errors, update with code from ENV_split version.')

# Paths
path_biosonic = 'analysis/results/biosonic/id.csv'
path_ground_truth = 'analysis/data/call_detector/validation_data/ground_truth'
path_pdf = 'analysis/results/biosonic/confusion_matrix.pdf'

# Load data
biosonic = read.csv(path_biosonic)
manual = load.selection.tables(path_ground_truth, recursive = TRUE)
rownames(manual) = seq_len(nrow(manual))

# Remove NOVANA files
biosonic = biosonic[!str_detect(biosonic$IN.FILE, 'M00'),]

# # Subset
# biosonic = biosonic[!str_detect(biosonic$file, 'NS') &
#                           !str_detect(biosonic$file, 'HR') &
#                           !str_detect(biosonic$file, 'ONBOARD'),]
# manual = manual[!str_detect(manual$file, 'NS') &
#                           !str_detect(manual$file, 'HR') &
#                           !str_detect(manual$file, 'ONBOARD'),]
# biosonic = biosonic[str_detect(biosonic$file, 'NS') |
#                           str_detect(biosonic$file, 'HR') |
#                           str_detect(biosonic$file, 'ONBOARD'),]
# manual = manual[str_detect(manual$file, 'NS') |
#                           str_detect(manual$file, 'HR') |
#                           str_detect(manual$file, 'ONBOARD'),]

# Test if all files in are in the manual data frame
files_gt = list.files(path_ground_truth, recursive = TRUE) |> 
  basename() |> 
  str_remove('.Table.1.selections.txt') |>
  str_remove('.Band.Limited.Energy.Detector.selections.txt')
biosonic$file = biosonic$IN.FILE |> 
  str_remove('.WAV') |> 
  str_remove('.wav')
if(any(!biosonic$file %in% files_gt)) stop('Missing ground truth.')
manual = manual[manual$file %in% biosonic$file,]

# Remove files with uncertain species
remove = manual$file[manual$Annotation %in% c('Ppippyg', 'Ppipnat')]
manual = manual[!manual$file %in% remove,]
biosonic = biosonic[!biosonic$file %in% remove,]

# For multispecies rows add an extra row for second species
for(row in seq_len(nrow(biosonic))){
  if(biosonic$AUTO.ID[row] == 'PIPNAT,PIPPIP'){
    new_row = biosonic[row,]
    new_row$AUTO.ID = 'PIPNAT'
    biosonic$AUTO.ID[row] = 'PIPPIP'
    biosonic = rbind(biosonic, new_row)
  }
}

# Translate classes from batdetect2
species_trans_b = c(
  `NYCVES` = 'ENV',
  `MYOSP` = 'M',
  `PIPNAT` = 'Pnat',
  `PIPPIP` = 'Ppip',
  `PIPPYG` = 'Ppyg',
  `NOISE` = 'noise'
)
biosonic$code = species_trans_b[biosonic$AUTO.ID]

# Translate classes from manual
manual$Annotation[manual$Annotation %in% c('Mdau', 'Mdas',
                                           'Mnat', 'm')] = 'M'
manual$Annotation[manual$Annotation %in% c('EVN', 'Nnoc', 'Vmur', 'Eser',
                                           'ENV', 'NVE')] =
  'ENV'
manual$Annotation[manual$Annotation %in% c('b', 'a')] = 'B'
manual$Annotation[manual$Annotation %in% c('s')] = 'S'

# Remove social and buzz = noise, and should not be annotated
manual = manual[!manual$Annotation %in% c('S', 'B', 'o', '?'),]

# Summarise manual per file
manual = manual[c('file', 'Annotation')] |> unique()

# List unique files
files = biosonic$file

# Create place holders for output
class_results = data.frame()

# Run through recordings
for(file in files){
  
  ## subset
  d = biosonic[biosonic$file == file,]
  g = manual[manual$file == file,]
  
  ## loop through detections
  for(row in seq_len(nrow(d))){
    if(d$code[row] %in% g$Annotation){
      class_results = rbind(class_results,
                            data.frame(file = file,
                                       d = d$code[row],
                                       g = d$code[row]))
    }
    if((!d$code[row] %in% g$Annotation) & d$code[row] != 'noise'){
      class_results = rbind(class_results,
                            data.frame(file = file,
                                       d = d$code[row],
                                       g = '-noise-'))
    }
    if(d$code[row] == 'noise' & nrow(g) == 0) {
        class_results = rbind(class_results,
                              data.frame(file = file,
                                         d = '-noise-',
                                         g = '-noise-'))
    } 
    if(d$code[row] == 'noise' & nrow(g) != 0)
        class_results = rbind(class_results,
                              data.frame(file = file,
                                         d = '-noise-',
                                         g = g$Annotation))
  }
  
  ## loop through ground truths for cases where there is a detection, but 
  ## not all ground truths have been detected
  for(row in seq_len(nrow(g))){
    if(!g$Annotation[row] %in% d$code & any(d$code != 'noise')) 
      class_results = rbind(class_results,
                            data.frame(file = file,
                                       d = '-noise-',
                                       g = g$Annotation[row]))
  }
  
} # end recording loop

# Compute stats
accuracy = length(which(class_results$d == class_results$g))/
  nrow(class_results)

# Plot confusion matrix
pdf(path_pdf, 10, 7.5)
# pdf(path_pdf, 15, 10)
par(mar = c(3.5, 4.5, 1, 7.5))
levels = sort(unique(c(class_results$d, class_results$g)))
conf_matrix = table(factor(class_results$d, levels = levels),
                    factor(class_results$g, levels = levels))
percentages = conf_matrix
for(i in seq_len(nrow(percentages))) 
  percentages[,i] = percentages[,i]/sum(percentages[,i]) * 100
color_gradient = colorRampPalette(c('lightblue', 'darkblue'))
plot(seq_along(levels), type = 'n', xlab = '', ylab = '',
     xlim = c(0.5, length(levels)+0.5), ylim = c(0.5, length(levels)+0.5),
     xaxt = 'n', yaxt = 'n')
mtext('biosonic', 1, 2.5)
mtext('ground truth', 2, 3.5)
for(i in seq_along(levels)){
  for(j in seq_along(levels)){
    rect(i - 0.5, j - 0.5, i + 0.5, j + 0.5,
         col = color_gradient(101)[as.numeric(percentages[i, j]+1)])
    text(i, j, labels = conf_matrix[i, j], col = 'white', cex = 1.5)
  }
}
mtext(rownames(conf_matrix), side = 2, at = seq_along(levels), las = 2,
      line = 0.75)
mtext(colnames(conf_matrix), side = 1, at = seq_along(levels), line = 0.75)
mtext(sprintf('accuracy = %.2f', round(accuracy, 2)), 
      side = 4, line = 1, at = 5.5, font = 1, las = 1, adj = 0)
dev.off()

# Message
message('Stored all results.')


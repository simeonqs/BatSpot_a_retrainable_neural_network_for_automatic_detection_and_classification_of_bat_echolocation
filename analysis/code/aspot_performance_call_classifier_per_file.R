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

# Paths
path_aspot = 'aspot/models_call_classifier/m09/combined_selection_tables'
path_ground_truth = 
  'analysis/data/call_detector/validation_data/ground_truth/denmark'
path_pdf = paste0('analysis/results/call_classifier/confusion_matrices/',
                  'confusion_matrix_per_file_m09.pdf')

# Load data
detection_files = list.files(path_aspot, full.names = TRUE)
aspot = load.selection.tables(path_aspot)
manual = load.selection.tables(path_ground_truth, recursive = TRUE)
rownames(manual) = seq_len(nrow(manual))

# Test if all files in are present
files_gt = list.files(path_ground_truth, recursive = TRUE) |> 
  basename() |> 
  str_remove('.Table.1.selections.txt') |>
  str_remove('.Band.Limited.Energy.Detector.selections.txt')
files_as = detection_files |> 
  basename() |> 
  str_remove('_predict_output.log.annotation.result.txt')
if(any(!files_as %in% files_gt)) stop('Missing ground truth.')
if(any(!files_gt %in% files_as)) stop('Missing detections.')

# Remove files with uncertain species
remove = manual$file[manual$Annotation %in% c('Ppippyg', 'Ppipnat')]
manual = manual[!manual$file %in% remove,]
aspot = aspot[!aspot$file %in% remove,]

# Summarise aspot per file
aspot_new = data.frame()
for(file in unique(aspot$file)){
  sub = aspot[aspot$file == file,]
  tab = table(sub$Annotations)
  for(sp in names(tab)[tab>=5]){
    aspot_new = rbind(aspot_new,
                      data.frame(file = file,
                                 annotation = sp))
  }
}

# Translate classes aspot
aspot_new = aspot_new[!aspot_new$annotation %in% c('s', 'B', 'bbar'),]
aspot_new$annotation[aspot_new$annotation %in% c('mbramys', 'mdas', 'mdau',
                                                 'mnat')] = 'M'
aspot_new$annotation[aspot_new$annotation %in% c('pnat')] = 'Pnat'
aspot_new$annotation[aspot_new$annotation %in% c('ppip')] = 'Ppip'
aspot_new$annotation[aspot_new$annotation %in% c('ppyg')] = 'Ppyg'
aspot_new$annotation[aspot_new$annotation %in% c('eser', 'nnoc', 
                                                 'vmur')] = 'ENV'
aspot_new = unique(aspot_new)

# Add noise for empty files
aspot_new = rbind(aspot_new,
                  data.frame(file = files_gt[!files_gt %in% aspot_new$file],
                             annotation = 'noise'))

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
files = files_gt

# Create place holders for output
class_results = data.frame()

# Run through recordings
for(file in files){
  
  ## subset
  d = aspot_new[aspot_new$file == file,]
  g = manual[manual$file == file,]
  
  ## loop through detections
  for(row in seq_len(nrow(d))){
    if(d$annotation[row] %in% g$Annotation){
      class_results = rbind(class_results,
                            data.frame(file = file,
                                       d = d$annotation[row],
                                       g = d$annotation[row]))
    }
    if((!d$annotation[row] %in% g$Annotation) & d$annotation[row] != 'noise'){
      class_results = rbind(class_results,
                            data.frame(file = file,
                                       d = d$annotation[row],
                                       g = '-noise-'))
    }
    if(d$annotation[row] == 'noise' & nrow(g) == 0) {
        class_results = rbind(class_results,
                              data.frame(file = file,
                                         d = '-noise-',
                                         g = '-noise-'))
    } 
    if(d$annotation[row] == 'noise' & nrow(g) != 0)
        class_results = rbind(class_results,
                              data.frame(file = file,
                                         d = '-noise-',
                                         g = g$Annotation))
  }
  
  ## loop through ground truths for cases where there is a detection, but 
  ## not all ground truths have been detected
  for(row in seq_len(nrow(g))){
    if(!g$Annotation[row] %in% d$annotation & any(d$annotation != 'noise')) 
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
mtext('batspot', 1, 2.5)
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


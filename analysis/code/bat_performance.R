# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
# Project: aspot bats
# Author: Simeon Q. Smeele
# Description: Plots confusion matrix for BAT
# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

# Loading libraries
libraries = c('stringr', 'callsync', 'caret', 'dplyr', 'data.table')
for(lib in libraries){
  if(! lib %in% installed.packages()) lapply(lib, install.packages)
  lapply(libraries, require, character.only = TRUE)
}

# Clean R
rm(list=ls()) 

# Paths
path_ground_truth = 
  'analysis/data/call_detector/validation_data/ground_truth/denmark'
path_bat = 'bat/BAT-cli-main/BAT.csv'
path_pdf = 'analysis/results/bat/confusion_matrix_bat.pdf'

# Load data
manual = load.selection.tables(path_ground_truth, recursive = TRUE)
rownames(manual) = seq_len(nrow(manual))
bat = fread(path_bat, header = FALSE, fill = TRUE, sep = ';', quote = '') |>
  as.data.frame()

# Make file name compatible
bat$file = bat$V1 |> basename() |> str_remove('.wav')

# Test if all files in are present
files_gt = list.files(path_ground_truth, recursive = TRUE) |> 
  basename() |> 
  str_remove('.Table.1.selections.txt') |>
  str_remove('.Band.Limited.Energy.Detector.selections.txt')
files_bat = bat$file
if(any(!files_bat %in% files_gt)) stop('Missing ground truth.')
if(any(!files_gt %in% files_bat)) stop('Missing detections.')

# Remove files with uncertain species
remove = manual$file[manual$Annotation %in% c('Ppippyg', 'Ppipnat', 'Pnatpip')]
manual = manual[!manual$file %in% remove,]
bat = bat[!bat$file %in% remove,]

# Translate classes
manual$Annotation[manual$Annotation %in% c('Mdau', 'Mdas',
                                           'Mnat', 'm')] = 'M'
manual$Annotation[manual$Annotation %in% c('EVN', 'Nnoc', 'Vmur', 'Eser',
                                           'ENV', 'NVE')] = 'ENV'
manual$Annotation[manual$Annotation %in% c('b', 'a')] = 'B'
manual$Annotation[manual$Annotation %in% c('s')] = 'S'
bat$V2[bat$V2 %in% c('Eptesicus serotinus', 'Nyctalus noctula', 
                     'Vespertilio murinus', 'Nyctalus leisleri')] = 'ENV'
bat$V2[str_detect(bat$V2, 'Myo')] = 'M'
bat$V2[bat$V2 == 'Pipistrellus nathusii'] = 'Pnat'
bat$V2[bat$V2 == 'Pipistrellus pipistrellus'] = 'Ppip'
bat$V2[bat$V2 %in% c('Miniopterus schreibersii', 'Pipistrellus kuhlii', 
                     'Rhinolophus hipposideros', '')] = '-noise-'

# Remove social and buzz = noise, and should not be annotated
manual = manual[!manual$Annotation %in% c('S', 'B', 'o', '?'),]

# Summarise per file
manual = manual[c('file', 'Annotation')] |> unique()
bat = bat[c('file', 'V2')] |> unique()
for(file in bat$file){
  sub = bat[bat$file == file,]
  if(nrow(sub) > 1) bat = bat[!(bat$V2 == '-noise-' &
                                  bat$file == file),]
}

# Make class_results
class_results = data.frame(file = bat$file,
                           species_bat = bat$V2)
class_results = merge(class_results, manual, 
                      by = 'file', all.x = TRUE, all.y = FALSE)
class_results$Annotation[is.na(class_results$Annotation)] = '-noise-'

# Plot confusion matrix
pdf(path_pdf, 5.5, 5)
par(mar = c(3.5, 5, 0.5, 0.5))
levels = sort(unique(c(class_results$species_bat, class_results$Annotation)))
conf_matrix = table(factor(class_results$species_bat, levels = levels),
                    factor(class_results$Annotation, levels = levels))
percentages = conf_matrix
for(i in seq_len(nrow(percentages))) 
  percentages[,i] = percentages[,i]/sum(percentages[,i]) * 100
color_gradient = colorRampPalette(c('lightblue', 'darkblue'))
plot(seq_along(levels), type = 'n', xlab = '', ylab = '',
     xlim = c(0.5, length(levels)+0.5), ylim = c(0.5, length(levels)+0.5),
     xaxt = 'n', yaxt = 'n')
mtext('BAT', 1, 2.5)
mtext('Ground truth', 2, 4)
for(i in seq_along(levels)){
  for(j in seq_along(levels)){
    rect(i - 0.5, j - 0.5, i + 0.5, j + 0.5,
         col = color_gradient(101)[as.numeric(percentages[i, j]+1)])
    text(i, j, labels = format(conf_matrix[i, j], 
                               big.mark = ',', 
                               batientific = FALSE), 
         col = 'white', cex = 1.5)
  }
}
mtext(rownames(conf_matrix), side = 2, at = seq_along(levels), las = 2,
      line = 0.75)
mtext(colnames(conf_matrix), side = 1, at = seq_along(levels), line = 0.75)
dev.off()

# Compute stats
if(sum(conf_matrix) != 200) stop('Wrong number of files in conf mat.')
## detection
tp = sum(conf_matrix[rownames(conf_matrix) != '-noise-', 
                     colnames(conf_matrix) != '-noise-'])
tn = sum(conf_matrix[rownames(conf_matrix) == '-noise-', 
                     colnames(conf_matrix) == '-noise-'])
fp = sum(conf_matrix[rownames(conf_matrix) != '-noise-', 
                     colnames(conf_matrix) == '-noise-'])
fn = sum(conf_matrix[rownames(conf_matrix) == '-noise-', 
                     colnames(conf_matrix) != '-noise-'])
recall =  tp/(tp+fn)
precision = tp/(tp+fp)
f1 = 2 * (precision*recall)/(precision+recall)
message('Recall: ', recall)
message('Precision: ', precision)
message('F1: ', f1)
## classification
sub_mat = conf_matrix[rownames(conf_matrix) != '-noise-', 
                      colnames(conf_matrix) != '-noise-']
accuracy = sum(diag(conf_matrix))/sum(conf_matrix)
message('Accuracy: ', accuracy)

# Message
message('Stored all results.')


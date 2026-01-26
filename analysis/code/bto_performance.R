# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
# Project: aspot bats
# Author: Simeon Q. Smeele
# Description: Plots confusion matrix for BTO.
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
path_ground_truth = 
  'analysis/data/call_detector/validation_data/ground_truth/denmark'
path_bto = 'bto/BatSpot_validation_set-results_17112025074107.csv'
path_pdf = 'analysis/results/bto/confusion_matrix_bto.pdf'

# Load data
manual = load.selection.tables(path_ground_truth, recursive = TRUE)
rownames(manual) = seq_len(nrow(manual))
bto = read.csv(path_bto)

# Make file name compatible
bto$file = bto$ORIGINAL.FILE.NAME |> str_remove('.wav')

# Test if all files in are present
files_gt = list.files(path_ground_truth, recursive = TRUE) |> 
  basename() |> 
  str_remove('.Table.1.selections.txt') |>
  str_remove('.Band.Limited.Energy.Detector.selections.txt')
files_bto = bto$file
if(any(!files_bto %in% files_gt)) stop('Missing ground truth.')
if(any(!files_gt %in% files_bto)) stop('Missing detections.')

# Translate classes
manual$Annotation[manual$Annotation %in% c('Mdau', 'Mdas',
                                           'Mnat', 'm')] = 'M'
manual$Annotation[manual$Annotation %in% c('EVN', 'Nnoc', 'Vmur', 'Eser',
                                           'ENV', 'NVE')] = 'ENV'
manual$Annotation[manual$Annotation %in% c('b', 'a')] = 'B'
manual$Annotation[manual$Annotation %in% c('s')] = 'S'
bto$SPECIES[bto$SPECIES %in% c('Eptser', 'Nycnoc', 'Vesmur')] = 'ENV'
bto$SPECIES[str_detect(bto$SPECIES, 'Myo')] = 'M'
bto$SPECIES[bto$SPECIES == 'Pipnat'] = 'Pnat'
bto$SPECIES[bto$SPECIES == 'Pippip'] = 'Ppip'
bto$SPECIES[bto$SPECIES == 'Pippyg'] = 'Ppyg'
bto$SPECIES[bto$SPECIES == 'Pleaur'] = 'Paur'
bto$SPECIES[bto$SPECIES %in% c('Aposyl', 'Barbar', 'bird',
                               'Leppun', 'No ID', 'Phogri',
                               'Sorara', 'Sormin', 'Ypoevo')] = '-noise-'
bto$SPECIES[bto$PROBABILITY < 0.1] = '-noise-'

# Remove social and buzz = noise, and should not be annotated
manual = manual[!manual$Annotation %in% c('S', 'B', 'o', '?'),]

# Summarise per file
manual = manual[c('file', 'Annotation')] |> unique()
for(f in bto$file){
  sub = bto[bto$file == f,]
  if(nrow(sub) > 1) bto = bto[!(bto$SPECIES == '-noise-' &
                                  bto$file == f),]
}
for(f in bto$file){
  sub = bto[bto$file == f,]
  to_keep = rownames(sub[sub$PROBABILITY == max(sub$PROBABILITY),])[1]
  bto = bto[!(bto$file == f & rownames(bto) != to_keep),]
}
bto = bto[,c('file', 'SPECIES')]

# Add noise for empty files
bto = rbind(bto,
            data.frame(file = files_gt[!files_gt %in% bto$file],
                       SPECIES = '-noise-'))

# Remove files with uncertain species
remove = manual$file[manual$Annotation %in% c('Ppippyg', 'Ppipnat', 'Pnatpip')]
manual = manual[!manual$file %in% remove,]
bto = bto[!bto$file %in% remove,]

# Make class_results
class_results = data.frame(file = bto$file,
                           species_bto = bto$SPECIES)
class_results = merge(class_results, manual, 
                      by = 'file', all.x = TRUE, all.y = FALSE)
class_results$Annotation[is.na(class_results$Annotation)] = '-noise-'

# Plot confusion matrix
pdf(path_pdf, 5.5, 5)
par(mar = c(3.5, 5, 0.5, 0.5))
levels = sort(unique(c(class_results$species_bto, class_results$Annotation)))
conf_matrix = table(factor(class_results$species_bto, levels = levels),
                    factor(class_results$Annotation, levels = levels))
percentages = conf_matrix
for(i in seq_len(nrow(percentages))) 
  percentages[,i] = percentages[,i]/sum(percentages[,i]) * 100
color_gradient = colorRampPalette(c('lightblue', 'darkblue'))
plot(seq_along(levels), type = 'n', xlab = '', ylab = '',
     xlim = c(0.5, length(levels)+0.5), ylim = c(0.5, length(levels)+0.5),
     xaxt = 'n', yaxt = 'n')
mtext('BTO', 1, 2.5)
mtext('Ground truth', 2, 4)
for(i in seq_along(levels)){
  for(j in seq_along(levels)){
    rect(i - 0.5, j - 0.5, i + 0.5, j + 0.5,
         col = color_gradient(101)[as.numeric(percentages[i, j]+1)])
    text(i, j, labels = format(conf_matrix[i, j], 
                               big.mark = ',', 
                               scientific = FALSE), 
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


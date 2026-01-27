# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
# Project: BatSpot  
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
path_batdetect2 = 'batdetect2/detections'
path_ground_truth = 
  'analysis/data/call_detector/validation_data/ground_truth/denmark'
path_pdf = 'analysis/results/batdetect2/confusion_matrix_0.4_per_file.pdf'

# Load data
detection_files = list.files(path_batdetect2, '*.csv', full.names = TRUE)
batdetect2 = detection_files |> lapply(read.csv) 
names(batdetect2) = detection_files |> basename() |> str_remove('.wav.csv')
batdetect2 = bind_rows(batdetect2, .id = 'file')
manual = load.selection.tables(path_ground_truth, recursive = TRUE)
rownames(manual) = seq_len(nrow(manual))


# Test if all files in are in the manual data frame
files_gt = list.files(path_ground_truth, recursive = TRUE) |> 
  basename() |> 
  str_remove('.Table.1.selections.txt') |>
  str_remove('.Band.Limited.Energy.Detector.selections.txt')
files_bt = detection_files |> 
  basename() |> 
  str_remove('.wav.csv')
if(any(!files_bt %in% files_gt)) stop('Missing ground truth.')
# if(any(!files_gt %in% files_bt)) stop('Missing detections.')
missing = files_gt[!files_gt %in% files_bt]

# Remove files with uncertain species
remove = manual$file[manual$Annotation %in% c('Ppippyg', 'Ppipnat', 'Pnatpip')]
manual = manual[!manual$file %in% remove,]
batdetect2 = batdetect2[!batdetect2$file %in% remove,]

# Translate classes from batdetect2
species_trans_b = c(
  `Barbastellus barbastellus` = '-noise-',
  `Eptesicus serotinus` = 'ENV',
  `Myotis bechsteinii` = 'M',
  `Myotis brandtii` = 'M',
  `Myotis daubentonii` = 'M',
  `Myotis mystacinus` = 'M',
  `Myotis nattereri` = 'M',
  `Nyctalus leisleri` = 'ENV',
  `Nyctalus noctula` = 'ENV',
  `Pipistrellus nathusii` = 'Pnat',
  `Pipistrellus pipistrellus` = 'Ppip',
  `Pipistrellus pygmaeus` = 'Ppyg',
  `Plecotus auritus` = 'Paur',
  `Plecotus austriacus` = '-noise-',
  `Rhinolophus ferrumequinum` = '-noise-'
)
# species_trans_b = c(
#   `Barbastellus barbastellus` = 'Bbar',
#   `Eptesicus serotinus` = 'Eser',
#   `Myotis bechsteinii` = 'Mbec',
#   `Myotis brandtii` = 'Mbra',
#   `Myotis daubentonii` = 'Mdau',
#   `Myotis mystacinus` = 'Mmys',
#   `Myotis nattereri` = 'Mnat',
#   `Nyctalus leisleri` = 'Nlei',
#   `Nyctalus noctula` = 'Nnoc',
#   `Pipistrellus nathusii` = 'Pnat',
#   `Pipistrellus pipistrellus` = 'Ppip',
#   `Pipistrellus pygmaeus` = 'Ppyg',
#   `Plecotus auritus` = 'Paur',
#   `Plecotus austriacus` = 'Paus',
#   `Rhinolophus ferrumequinum` = 'Rfer'
# )
batdetect2$code = species_trans_b[batdetect2$class]

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

# Summarise per file
manual = manual[c('file', 'Annotation')] |> unique()
for(f in batdetect2$file){
  sub = batdetect2[batdetect2$file == f,]
  if(nrow(sub) > 1) batdetect2 = batdetect2[!(batdetect2$code == '-noise-' &
                                                batdetect2$file == f),]
}
for(f in batdetect2$file){
  sub = batdetect2[batdetect2$file == f,]
  to_keep = rownames(sub[sub$class_prob == max(sub$class_prob),])[1]
  batdetect2 = batdetect2[!(batdetect2$file == f & 
                              rownames(batdetect2) != to_keep),]
}
batdetect2 = rbind(batdetect2[,c('file', 'code')], 
                   data.frame(file = missing,
                              code = '-noise-'))

# Make class_results
class_results = data.frame(file = batdetect2$file,
                           species_bt = batdetect2$code)
class_results = merge(class_results, manual, 
                      by = 'file', all.x = TRUE, all.y = FALSE)
class_results$Annotation[is.na(class_results$Annotation)] = '-noise-'

# Plot confusion matrix
pdf(path_pdf, 5.5, 5)
par(mar = c(3.5, 5, 0.5, 0.5))
levels = sort(unique(c(class_results$species_bt, class_results$Annotation)))
conf_matrix = table(factor(class_results$species_bt, levels = levels),
                    factor(class_results$Annotation, levels = levels))
percentages = conf_matrix
for(i in seq_len(nrow(percentages))) 
  percentages[,i] = percentages[,i]/sum(percentages[,i]) * 100
color_gradient = colorRampPalette(c('lightblue', 'darkblue'))
plot(seq_along(levels), type = 'n', xlab = '', ylab = '',
     xlim = c(0.5, length(levels)+0.5), ylim = c(0.5, length(levels)+0.5),
     xaxt = 'n', yaxt = 'n')
mtext('BatDetect2', 1, 2.5)
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


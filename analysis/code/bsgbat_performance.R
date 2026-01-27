# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
# Project: BatSpot
# Author: Simeon Q. Smeele
# Description: Plots confusion matrix for BSG-BAT.
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
path_bsgbat = 'bsgbat/outfile'
path_pdf = 'analysis/results/bsg_bat/confusion_matrix_bsgbat.pdf'

# Load data
manual = load.selection.tables(path_ground_truth, recursive = TRUE)
rownames(manual) = seq_len(nrow(manual))

df = read.delim(
  path_bsgbat,
  header = FALSE,
  stringsAsFactors = FALSE,
  sep = '\t',
  col.names = c('filepath', 'labels')
)

pred = vapply(seq_len(nrow(df)), function(i) {
  parts = str_split(df$labels[i], ',')[[1]]
  if(length(parts) == 1) parts = c('Background', "1")
  names = parts[seq(1, length(parts), by = 2)]
  counts = as.numeric(parts[seq(2, length(parts), by = 2)])
  idx_nb = which(names != 'Background')
  if (length(idx_nb) > 0) {
    idx = idx_nb[which.max(counts[idx_nb])]
  } else {
    idx = which.max(counts)
  }
  names[idx]
}, character(1))

filenames = df$file |> str_remove('.wav')

bsg_bat = data.frame(file = filenames |> basename(), 
                     SPECIES = pred)

# Test if all files in are present
files_gt = list.files(path_ground_truth, recursive = TRUE) |> 
  basename() |> 
  str_remove('.Table.1.selections.txt') |>
  str_remove('.Band.Limited.Energy.Detector.selections.txt')
files_bsgbat = bsg_bat$file
if(any(!files_bsgbat %in% files_gt)) stop('Missing ground truth.')
if(any(!files_gt %in% files_bsgbat)) stop('Missing detections.')

# Translate classes
manual$Annotation[manual$Annotation %in% c('Mdau', 'Mdas',
                                           'Mnat', 'm')] = 'M'
manual$Annotation[manual$Annotation %in% c('EVN', 'Nnoc', 'Vmur', 'Eser',
                                           'ENV', 'NVE')] = 'ENV'
manual$Annotation[manual$Annotation %in% c('b', 'a')] = 'B'
manual$Annotation[manual$Annotation %in% c('s')] = 'S'
bsg_bat$SPECIES[bsg_bat$SPECIES %in% c('Eptesicus_nilssonii', 
                                       'Eptesicus_serotinus', 
                                       'Nyctalus_leisleri', 
                                       'Nyctalus_noctula')] = 'ENV'
bsg_bat$SPECIES[str_detect(bsg_bat$SPECIES, 'Myo')] = 'M'
bsg_bat$SPECIES[bsg_bat$SPECIES %in% c('Pipistrellus_nathusii',
                                       'Pipistrellus_kuhlii')] = 'Pnat'
bsg_bat$SPECIES[bsg_bat$SPECIES == 'Pipistrellus_pipistrellus'] = 'Ppip'
bsg_bat$SPECIES[bsg_bat$SPECIES == 'Pipistrellus_pygmaeus'] = 'Ppyg'
bsg_bat$SPECIES[bsg_bat$SPECIES == 'Plecotus_auritus'] = 'Paur'
bsg_bat$SPECIES[bsg_bat$SPECIES %in% c('Background', 
                                       'Barbastella_barbastellus', 
                                       'Hypsugo_savii',
                                       'Miniopterus_schreibersii', 
                                       'Tadarida_teniotis')] = '-noise-'

# Remove social and buzz = noise, and should not be annotated
manual = manual[!manual$Annotation %in% c('S', 'B', 'o', '?'),]

# Summarise per file
manual = manual[c('file', 'Annotation')] |> unique()
for(f in bsg_bat$file){
  sub = bsg_bat[bsg_bat$file == f,]
  if(nrow(sub) > 1) bsg_bat = bsg_bat[!(bsg_bat$SPECIES == '-noise-' &
                                          bsg_bat$file == f),]
}

# Remove files with uncertain species
remove = manual$file[manual$Annotation %in% c('Ppippyg', 'Ppipnat', 'Pnatpip')]
manual = manual[!manual$file %in% remove,]
bsg_bat = bsg_bat[!bsg_bat$file %in% remove,]

# Make class_results
class_results = data.frame(file = bsg_bat$file,
                           species_bsgbat = bsg_bat$SPECIES)
class_results = merge(class_results, manual, 
                      by = 'file', all.x = TRUE, all.y = FALSE)
class_results$Annotation[is.na(class_results$Annotation)] = '-noise-'

# Plot confusion matrix
pdf(path_pdf, 5.5, 5)
par(mar = c(3.5, 5, 0.5, 0.5))
levels = sort(unique(c(class_results$species_bsgbat, class_results$Annotation)))
conf_matrix = table(factor(class_results$species_bsgbat, levels = levels),
                    factor(class_results$Annotation, levels = levels))
percentages = conf_matrix
for(i in seq_len(nrow(percentages))) 
  percentages[,i] = percentages[,i]/sum(percentages[,i]) * 100
color_gradient = colorRampPalette(c('lightblue', 'darkblue'))
plot(seq_along(levels), type = 'n', xlab = '', ylab = '',
     xlim = c(0.5, length(levels)+0.5), ylim = c(0.5, length(levels)+0.5),
     xaxt = 'n', yaxt = 'n')
mtext('BSG-BAT', 1, 2.5)
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


# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
# Project: BatSpot  
# Author: Simeon Q. Smeele
# Description: Plots confusion matrix for call detector.
# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

# Loading libraries
libraries = c('stringr', 'callsync', 'caret')
for(lib in libraries){
  if(! lib %in% installed.packages()) lapply(lib, install.packages)
  lapply(libraries, require, character.only = TRUE)
}

# Clean R
rm(list=ls()) 

# Settings
model = 'm03'

# Paths
path_aspot = sprintf('%s/%s/selection_tables', 
                     'aspot/models_call_detector', model)
path_ground_truth = 
  'analysis/data/call_detector/validation_data/ground_truth/denmark'
path_pdf = paste0('analysis/results/call_detector/confusion_matrices/',
                  'confusion_matrix_call_detector_', model, '.pdf')

# Load data
detection_files = list.files(path_aspot, full.names = TRUE)
aspot = load.selection.tables(path_aspot)
manual = load.selection.tables(path_ground_truth, recursive = TRUE)
rownames(manual) = seq_len(nrow(manual))
manual$Annotation = ifelse(manual$Annotation %in% c('a', 'b', 's'), 
                           'noise', 'target')

# Test if all files in are present
files_gt = list.files(path_ground_truth, '*.txt', recursive = TRUE) |> 
  basename() |> 
  str_remove('.Table.1.selections.txt') |>
  str_remove('.Band.Limited.Energy.Detector.selections.txt')
files_as = detection_files |> 
  basename() |> 
  str_remove('_predict_output.log.annotation.result.txt')
if(any(!files_as %in% files_gt)) stop('Missing ground truth.')
if(any(!files_gt %in% files_as)) stop('Missing detections.')

# Remove noise annotations
manual = manual[manual$Annotation == 'target',]

# Function to calculate overlap
calc.iou = function(st_d, st_g, end_d, end_g){
  union = max(end_d, end_g) - min(st_d, st_g)
  intercept = min(end_d, end_g) - max(st_d, st_g)
  if(intercept > union) stop('Error in calc.overlap.')
  return(intercept/union)
}

# List unique files
files = list.files(path_ground_truth, recursive = TRUE) |> basename() |>
  str_remove('.Table.1.selections.txt')

# Create place holders for output
fps = fns = tps = c()
class_results = data.frame()

# Run through images
for(file in files){
  
  ## subset
  d = aspot[aspot$file == file,]
  g = manual[manual$file == file,]
  
  ## run through detections and ground truths
  links = data.frame(row_d = numeric(),
                     row_g = numeric())
  for(row_d in rownames(d)){
    for(row_g in rownames(g)){
      links = rbind(links,
                    data.frame(file = file,
                               row_d = row_d, 
                               row_g = row_g, 
                               g = manual[row_g,]$Annotation,
                               d = aspot[row_d,]$Sound.type,
                               iou = calc.iou(d[row_d,]$Begin.time..s.,
                                              g[row_g,]$Begin.Time..s.,
                                              d[row_d,]$End.time..s.,
                                              g[row_g,]$End.Time..s.)))
    }
  }
  
  ## only keep if some overlap
  links = links[links$iou > 0,]
  
  ## run through ground truths and remove all but one link
  ## first order so that the ones with highest overlap are at the top
  ## then remove duplications (which will not be the top entry)
  if(nrow(links) > 1){
    links = links[order(links$iou, decreasing = TRUE),]
    links = links[!duplicated(links$row_g),]
    links = links[!duplicated(links$row_d),]
  }
  
  ## check if there are any duplications left
  if(any(duplicated(links$row_d)) | any(duplicated(links$row_g)))
    stop('Found duplications in file ', image, '.')
  
  ## store remaining
  class_results = rbind(class_results,
                        links)
  
  ## get fps
  new_fps = rownames(d)[!rownames(d) %in% links$row_d]
  fps = c(fps, new_fps)
  
  ## get fns
  new_fns = rownames(g)[!rownames(g) %in% links$row_g]
  fns = c(fns, new_fns)
  
} # end image loop

# Add false positives as such
if(length(fps) > 0)
  class_results = rbind(class_results,
                        data.frame(file = aspot[fps,]$file,
                                   row_d = fps,
                                   row_g = NA,
                                   d = aspot[fps,]$Sound.type,
                                   g = 'noise',
                                   iou = NA))

# Add false negatives as such
if(length(fns) > 0)
  class_results = rbind(class_results,
                        data.frame(file = manual[fns,]$file,
                                   row_d = NA,
                                   row_g = fns,
                                   d = 'noise',
                                   g = manual[fns,]$Annotation,
                                   iou = NA))

# Run checks
if(any(duplicated(class_results$row_d[!is.na(class_results$row_d)]))) 
  stop('Duplications in row d.')
if(any(duplicated(class_results$row_g[!is.na(class_results$row_g)]))) 
  stop('Duplications in row g.')
if(any(!rownames(aspot) %in% class_results$row_d)) 
  stop('Missing rows from Animal Spot.')
if(any(!rownames(manual) %in% 
       class_results$row_g)) 
  stop('Missing rows from ground truth.')

# Compute stats
tps = which(class_results$d == class_results$g)
precision_detection = length(tps)/sum(length(tps), length(fps))
recall_detection = length(tps)/sum(length(tps), length(fns))
F1_detection = 2 * (precision_detection * recall_detection) / 
  (precision_detection + recall_detection)

# Plot confusion matrix
pdf(path_pdf, 4.2, 2.8)
par(mar = c(3.5, 4.5, 1, 7.5))
levels = sort(unique(c(class_results$d, class_results$g)))
conf_matrix = table(factor(class_results$d, levels = levels),
                    factor(class_results$g, levels = levels))
percentages = conf_matrix
percentages = percentages/sum(percentages) * 100
color_gradient = colorRampPalette(c('lightblue', 'darkblue'))
plot(seq_along(levels), type = 'n', xlab = '', ylab = '',
     xlim = c(0.5, length(levels)+0.5), ylim = c(0.5, length(levels)+0.5),
     xaxt = 'n', yaxt = 'n')
mtext('aspot', 1, 2.5)
mtext('ground truth', 2, 3.5)
for(i in seq_along(levels)){
  for(j in seq_along(levels)){
    if(i == 1 & j == 1) next
    rect(i - 0.5, j - 0.5, i + 0.5, j + 0.5,
         col = color_gradient(101)[as.numeric(percentages[i, j]+1)])
    text(i, j, labels = conf_matrix[i, j], col = 'white', cex = 1.5)
  }
}
mtext(rownames(conf_matrix), side = 2, at = seq_along(levels), las = 2,
      line = 0.75)
mtext(colnames(conf_matrix), side = 1, at = seq_along(levels), line = 0.75)
mtext('performance:', side = 4, line = 1, at = 2.2, font = 2, las = 1, adj = 0)
mtext(sprintf('F1 = %.2f', round(F1_detection, 2)), 
      side = 4, line = 1, at = 1.9, font = 1, las = 1, adj = 0)
mtext(sprintf('precision = %.2f', round(precision_detection, 2)), 
      side = 4, line = 1, at = 1.6, font = 1, las = 1, adj = 0)
mtext(sprintf('recall = %.2f', round(recall_detection, 2)), 
      side = 4, line = 1, at = 1.3, font = 1, las = 1, adj = 0)
dev.off()

# Message
message('Stored all results.')
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
path_aspot = 'aspot/models_call_classifier/m06/combined_selection_tables'
path_ground_truth = 
  'analysis/data/call_detector/validation_data/ground_truth/denmark'
path_pdf = paste0('analysis/results/call_classifier/confusion_matrices/',
                  'confusion_matrix_m03_m06.pdf')
  
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

# Translate classes from manual
manual$Annotation[manual$Annotation %in% c('Mdau', 'Mdas', 'Mnat', 'm')] = 'M'
manual$Annotation[manual$Annotation %in% c('EVN', 'Nnoc', 'Vmur', 'Eser',
                                           'ENV', 'NVE')] = 
  'ENV'
manual$Annotation[manual$Annotation %in% c('b', 'a')] = 'B'
manual$Annotation[manual$Annotation %in% c('s')] = 'S'

# Remove social and buzz = noise, and should not be annotated
manual = manual[!manual$Annotation %in% c('S', 'B'),]

# Translate classes from model
aspot$Annotations = str_to_title(aspot$Annotations)
aspot$Annotations[aspot$Annotations %in% 
                    c('Mdau', 'Mdas', 'Mnat', 'Mbramys')] = 'M'
aspot$Annotations[aspot$Annotations %in% c('Nnoc', 'Vmur', 'Eser')] = 
  'ENV'

# Social and buzz are noise -> turn all noise into separate category
aspot$Annotations[aspot$Annotations %in% c('S', 'B', 'noise')] = '-noise-'
# aspot$Annotations[aspot$Annotations %in% c('noise')] = '-noise-'

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

# Run through recordings
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
                               d = aspot[row_d,]$Annotations,
                               iou = calc.iou(d[row_d,]$Begin.Time..s.,
                                              g[row_g,]$Begin.Time..s.,
                                              d[row_d,]$End.Time..s.,
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
    stop('Found duplications in file ', recording, '.')
  
  ## store remaining
  class_results = rbind(class_results,
                        links)
  
  ## get fps
  new_fps = rownames(d)[!rownames(d) %in% links$row_d]
  fps = c(fps, new_fps)
  
  ## get fns
  new_fns = rownames(g)[!rownames(g) %in% links$row_g]
  fns = c(fns, new_fns)
  
} # end recording loop

# Add false positives as such
if(length(fps) > 0)
  class_results = rbind(class_results,
                        data.frame(file = aspot[fps,]$file,
                                   row_d = fps,
                                   row_g = NA,
                                   d = aspot[fps,]$Annotations,
                                   g = 'noise',
                                   iou = NA))

# Add false negatives as such
if(length(fns) > 0)
  class_results = rbind(class_results,
                        data.frame(file = manual[fns,]$file,
                                   row_d = NA,
                                   row_g = fns,
                                   d = '-missed-',
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

# Remove overlapping, social, etc. 
class_results = class_results[!class_results$g %in% 
                                c('?', 'o', 'Ppippyg', 'Ppipnat'),]

# Fix some names
class_results$g[class_results$g == 'noise'] = '-noise-'
class_results$d[class_results$d == 'Noise'] = '-noise-'

# Compute stats
accuracy_overall = length(which(class_results$d == class_results$g))/
  nrow(class_results)
tp_detection = length(which(class_results$g != '-noise-' &
                              class_results$d != '-missed-'))
fp_detection = length(which(class_results$g == '-noise-' &
                              class_results$d != '-missed-'))
fn_detection = length(which(class_results$g != '-noise-' &
                              class_results$d == '-missed-'))
# tp_detection = length(which(class_results$g != '-noise-' &
#                               (!class_results$d %in% c('-noise-', 
#                                                        '-missed-'))))
# fp_detection = length(which(class_results$g == '-noise-' &
#                               (!class_results$d %in% c('-noise-', 
#                                                        '-missed-'))))
# fn_detection = length(which(class_results$g != '-noise-' &
#                               class_results$d %in% c('-noise-', 
#                                                      '-missed-')))
if(sum(tp_detection, fp_detection, fn_detection) != nrow(class_results))
  stop('This doesn not add up.')
accuracy_detection = tp_detection/nrow(class_results)
precision_detection = tp_detection/sum(tp_detection, fp_detection)
recall_detection = tp_detection/sum(tp_detection, fn_detection)
f1_detection = 2*precision_detection*recall_detection/
  (precision_detection+recall_detection)
correct_classification = length(which(class_results$g == class_results$d &
                                        class_results$g != '-noise-'))
incorrect_classification = length(which(class_results$g != class_results$d &
                                          class_results$g != '-noise-'))
accuracy_classification = correct_classification/
  sum(correct_classification, incorrect_classification)

# Plot confusion matrix
pdf(path_pdf, 10, 7.5)
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
mtext('aspot', 1, 2.5)
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
mtext('Overall:', side = 4, line = 1, at = 6, font = 2, las = 1, adj = 0)
mtext(sprintf('accuracy = %.2f', round(accuracy_overall, 2)), 
      side = 4, line = 1, at = 5.5, font = 1, las = 1, adj = 0)
mtext('Detection:', side = 4, line = 1, at = 4.5, font = 2, las = 1, adj = 0)
mtext(sprintf('accuracy = %.2f', round(accuracy_detection, 2)), 
      side = 4, line = 1, at = 4, font = 1, las = 1, adj = 0)
mtext(sprintf('precision = %.2f', round(precision_detection, 2)), 
      side = 4, line = 1, at = 3.5, font = 1, las = 1, adj = 0)
mtext(sprintf('recall = %.2f', round(recall_detection, 2)), 
      side = 4, line = 1, at = 3, font = 1, las = 1, adj = 0)
mtext(sprintf('F1 = %.2f', round(f1_detection, 2)), 
      side = 4, line = 1, at = 2.5, font = 1, las = 1, adj = 0)
mtext('Classification:', side = 4, line = 1, at = 1.5, 
      font = 2, las = 1, adj = 0)
mtext(sprintf('accuracy = %.2f', round(accuracy_classification, 2)), 
      side = 4, line = 1, at = 1, font = 1, las = 1, adj = 0)
dev.off()

# Message
message('Stored all results.')


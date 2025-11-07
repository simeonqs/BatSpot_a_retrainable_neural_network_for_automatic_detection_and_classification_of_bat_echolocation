# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
# Project: aspot bats  
# Author: Simeon Q. Smeele
# Description: Plots confusion matrix for biosonic classification that 
# includes the ENV species separately. 
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
path_biosonic = 
  'analysis/results/biosonic/results_second_test_set_with_ENV_split.csv'
path_ground_truth_1 = 
  'analysis/data/call_detector/validation_data/ground_truth/denmark'
path_ground_truth_2 = 
  'analysis/results/biosonic/ground_truth_second_test_set_with_ENV_split.csv'
path_translation = 'analysis/results/biosonic/translation_second_test_set.csv'
path_pdf = 'analysis/results/biosonic/confusion_matrix_ENV.pdf'

# Load data
biosonic = read.csv(path_biosonic)
manual = load.selection.tables(path_ground_truth_1, recursive = TRUE)
rownames(manual) = seq_len(nrow(manual))
translation = read.csv(path_translation)

# Translate biosonic file names
biosonic$file = vapply(biosonic$FILE.NAME, function(x){
  return(translation$name[translation$newname == x |> str_remove('.WAV') |>
                            as.integer()])
}, character(1))
biosonic$file = biosonic$file |> str_remove('.wav') |> str_remove('.WAV')

# For multispecies rows add an extra row for second species
for(row in seq_len(nrow(biosonic))){
  if(str_detect(biosonic$AUTO.ID[row], ',')){
    split = strsplit(biosonic$AUTO.ID[row], ',')[[1]]
    biosonic$AUTO.ID[row] = split[1]
    for(i in seq_len(length(split))[-1]){
      new_row = biosonic[row,]
      new_row$AUTO.ID = split[i]
      biosonic = rbind(biosonic, new_row)
    }
  }
}

# Translate classes from biosonic
species_trans_b = c(
  `EPSTER` = 'Eser',
  `EPTSER` = 'Eser',
  `NYCNOC` = 'Nnoc',
  `VESMUR` = 'Vmur',
  `MYODAU` = 'M',
  `MYONAT` = 'M',
  `MYODAS` = 'M',
  `PIPNAT` = 'Pnat',
  `PIPPIP` = 'Ppip',
  `PIPPYG` = 'Ppyg',
  `PLEAUR` = 'Paur',
  `NOISE` = '-noise-'
)
biosonic$code = species_trans_b[biosonic$AUTO.ID]

# Translate classes from manual
manual$Annotation[manual$Annotation %in% c('Mdau', 'Mdas',
                                           'Mnat', 'm')] = 'M'
manual$Annotation[manual$Annotation == 'PPip'] = 'Ppip'
manual$Annotation[manual$Annotation %in% c('EVN', 'ENV', 'NVE')] = 'ENV'
manual$Annotation[manual$Annotation %in% c('b', 'a')] = 'B'
manual$Annotation[manual$Annotation %in% c('s')] = 'S'

# Remove social and buzz = noise, and should not be annotated
manual = manual[!manual$Annotation %in% c('S', 'B', 'o', '?'),]

# Summarise manual per file
manual = manual[c('file', 'Annotation')] |> unique()

# Add annotations from set two
manual_2 = read.csv(path_ground_truth_2)
manual_2$species[manual_2$species %in% c('Mdau', 'Mdas',
                                         'Mnat', 'Myosp')] = 'M'
colnames(manual_2) = c('file', 'Annotation')
manual = rbind(manual, manual_2) 
manual$file = manual$file |> str_remove('.wav') |> str_remove('.WAV')

# Remove files with uncertain species
remove = manual$file[manual$Annotation %in% c('Ppippyg', 'Ppipnat', 'Pnatpip',
                                              'ENV')]
manual = manual[!manual$file %in% remove,]
biosonic = biosonic[!biosonic$file %in% remove,]

# Remove file with error
manual = manual[manual$file != 'DB_ID_832_Nnoc_280724_2318',]
biosonic = biosonic[biosonic$file != 'DB_ID_832_Nnoc_280724_2318',]

# Make upper case filenames to ensure match if fiddled with
biosonic$file = toupper(biosonic$file)
manual$file = toupper(manual$file)

# Test if files missing in biosonic
missing = which(!manual$file %in% biosonic$file)
if(length(missing)> 0) 
  stop('Missing detection files:\n', 
       paste(manual$file[missing], collapse = '\n'))
mfs = list.files(path_ground_truth_1) |> toupper() |> 
  str_remove('.TABLE.1.SELECTIONS.TXT')
missing = which(!biosonic$file %in% c(manual$file, mfs))
if(length(missing)> 0) 
  stop('Missing ground truth files:\n', 
       paste(biosonic$file[missing], collapse = '\n'))

# List unique files
files = unique(biosonic$file)

# Create place holders for output
class_results = data.frame()

# Run through recordings
for(file in files){
  
  ## subset
  d = biosonic[biosonic$file == file,]
  g = manual[manual$file == file,]
  
  ## add noise to manual if empty
  if(nrow(g) == 0) g = data.frame(file = file,
                                  Annotation = '-noise-')
  
  ## check that noise is only annotation
  if('-noise-' %in% d$code & nrow(d) > 1) 
    stop('Noise and annotation in detections.')
  if('-noise-' %in% g$Annotation & nrow(g) > 1) 
    stop('Noise and annotation in ground truth.')
  
  ## get all true positives
  tps = which(d$code %in% g$Annotation)
  if(length(tps) > 0){
    class_results = rbind(class_results,
                          data.frame(file = file,
                                     d = d$code[tps],
                                     g = d$code[tps]))
    g = g[!g$Annotation %in% d$code,]
    d = d[-tps,]
  }
  if(nrow(g) == 0 & nrow(d) == 0) next
  
  ## if only one left in each, use those as misclassification
  if(nrow(g) == 1 & nrow(d) == 1){
    class_results = rbind(class_results,
                          data.frame(file = file,
                                     d = d$code,
                                     g = g$Annotation))
    next
  }
  
  ## if no detections, but groundtruth, add as false negative
  if(nrow(g) > 0 & nrow(d) == 0){
    class_results = rbind(class_results,
                          data.frame(file = file,
                                     d = '-none-',
                                     g = g$Annotation))
    next
  }
  
  ## if detections, but no groundtruth, add as false positive
  if(nrow(g) == 0 & nrow(d) > 0){
    class_results = rbind(class_results,
                          data.frame(file = file,
                                     d = d$code,
                                     g = '-none-'))
    next
  }
  
  ## if d is noise, g is not, add as false negative
  if('-noise-' %in% d$code & nrow(g) > 0){
    class_results = rbind(class_results,
                          data.frame(file = file,
                                     d = '-noise-',
                                     g = g$Annotation))
    next
  }
  
  ## if g is noise, d is not, add as false positives
  if('-noise-' %in% g$Annotation & nrow(d) > 0){
    class_results = rbind(class_results,
                          data.frame(file = file,
                                     d = d$code,
                                     g = '-noise-'))
    next
  }
  
  ## if none of the above went to next, there are only misclassifications
  ## and potentially false positives and negatives left, by adding '-none-'
  ## to the shortest data frame, everything should work out, by ordering first
  ## it's more likely that similar species end up together
  d = d[order(d$code),]
  g = g[order(g$Annotation),]
  diff = nrow(d) - nrow(g)
  if(diff > 0) g = rbind(g, data.frame(file = file,
                                       Annotation = rep('-none-', diff)))
  if(diff < 0) d = rbind(d, data.frame(FILE.NAME = NA,
                                       AUTO.ID = NA,
                                       COONFIDENCE.1st.species = NA,
                                       CONFIDENCE.2nd..3rd.and.4th.species = 
                                         NA,
                                       ERRORS = NA,
                                       file = file,
                                       code = rep('-none-', abs(diff))))
  
  class_results = rbind(class_results,
                        data.frame(file = file,
                                   d = d$code,
                                   g = g$Annotation))
  
} # end recording loop

# Compute stats
accuracy = length(which(class_results$d == class_results$g))/
  nrow(class_results)

# Plot confusion matrix
pdf(path_pdf, 10, 7.5)
# pdf(path_pdf, 15, 10)
par(mar = c(3.5, 4.5, 1, 7.5))
levels = sort(unique(c(class_results$d, class_results$g)))
conf_matrix = table(factor(class_results$d, levels = levels |> sort()),
                    factor(class_results$g, levels = levels |> sort()))
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


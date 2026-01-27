# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
# Project: BatSpot  
# Author: Simeon Q. Smeele
# Description: Plots coverage from validation. 
# >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

# Loading libraries
libraries = c('stringr')
for(lib in libraries){
  if(! lib %in% installed.packages()) lapply(lib, install.packages)
  lapply(libraries, require, character.only = TRUE)
}

# Clean R
rm(list=ls()) 

# Buzz detector ---------------------------------------------------------------

# Paths
path_meta_stations = 
  'analysis/data/buzz_detector/validation_data/meta_data_stations.csv'
path_meta_files = 
  'analysis/data/buzz_detector/validation_data/meta_data_validation_files.csv'
path_pdf = 'analysis/results/buzz_detector/validation_coverage.pdf'

# Load data
meta_stations = read.csv(path_meta_stations)
meta_files = read.csv(path_meta_files)

# Fix dates
meta_stations$start = meta_stations$start |> as.character() |> 
  as.Date(format = '%Y%m%d')
meta_stations$end = meta_stations$end |> as.character() |> 
  as.Date(format = '%Y%m%d')
meta_files$date = meta_files$date |> as.character() |> 
  as.Date(format = '%Y%m%d')

# Translate stations to numeric
trans_stations = seq_len(length(unique(meta_stations$station)))
names(trans_stations) = unique(meta_stations$station)

# Plot
pdf(path_pdf, 12, 8)
xmin = min(meta_stations$start)
xmax = max(meta_stations$end)
par(mar = c(4, 7, 0.5, 0.5))
plot(NULL, 
     xlim = c(xmin, xmax),
     ylim = c(0.5, max(trans_stations) + 0.5), 
     xaxt = 'n', yaxt = 'n', xlab = 'Date', ylab = '')
for(i in seq_len(nrow(meta_stations))) 
  lines(c(meta_stations$start[i], meta_stations$end[i]),
        rep(trans_stations[meta_stations$station[i]], 2), 
        lwd = 20, col = '#2874A6')
points(meta_files$date, trans_stations[meta_files$station],
       pch = 16, cex = 2,
       col = ifelse(!is.na(meta_files$with_buzz), '#17A589', '#EC7063'))
date_axis = seq(xmin, xmax, by = 'month')
axis(1, date_axis, date_axis |> str_sub(1, 7))
axis(2, trans_stations, names(trans_stations), las = 1)
dev.off()

# Call detector ---------------------------------------------------------------

# Paths
path_meta_stations = 
  'analysis/data/call_detector/validation_data/meta_data_stations.csv'
path_meta_files = 
  'analysis/data/call_detector/validation_data/meta_data_validation_files.csv'
path_pdf = 'analysis/results/call_detector/validation_coverage.pdf'

# Load data
meta_stations = read.csv(path_meta_stations)
meta_files = read.csv(path_meta_files)

# Fix dates
meta_stations$start = meta_stations$start |> as.character() |> 
  as.Date(format = '%Y%m%d')
meta_stations$end = meta_stations$end |> as.character() |> 
  as.Date(format = '%Y%m%d')
meta_files$date = meta_files$date |> as.character() |> 
  as.Date(format = '%Y%m%d')

# Translate stations to numeric
trans_stations = seq_len(length(unique(meta_stations$station)))
names(trans_stations) = unique(meta_stations$station)

# Plot
pdf(path_pdf, 10, 6)
xmin = min(meta_stations$start)
xmax = max(meta_stations$end)
par(mar = c(4, 7, 0.5, 0.5))
plot(NULL, 
     xlim = c(xmin, xmax),
     ylim = c(0.5, max(trans_stations) + 0.5), 
     xaxt = 'n', yaxt = 'n', xlab = 'Date', ylab = '')
for(i in seq_len(nrow(meta_stations))) 
  lines(c(meta_stations$start[i], meta_stations$end[i]),
        rep(trans_stations[meta_stations$station[i]], 2), 
        lwd = 20, col = '#2874A6')
points(meta_files$date, trans_stations[meta_files$station],
       pch = 16, cex = 2,
       col = ifelse(!is.na(meta_files$with_call), '#17A589', '#EC7063'))
date_axis = seq(xmin, xmax, by = 'month')
axis(1, date_axis, date_axis |> str_sub(1, 7))
axis(2, trans_stations, names(trans_stations), las = 1)
dev.off()












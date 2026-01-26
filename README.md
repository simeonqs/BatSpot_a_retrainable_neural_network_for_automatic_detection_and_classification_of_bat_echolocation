# BatSpot: a retrainable neural network for automatic detection and classification of bat echolocation and detection of buzzes and social calls

The R code and data needed to replicate results from the article:

```
Reference
```

------------------------------------------------

**Abstract**

------------------------------------------------

**Requirements:**

R version 4.2.0 or later. 

Required packages are installed and loaded in each script.

To run BatSpot, see this repository: **link**.

------------------------------------------------

**System information:**



------------------------------------------------

**The folders contain:**

`analysis`:
  - `code`: the scripts to replicate results
  - `data`: the raw data, note this is not shared on GitHub but can be downloaded from **link**
  - `results`: the results, **remember to make a clean upload**

------------------------------------------------

**File information and meta data:**

- `analysis/code/aspot_combine_selection_tables.R`: R script to combine the selection tables from the detection and classification step
- `analysis/code/aspot_create_retraining_data_call_detector.R`: R script to generate the training examples for the retraining of the call detector
- `analysis/code/aspot_create_training_data_buzz_detector.R`: R script to generate the training examples for the buzz detector
- `analysis/code/aspot_create_training_data_call_classifier.R`: R script to generate the training examples for the call classifier
- `analysis/code/aspot_create_training_data_call_detector.R`: R script to generate the training examples for the call detector
- `analysis/code/aspot_create_training_data_social_detector.R`: R script to generate the training examples for the social call detector
- `analysis/code/aspot_get_associated_sound_files.R`: R script to copy wav files associated with selection tables to new location
- `analysis/code/aspot_performance_buzz_detector.R`: R script to make the confusion matrix and calculate the performance stats of the buzz detector
- `analysis/code/aspot_performance_buzz_detector_denmark.R`: R script to make the confusion matrix and calculate the performance stats of the buzz detector for only Denmark
- `analysis/code/aspot_performance_buzz_detector_konstanz.R`: R script to make the confusion matrix and calculate the performance stats of the buzz detector for only Konstanz
- `analysis/code/aspot_performance_buzz_detector_panama.R`: R script to make the confusion matrix and calculate the performance stats of the buzz detector for only Panama
- `analysis/code/aspot_performance_call_classifier.R`: R script to make the confusion matrix and calculate the performance stats of the call detector and classifier combined per call/detection
- `analysis/code/aspot_performance_call_classifier_per_file.R`: R script to make the confusion matrix and calculate the performance stats of detector and classifier combined per file
- `analysis/code/aspot_performance_call_detector.R`: R script to make the confusion matrix and calculate the performance stats of the call detector
- `analysis/code/aspot_performance_call_detector_konstanz.R`: R script to make the confusion matrix and calculate the performance stats of the call detector for only Konstanz
- `analysis/code/aspot_performance_call_detector_panama.R`: R script to make the confusion matrix and calculate the performance stats of the call detector for only Panama
- `analysis/code/aspot_performance_social_detector.R`: R script to make the confusion matrix and calculate the performance stats of social call detector
- `analysis/code/aspot_wavs_detections.R`: R script to create wav files for each detection (for the classification step)
- `analysis/code/bat_performance.R`: R script to make the confusion matrix and calculate the performance stats of BAT
- `analysis/code/batdetect2_performance.R`: R script to make the confusion matrix and calculate the performance stats of BatDetect2 per call/detection
- `analysis/code/batdetect2_performance_per_file.R`: R script to make the confusion matrix and calculate the performance stats of BatDetect2 per file
- `analysis/code/bsgbat_performance.R`: R script to make the confusion matrix and calculate the performance stats of BSGBAT
- `analysis/code/bto_performance.R`: R script to make the confusion matrix and calculate the performance stats of BTO
- `analysis/code/buzzfindr_performance.R`: R script to make the confusion matrix and calculate the performance stats of buzzfindr
- `analysis/code/file_overview_xeno_canto.R`: R script to create an overview of the files used to train the call classifier for Xeno Canto
- `analysis/code/fix_extension.R`: R script to rename files with extension `.WAV` to `.wav`, which is recognised by BatSpot
- `analysis/code/kaleidoscope_performance.R`: R script to make the confusion matrix and calculate the performance stats of Kaleidoscope
- `analysis/code/plot_coverage_validation.R`: R script to plot an overview of the coverage of the validation files
- `analysis/code/sonochiro_performance.R`: R script to make the confusion matrix and calculate the performance stats of Sonochiro
  

- `analysis/data/buzz_detector/training_data/target/denmark/*.txt`: selection tables from Raven Lite with buzzes

- `analysis/data/buzz_detector/training_data/target/panama/*.txt`: selection tables from Raven Lite with buzzes and social calls; there are sometimes multiple annotations, if so only the `.2sdeltatime` ones are kept

------------------------------------------------

**Maintainers and contact:**

Please contact Simeon Q. Smeele, <simeonqs@hotmail.com>, if you have any questions or suggestions. 

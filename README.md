# BatSpot: a retrainable neural network for automatic detection and classification of bat echolocation and detection of buzzes and social calls

The R code and data needed to replicate results from the article:

```
Reference
```

------------------------------------------------

**Abstract**

1. Bats are a diverse taxonomic group that display a wide range of interesting 
behaviours. Many bats are keystone species for their ecosystem, are IUCN 
Red-listed as vulnerable to critically endangered, and subject to 
human-wildlife conflicts arising from anthropogenic expansion. Yet bats 
remain understudied both with respect to behaviour, population ecology and 
conservation status. One of the major challenges when studying bats is 
obtaining data. Their nocturnal lifestyle and use of ultrasonic echolocation 
makes them difficult to track and record using traditional methods. Recent 
advances in passive acoustic monitoring have allowed researchers to record 
large amounts of data, but the detection and classification of vocalisations 
remain a challenge. Most available tools are either for profit or are limited 
to a narrow geographic range, and mostly focus on echolocation search phase 
calls. 

2. Here we present BatSpot, a convolutional neural network trained to detect 
search phase calls, buzzes and social calls. It also offers the option to 
classify the search phase calls to species(-complex) level. We provide a GUI 
that allows researchers to retrain or transfer-train the models for their 
specific needs and validate the performance. 

3. We test the performance of all models and show that they perform better 
than both commercial and open-source solutions (search phase file level F1: 
0.97 vs 0.96, buzz detector F1: 0.95 vs 0.11). We furthermore show that 
retraining the search phase call detector for a new country with examples 
from just 59 recordings massively improves the performance (F1: 0.48 to 0.79).

4. BatSpot will enable bat researchers globally to automate detection and 
classification with minimal effort and includes novel options for social 
call and buzz detection, typically not featured in other automated tools 
for bat monitoring. 

------------------------------------------------

**Usage:**

- To reproduce the results of this article, you can use the R scripts in the
`analysis/code` folder. 

- To use the existing BatSpot models, you can download them from the folder 
`batspot` in the `BatSpot_article.zip` on Zenodo (
<https://zenodo.org/records/18607461?preview=1&token=eyJhbGciOiJIUzUxMiJ9.eyJpZCI6IjhhM2EwYjNmLTQ0YWItNGU1My1iYTE4LTdmMzZjODZkNGM3NSIsImRhdGEiOnt9LCJyYW5kb20iOiI0NzFlYWVjZTVlZDRiOGRhM2ZlMDliNmQ3Mjc5MTY2YiJ9.a8v5Y3t4pgn-f8ViyLUZZNEELiIZ3lc4WpI_MG2blO8w0oqqSwSh3a3gPiSWD1_tAK_BIevNcckGuzpLHguAdA>
) and follow the instructions in this repository: 
<https://github.com/Hauechri/BatSpot>.

- To create new training data, you can follow the instructions in this 
repository: <https://github.com/Hauechri/BatSpot> and use 
`analysis/code/aspot_create_training_data_template.R` to generate examples if 
you have Raven Lite selection tables.

- To retrain or use transfer learning, you can download existing models from 
the folder `batspot` in the `BatSpot_article.zip` on Zenodo (
<https://zenodo.org/records/18607461?preview=1&token=eyJhbGciOiJIUzUxMiJ9.eyJpZCI6IjhhM2EwYjNmLTQ0YWItNGU1My1iYTE4LTdmMzZjODZkNGM3NSIsImRhdGEiOnt9LCJyYW5kb20iOiI0NzFlYWVjZTVlZDRiOGRhM2ZlMDliNmQ3Mjc5MTY2YiJ9.a8v5Y3t4pgn-f8ViyLUZZNEELiIZ3lc4WpI_MG2blO8w0oqqSwSh3a3gPiSWD1_tAK_BIevNcckGuzpLHguAdA>
) and follow the instructions in this 
repository: <https://github.com/Hauechri/BatSpot>. Currently we provide four 
basic models, but we plan to share links to models trained in future projects 
in the list below as they become available. The four models are:

  - Search phase call detection: use 
  `batspot/models_call_detector/m03/train/ANIMAL-SPOT.pk`, use 
  `sampling rate = 192 kHz`.
  - Search phase call classifier: use
  `batspot/models_call_classifier/m09/train/ANIMAL-SPOT.pk`, use 
  `sampling rate = 250 kHz`.
  - Buzz detector: use
  `batspot/models_buzz_detector/m06/train/ANIMAL-SPOT.pk`, use 
  `sampling rate = 192 kHz`.
  - Social call detector: use 
  `batspot/models_social_detector/m05/train/ANIMAL-SPOT.pk`, use 
  `sampling rate = 192 kHz`.
  

- To automate processing of very large datasets, you can use the scripts in 
the folder `analysis/code/pipeline_lumi`. These are examples from 
`Smeele et al. (2026) - Modelling offshore bat activity over danish waters` and
explanation as well as metadata for the scripts are supplied below. 

------------------------------------------------

**Pipeline:**

WARNING: you will need some experience with HPCC's, SQLite, bash and Python
to be able to adapt these scripts. You can always contact 
<simeonqs@hotmail.com> with questions. Also, the pipeline below is not the most
optimal implementation, but for now it works, you are welcome to improve it!

The pipeline to run BatSpot on large quantities of data is set-up for storage
of the data on ERDA (Aarhus University's server), local indexing and 
computation on LUMI (an HPCC). The general idea should work for any server 
with SFTP access and any HPCC that can run CUDA. 

As a first step all wav files are indexed using `index_audio_files_ERDA.py`. 
All results are stored in `audio_database_ERDA.db`. It contains two tables:

- `audio_files` contains the results per audio file with the following columns:
  - `file_path TEXT UNIQUE PRIMARY KEY`: the path on ERDA relative to the directory where indexing started
  - `file_name TEXT`: the original file name of the audio file (these are not unique across deployments!)
  - `new_file_name TEXT UNIQUE`: the new file name to be given after download (contain location_season_deployment_orginal_file_name, where the original file name is made lower case (Animal Spot doesn't take .WAV files)
  - `batch_id TEXT`: batch id, set to NULL before processing
  - `location TEXT`: name of the location_season of data collection
  - `deployment TEXT`: name of the deployment (station_id_recorder_id)
  - `duration REAL`: duration of the file, 0 if broken
  - `is_broken BOOLEAN`: if broken = 1, if not = 0
  - `no_audio BOOLEAN`: if all audio is quiet = 1, else = 0
  - `processing INTEGER`: set to 2 if broken or empty, 2 means process, 1 means processing, 0 means not processed or processing
  - `n_detections INTEGER`: number of detections in files
  - `bats_present INTEGER`: whether or not bats are present in the file
- `detections` contains information for each detection with the following columns:
  - `new_file_sel TEXT UNIQUE PRIMARY KEY`: the new file name _ detection number (selection)
  - `new_file_name TEXT`: the new file name (links it to `audio_files`)
  - `start_s REAL`: the start time in seconds
  - `end_s REAL`: the end time in seconds
  - `annotation TEXT`: empty annotation field (can be filled out later)

This database is then uploaded to the HPCC together with the BatSpot source 
code, the pipeline scripts and the trained model. It's best to store the 
database on a fast write access partition of the HPCC while the prediction 
results and audio data can be stored on a cheaper/slower partition. The 
processing pipeline has the following structure: 

```
── grand_parent_batch_script.sh
   │   └─ download_from_ERDA.sh
   ├── parent_batch_script.sh (loops the below)
   │   │  └─ predict.sh (loops the below)
   │   │       └─ start_prediction.py
   │   └─ child_batch_script.sh   
   │      ├─ translate.sh
   │      │    └─ start_evaluation.py
   │      └─ run_create_clips.sh
   │           └─ create_clips.sh
   ├── parent_batch_script.sh 
   ... n parents total

── zipper_batch_script.sh
```

In short the grand parent script starts the whole process for a specific 
deployment. You can start multiple grand parents for different deployments at 
the same time. It first checks if there are files that are half processed and 
resets the database for these. It then downloads the wav files from the server
to the HPCC. Then it start n number of parent scripts. These parent scripts 
run the actual prediction step in batches. For each bats the parent starts a 
child script that runs the translation step and enters the results in the data
base. It also creates small wav clips for each detection. Finally, the 
zipper script can be started to zip multiple deployments for download to your
local computer. 

------------------------------------------------

**Requirements:**

R version 4.2.0 or later. 

Required packages are installed and loaded in each script.

To run BatSpot, see this repository: <https://github.com/Hauechri/BatSpot>.

------------------------------------------------

**System information:**

- Ubuntu 24.04.3 LTS
- 13th Gen Intel® Core™ i9-13900K × 32
- Memory 64.0 GiB
- NVIDIA RTX A4000
- Python 3.10.20

------------------------------------------------

**The folders contain:**

- `analysis`:
  - `code`: the scripts to replicate results (see "File information and meta data" for more details)
  - `data`: the raw data, note this is not shared on GitHub but can be downloaded from 
  <https://zenodo.org/records/18607461?preview=1&token=eyJhbGciOiJIUzUxMiJ9.eyJpZCI6IjhhM2EwYjNmLTQ0YWItNGU1My1iYTE4LTdmMzZjODZkNGM3NSIsImRhdGEiOnt9LCJyYW5kb20iOiI0NzFlYWVjZTVlZDRiOGRhM2ZlMDliNmQ3Mjc5MTY2YiJ9.a8v5Y3t4pgn-f8ViyLUZZNEELiIZ3lc4WpI_MG2blO8w0oqqSwSh3a3gPiSWD1_tAK_BIevNcckGuzpLHguAdA> 
  (see "File information and meta data" for more details)
  - `results`: the results for this article
- `bat`: the detection/classification results from BAT
- `batdetect2`: the detection/classification results from BatDetect2
- `batspot`: the training and prediction results from BatSpot; datasets used for training (see "File information and meta data" for more details);note this is not shared on GitHub but can be downloaded from **link**
- `bsgbat`: the detection/classification results from BSG-BAT
- `bto`: the detection/classification results from the BTO acoustics pipeline
- `buzzfindr`: the detection results from buzzfindr; script to run buzzfindr
- `kaleidoscope`: the detection/classification results from Kaleidoscope
- `sonochiro`: the detection/classification results from Sonochiro

------------------------------------------------

**File information and meta data:**

- `analysis/code/aspot_combine_selection_tables.R`: R script to combine the selection tables from the detection and classification step
- `analysis/code/aspot_create_retraining_data_call_detector.R`: R script to generate the training examples for the retraining of the call detector
- `analysis/code/aspot_create_training_data_buzz_detector.R`: R script to generate the training examples for the buzz detector
- `analysis/code/aspot_create_training_data_call_classifier.R`: R script to generate the training examples for the call classifier
- `analysis/code/aspot_create_training_data_call_detector.R`: R script to generate the training examples for the call detector
- `analysis/code/aspot_create_training_data_social_detector.R`: R script to generate the training examples for the social call detector
- `analysis/code/aspot_create_training_data_template.R`: template R script to generate the training examples
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

- `analysis/code/pipeline_lumi/child_batch_script.sh`: slurm bash script to start the child process
- `analysis/code/pipeline_lumi/config_predict`: configuration script for the prediction step
- `analysis/code/pipeline_lumi/config_translate`: configuration script for the translation step
- `analysis/code/pipeline_lumi/create_clips.py`: Python script to create wav files per detection
- `analysis/code/pipeline_lumi/download_from_ERDA.sh`: bash script to run the download of wav files from ERDA to LUMI
- `analysis/code/pipeline_lumi/fixer_batch_script.sh`: slurm bash script to fix the database if some files were skipped
- `analysis/code/pipeline_lumi/grand_parent_batch_script.sh`: slurm bash script to start the grand parent process
- `analysis/code/pipeline_lumi/merge_batch_script.sh`: bash script to merge a deployment database back into the main database
- `analysis/code/pipeline_lumi/parent_batch_script.sh`: slurm bash script to start the parent process
- `analysis/code/pipeline_lumi/predict.sh`: bash script to start the prediction step
- `analysis/code/pipeline_lumi/run_create_clips.sh`: bash script to start the Python script to create wav files per detection
- `analysis/code/pipeline_lumi/translate.sh`: bash script to run the translation step
- `analysis/code/pipeline_lumi/zipper_batch_script.sh`: slurm bash script to zip results

- `analysis/data/audio/denmark`: raw audio files for training from Denmark
- `analysis/data/audio/konstanz`: raw audio files for training from Konstanz
- `analysis/data/audio/panama`: raw audio file for training from Panama
- `analysis/data/buzz_detector/training_data/from_runs_konstanz`: target and noise examples from an earlier model, used as training data
- `analysis/data/buzz_detector/training_data/noise/denmark`: selection tables from Raven Lite with noise from Denmark
- `analysis/data/buzz_detector/training_data/noise/konstanz`: selection tables from Raven Lite with noise from Konstanz
- `analysis/data/buzz_detector/training_data/noise/panama`: selection tables from Raven Lite with from noise Panama
- `analysis/data/buzz_detector/training_data/target/denmark`: selection tables from Raven Lite with buzzes from Denmark
- `analysis/data/buzz_detector/training_data/target/konstanz`: selection tables from Raven Lite with buzzes from Konstanz
- `analysis/data/buzz_detector/training_data/target/panama`: selection tables from Raven Lite with buzzes and social calls from Panama; there are sometimes multiple annotations, if so only the `.2sdeltatime` ones are kept
- `analysis/data/buzz_detector/validation_data/audio`: validation recordings from the three locations
- `analysis/data/buzz_detector/validation_data/ground_truth`: selection tables from Raven Lite  with the ground truth for the validation recordings from the three locations 
- `analysis/data/call_classifier/training_data/buzz_and_social`: selection tables from Raven Lite  with annotations of approach calls, buzzes and social calls 
- `analysis/data/call_classifier/training_data/noise`: selection tables from Raven Lite  with annotations of noise
- `analysis/data/call_classifier/training_data/noise_from_call_detector`: selection tables from the call detector that are false positive (noise)
- `analysis/data/call_classifier/training_data/species`: selection tables from Raven Lite with annotations of species
- `analysis/data/call_detector/retraining_data/noise/konstanz`: selection tables from Raven Lite with annotations of noise for retraining of the call detector for Konstanz
- `analysis/data/call_detector/retraining_data/target/konstanz`: selection tables from Raven Lite with annotations of bat calls for retraining of the call detector for Konstanz
- `analysis/data/call_detector/training_data/noise/Denmark`: selection tables from Raven Lite with annotations of noise from Denmark to train the call detector
- `analysis/data/call_detector/training_data/target/Denmark`: selection tables from Raven Lite with annotations of bat calls from Denmark to train the call detector
- `analysis/data/call_detector/validation_data/audio`: validation recordings from Denmark and Konstanz
- `analysis/data/call_detector/validation_data/ground_truth`: selection tables from Raven Lite  with the ground truth for the validation recordings from Denmark and Konstanz 
- `analysis/data/social_detector/training_data/noise`: selection tables from Raven Lite with noise
- `analysis/data/social_detector/training_data/target`: selection tables from Raven Lite with social calls
- `analysis/data/social_detector/validation_data/audio`: validation recordings
- `analysis/data/social_detector/validation_data/ground_truth`: selection tables from Raven Lite  with the ground truth for the validation recordings

- `batspot/data_sets_buzz_detector/data_6`: dataset used to train the buzz detector
- `batspot/data_sets_call_classifier/aug_data`: augmentation data used to train the call classifier
- `batspot/data_sets_call_classifier/data_9`: dataset used to train the call classifier 
- `batspot/data_sets_call_detector/data_3`: dataset used to train the call detector for Denmark
- `batspot/data_sets_call_detector/data_5`: dataset used for training from scratch and retraining of the call detector for Konstanz 
- `batspot/data_sets_social_detector/data_4`: dataset used to train the social call detector
- `batspot/models_buzz_detector/m06`: files from training, prediction and translation of the buzz detector, note that the config files are formatted for running BatSpot from the terminal
- `batspot/models_call_classifier/m09`: files from training, prediction and translation of the call classifier, note that the config files are formatted for running BatSpot from the terminal
- `batspot/models_call_detector/m03`: files from training, prediction and translation of the call detector for Denmark, note that the config files are formatted for running BatSpot from the terminal
- `batspot/models_call_detector/m09`: files from retraining, prediction and translation of the call detector for Konstanz
- `batspot/models_call_detector/m11`: files from training from scratch, prediction and translation of the call detector for Konstanz
- `batspot/models_social_detector/m05`: files from training, prediction and translation of the social call detector, note that the config files are formatted for running BatSpot from the terminal

------------------------------------------------

**Maintainers and contact:**

Please contact Simeon Q. Smeele, <simeonqs@hotmail.com>, if you have any questions or suggestions. 

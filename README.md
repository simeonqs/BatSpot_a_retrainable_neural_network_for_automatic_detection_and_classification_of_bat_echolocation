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

ANALYSIS:
  - CODE: the code to replicate results
  - DATA: raw data
  - RESULTS: results that cannot be reproduced or take very long to reproduce, all other results are not included, but can be reproduced by the scripts in the CODE folder

------------------------------------------------

**File information and meta data:**

- `analysis/code/aspot_combine_selection_tables.R`: R script to combine the selection tables from the detection and classification step
- `analysis/code/aspot_create_retraining_data_call_detector.R`: R script to generate the training examples for the call detector
- `analysis/code/`: R script to
- `analysis/code/`: R script to
- `analysis/code/`: R script to
- `analysis/code/`: R script to
- `analysis/code/`: R script to
- `analysis/code/`: R script to
- `analysis/code/`: R script to
- `analysis/code/`: R script to
- `analysis/code/`: R script to
- `analysis/code/`: R script to
- `analysis/code/`: R script to
- `analysis/code/`: R script to
- `analysis/code/`: R script to
- `analysis/code/`: R script to
  

- `analysis/data/buzz_detector/training_data/target/denmark/*.txt`: selection tables from Raven Lite with buzzes

- `analysis/data/buzz_detector/training_data/target/panama/*.txt`: selection tables from Raven Lite with buzzes and social calls; there are sometimes multiple annotations, if so only the `.2sdeltatime` ones are kept

------------------------------------------------

**Maintainers and contact:**

Please contact Simeon Q. Smeele, <simeonqs@hotmail.com>, if you have any questions or suggestions. 

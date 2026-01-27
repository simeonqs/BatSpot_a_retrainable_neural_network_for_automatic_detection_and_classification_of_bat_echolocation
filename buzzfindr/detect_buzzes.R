# devtools::install_github("joelwjameson/buzzfindr")
library(buzzfindr)

path_wavs_dk = 'analysis/data/buzz_detector/validation_data/audio/denmark'
path_wavs_kn = 'analysis/data/buzz_detector/validation_data/audio/konstanz'
path_wavs_pan = 'analysis/data/buzz_detector/validation_data/audio/panama'
path_out = 'buzzfindr/detected_buzzes.csv'

detected_buzzes_dk = buzzfindr(path_wavs_dk)
detected_buzzes_kn = buzzfindr(path_wavs_kn)
detected_buzzes_pan = buzzfindr(path_wavs_pan)

detected_buzzes = rbind(detected_buzzes_dk, 
                        detected_buzzes_kn,
                        detected_buzzes_pan)

write.csv(detected_buzzes, path_out, row.names = FALSE)
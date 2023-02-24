### p04_correlate_outcomes ###
# These scripts correlate the low-ADC region volume change with TTP/TTD

### 00_init
# This script loads packages and declares script options

# import libraries
library(mysurv)
library(dplyr)
library(tidyverse)
library(readxl)
library(lubridate)
library(survival)
library(ranger)
library(ggfortify)
library(pROC)
library(rjson)
library(assert)

# declare script options
theme_set(theme_bw())
enclosing.roi.use <- 'GTVDaily' # enclosing ROI for low-ADC region
filter.by.dice <- FALSE # if using AIAA contour, filter subjects by Dice score with planning GTV?
dice.threshold <- 0.6 # Dice threshold to use for filtering

if (filter.by.dice){
  assert(enclosing.roi.use=='AIAAtumourcore',msg='if filtering by Dice, enclosing ROI must be AIAA tumour core')
}

# declare working directory
dir.work <- file.path('results','20220722_correlate_outcomes')
dir.create(dir.work,showWarnings=FALSE)

# write script options
opts <- vector(mode='list',length=3)
opts[[1]] <- enclosing.roi.use
opts[[2]] <- filter.by.dice
opts[[3]] <- dice.threshold
names(opts) <- c('EnclosingROIUsed','FilterByDiceAIAA','DiceThreshold')
json.opts <- toJSON(opts)
write(json.opts,file.path(dir.work,'R_script_options.json'))

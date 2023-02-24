# main
# main script to call all other scripts

# clear variables
rm(list=ls())

# set options -------------------------------------------------------------

verbose <- FALSE # if true, scripts will produce many additional files for verification/debugging
create.fancy.km <- FALSE # if true, scripts create fancy KM plots

# Load libraries ----------------------------------------------------------

library(MASS)
if (create.fancy.km){
  library(mysurv)
}
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
library(RColorBrewer)
library(viridis)
library(pracma)
library(openxlsx)
library(naniar)
library(ggsignif)
library(survcomp)
library(nlme)

# run scripts ------------------------------

# declare results directory
dir.results <- 'results'
dir.create(dir.results, showWarnings=FALSE)

# source scripts
source('01_preproc_MRL.R')
source('02_preproc_GLIO.R')
source('03_init_correlation.R')
source('04_read_dataframes.R')
source('05_stratify.R')
source('06_survival_correlation.R')
source('07_plot_timeseries.R')
source('08_mrl_survival.R')
source('09_evaluate_bias.R')


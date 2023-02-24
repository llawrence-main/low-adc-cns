#### response_correlation
# The purpose of these scripts is to correlate changes in ADC with clinical response (progression-free survival, overall survival)
#### 

### 00_init
# loads libraries and declares script options

# Import libraries
library(mysurv)
library(tidyverse)
library(readxl)
library(assert)
library(lubridate)
library(RColorBrewer)
library(viridis)
library(survival)
library(ranger)
library(ggfortify)
library(pracma)
library(openxlsx)
library(pROC)
library(naniar)


# Script options ----------------------------------------------------------

# plotting
theme_set(theme_bw())

# working directory
dir.work <- file.path('results','dwi_response_results','20220722_responseCorrelation')
dir.create(dir.work,showWarnings=FALSE)

# declare timepoint-session correspondence for each patient
df.subref <- read_csv(file.path('results','subject_reference_list.csv'))
subjects <- unique(df.subref$Subject)
timepoints.list <- c('Fx0','Fx10','Fx20','P1M')
session.list <- c('sim001','sim002','sim003','sim004')
n.subjects <- length(subjects)
n.timepoints <- length(timepoints.list)
timepoint.dict <- data.frame(Subject=rep(subjects,each=n.timepoints),
                             Timepoint=rep(timepoints.list,n.subjects),
                             Session=rep(session.list,n.subjects)) %>%
  tibble() %>%
  mutate(Subject=as.character(Subject),
         Timepoint=as.character(Timepoint),
         Session=as.character(Session))
timepoint.fix <- tribble(
  ~Subject,~Session,~Timepoint,
  'M020','sim002','Fx0',
  'M020','sim003','Fx10',
  'M020','sim004','Fx20',
  'M020','sim005','P1M',
  'M115','sim001','Fx0',
  'M115','sim002','Fx10',
  'M115','sim004','Fx20',
  'M115','sim005','P1M',
  'M129','sim001','Fx0',
  'M129','sim003','Fx10',
  'M129','sim004','Fx20',
  'M129','sim005','P1M',
  'M187','sim001','Fx0',
  'M187','sim002','Fx10',
  'M187','NoSession','Fx20',
  'M187','sim003','P1M',
  'M199','sim001','Fx0',
  'M199','sim003','Fx10',
  'M199','sim004','Fx20',
  'M199','sim005','P1M'
)
timepoint.dict <- left_join(timepoint.dict,timepoint.fix,by=c('Subject','Timepoint'),suffix=c('','.fix'))
loc.rep <- !is.na(timepoint.dict$Session.fix)
timepoint.dict$Session[loc.rep] <- timepoint.dict$Session.fix[loc.rep]
timepoint.dict <- timepoint.dict %>% select(-Session.fix)

# write timepoint dictionary to file
timepoint.dict %>%
  write_csv(file.path('results','metadata','fraction_session.csv'))

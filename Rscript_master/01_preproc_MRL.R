### 01_preproc_MRL
# combines info on low-ADC volume measurements on MR-Linac with response data

# Script options ----------------------------------------------------------

# plotting
theme_set(theme_bw())

# working directory
dir.work <- file.path(dir.results,'preproc_mrl')
dir.create(dir.work,showWarnings=FALSE)

# declare timepoint-session correspondence for each patient
df.subref <- read_csv(file.path('data','MRL_subject_reference_list.csv'))
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
  write_csv(file.path(dir.work,'MRL_fraction_session.csv'))

# create the time-to-progression and death tables -------------------------

# Read MOMENTUM tracker for MOMENTUM ID - OC Study ID correspondence dictionary
filename.tracker <- file.path('data','MOMENTUM_study_tracker_20220714.xlsx')
df.dict <- cbind(read_excel(filename.tracker,range='Tracker!B4:B232'),
                 read_excel(filename.tracker,range='Tracker!A4:A232')) %>%
  tibble() %>%
  rename(Subject=`Study ID`,OC.ID=`OC Study ID`)

## Read spreadsheet of outcomes
fn.meta <- file.path('data','MRL_outcomes_June2022.xlsx')

read.outcomes.spreadsheet <- function(fn.meta){
  res <- cbind(read_excel(fn.meta,range='A4:A44',col_names='OC.ID'),
               read_excel(fn.meta,range='M4:M44',col_names='ORDate',col_types='date',na=c('999','888')),
               read_excel(fn.meta,range='AU4:AU44',col_names='FU1Date',col_types='date',na=c('PEND','999','888')),
               read_excel(fn.meta,range='AW4:AW44',col_names='FU1RANO',na=c('888','999')),
               read_excel(fn.meta,range='BF4:BF44',col_names='FU2Date',col_types='date',na=c('PEND','999','ND','888')),
               read_excel(fn.meta,range='BH4:BH44',col_names='FU2RANO',na=c('888','999')),
               read_excel(fn.meta,range='BQ4:BQ44',col_names='FU3Date',col_types='date',na=c('PEND','999','888')),
               read_excel(fn.meta,range='BS4:BS44',col_names='FU3RANO',na=c('999','888')),
               read_excel(fn.meta,range='CB4:CB44',col_names='EOS'),
               read_excel(fn.meta,range='B4:B44',col_names='StudyStatus'),
               read_excel(fn.meta,range='O4:O44',col_names='Grade'),
               read_excel(fn.meta,range='D4:G44',col_names=c('Sex','Age','ECOG','KPS'),na=c('999')),
               read_excel(fn.meta,range='P4:P44',col_names='Location'),
               read_excel(fn.meta,range='AA4:AA44',col_names='Dose'),
               read_excel(fn.meta,range='S4:S44',col_names='CodeResection',col_types='numeric',na=c('888','999','SD')),
               read_excel(fn.meta,range='X4:Z44',col_names=c('Code1p19q','CodeIDH1','CodeMGMT'),col_types=c('numeric','numeric','numeric'),na=c('888','999')))
  return(res)
}
df.response.spreadsheet <- read.outcomes.spreadsheet(fn.meta)

# Read additional outcomes and replace associated rows in spreadsheet
fn.meta.3patients <- file.path('data', 'MRL_outcomes_Dec2022_3patients.xlsx')
meta.extra <- read.outcomes.spreadsheet(fn.meta.3patients) %>% filter(!is.na(OC.ID))
loc.3patients <- df.response.spreadsheet$OC.ID %in% meta.extra$OC.ID
df.response.spreadsheet[loc.3patients,] <- meta.extra

# convert RANO columns to numeric
df.response.spreadsheet <- df.response.spreadsheet %>% mutate(FU1RANO=as.numeric(FU1RANO),
                                                              FU2RANO=as.numeric(FU2RANO),
                                                              FU3RANO=as.numeric(FU3RANO))

# Parse clinical characteristic codes
codes.resection <- tribble(
  ~CodeResection,~StatusResection,
  1,'GTR',
  2,'STR',
  3,'Biopsy',
  4,'NoResection'
)
codes.1p19q <- tribble(
  ~Code1p19q,~Status1p19q,
  1,'Codeleted',
  2,'NotCodeleted',
  3,'NotAssessed'
)
codes.idh1 <- tribble(
  ~CodeIDH1,~StatusIDH1,
  1,'Mutated',
  2,'Wildtype',
  3,'NotAssessed'
)
codes.mgmt <- tribble(
  ~CodeMGMT,~StatusMGMT,
  1,'Methylated',
  2,'Unmethylated',
  3,'NotAssessed'
)
convert.rano <- function(rano.code){
  ranos <- c('CR','PR','SD','PD','UNK')
  if (is.na(rano.code)){
    res <- NA
  } else {
    res <- ranos[rano.code]
  }
  return(res)
}
df.response.spreadsheet <- df.response.spreadsheet %>% 
  left_join(codes.resection,by='CodeResection') %>%
  left_join(codes.1p19q,by='Code1p19q') %>%
  left_join(codes.idh1,by='CodeIDH1') %>%
  left_join(codes.mgmt,by='CodeMGMT') %>%
  select(-CodeResection,-Code1p19q,-CodeIDH1,-CodeMGMT) %>%
  tibble() %>%
  mutate(FU1RANO=sapply(FU1RANO,convert.rano),
         FU2RANO=sapply(FU2RANO,convert.rano),
         FU3RANO=sapply(FU3RANO,convert.rano))

# compute date of death
df.response.spreadsheet <- df.response.spreadsheet %>% mutate(DateOfDeath=EOS) %>% relocate(DateOfDeath,.after='FU3RANO')
df.response.spreadsheet$DateOfDeath[df.response.spreadsheet$StudyStatus != 'EX'] <- NA
df.response.spreadsheet <- df.response.spreadsheet %>% mutate(Died=!is.na(DateOfDeath)) %>% relocate(Died,.after='DateOfDeath')

# clean up outcomes dataframe
subs.exclude <- c('M201') # M201 is M001 (same patient, later treatment)
df.outcome <- df.response.spreadsheet %>%
  left_join(df.dict,by='OC.ID') %>%
  select(-OC.ID) %>%
  relocate(Subject) %>%
  filter(!(Subject %in% subs.exclude))
df.outcome$ORDate[df.outcome$Subject=='M009'] <- make_date(year=2019,month=9,day=17) # fix typo in spreadsheet

get.prog.date <- function(dates,evals){
  # returns the date of progression or last follow-up given a set of evaluation dates and RANO evaluations
  # dates: list of dates
  # evals: list of RANO evaluations (SD, PD, PR, CR)
  N <- length(dates)
  status <- NA
  event.date <- NA
  for (ix in 1:N){
    if ((!is.na(evals[ix])) & (evals[ix]=='PD')){
      status <- 1
      event.date <- dates[ix]
      break
    } else if (!is.na(evals[ix])) {
      status <- 0
      event.date <- dates[ix]
    }
  }
  return(data.frame(EventDate=event.date,Status=status))
}

# add dates of progression
df.event <- data.frame()
for (ix in seq(1,nrow(df.outcome))){
  dates <- c(df.outcome$FU1Date[ix],df.outcome$FU2Date[ix],df.outcome$FU3Date[ix])
  ranos <- c(df.outcome$FU1RANO[ix],df.outcome$FU2RANO[ix],df.outcome$FU3RANO[ix])
  df.event <- rbind(df.event,get.prog.date(dates,ranos))
}

# if patient did not progress but died, put date of death as date of progression
df.outcome <- cbind(df.outcome,df.event) %>% tibble()
df.outcome <- df.outcome %>% 
  mutate(EventDateWithDeath=if_else((Status%in%c(NA,0))&(Died),DateOfDeath,EventDate),
         StatusWithDeath=if_else((Status%in%c(NA,0))&(Died),1,Status))

# overwrite outcome for M125 (lost to follow-up)
loc.M125 <- df.outcome$Subject=='M125' # no follow-ups
df.outcome$Died[loc.M125] <- NA

# declare time to progression
df.ttp <- df.outcome %>% 
  mutate(TimeToEvent=EventDateWithDeath-ORDate) %>%
  mutate(TimeToEventMonths=as.numeric(TimeToEvent)/30) %>%
  mutate(Progressed=as.logical(StatusWithDeath)) %>%
  select(Subject,TimeToEventMonths,Progressed)

# declare time to death
followup.dates <- df.outcome %>% select(Subject,FU1Date,FU2Date,FU3Date) %>%
  pivot_longer(cols=c('FU1Date','FU2Date','FU3Date')) %>%
  mutate(value=as_date(value)) %>%
  group_by(Subject) %>%
  summarise(FollowupDate=max(value,na.rm=TRUE))
df.outcome <- df.outcome %>% left_join(followup.dates,by='Subject') %>%
  relocate(FollowupDate,.after='Died')
df.ttd <- df.outcome %>%
  select(Subject,ORDate,DateOfDeath,Died) %>%
  left_join(followup.dates,by='Subject') %>%
  mutate(DateOfDeath=as_date(DateOfDeath),
         ORDate=as_date(ORDate))
df.ttd <- df.ttd %>% mutate(EventDate=if_else(Died,DateOfDeath,FollowupDate))
df.ttd <- df.ttd %>% mutate(TimeToEventMonths=as.numeric(EventDate-ORDate)/30) %>%
  mutate(TimeToEventMonths=if_else(TimeToEventMonths==-Inf,as.numeric(NA),TimeToEventMonths))
df.ttd <- df.ttd %>% select(Subject,TimeToEventMonths,Died)

if (verbose){
  # write time to progression table
  write_csv(df.ttp,file.path(dir.work,'time_to_progression.csv'))
  
  # write time to death table
  write_csv(df.ttd,file.path(dir.work,'time_to_death.csv'))
  
  # write full spreadsheet of outcomes for verification
  write_csv(df.outcome,file.path(dir.work,'outcomes_table.csv'))

  # write spreadsheet of patients where date of death was set as date of progression
  df.outcome.overwritten <- df.outcome %>% filter((EventDate != EventDateWithDeath)|(is.na(EventDate)))
  write_csv(df.outcome.overwritten,file.path(dir.work,'outcomes_table_death_as_progression.csv'))
}

# save dataframe of patient characteristics for later
pt.chars <- list()
pt.chars$mrl <- df.outcome

# create response correlation dataframe -----------------------------------

# read table of volume dynamic metrics
fn.dyn <- file.path('data','MRL_dyn_table.csv')
df.dyn.all <- read_csv(fn.dyn,col_types=list(
  col_factor(),
  col_factor(),
  col_integer(),
  col_factor(),
  col_factor(),
  col_double())
)

# subset to MR-sim scans
df.dyn.sim <- df.dyn.all %>% filter(grepl('sim',Session,fixed=TRUE))

# subset to MR-sim tumourcore ROI on same day
df.dyn.sim <- df.dyn.sim %>%
  mutate(Session=as.character(Session),
         TumourcoreSession=as.character(TumourcoreSession)) %>% 
  filter(Session==TumourcoreSession) %>%
  mutate(Session=factor(Session))

# join to dataframe of timepoints
df.dyn.sim <- df.dyn.sim %>% left_join(timepoint.dict,by=c('Subject','Session'))

# declare baseline scans on MR-sim
df.baseline <- df.dyn.sim %>% filter(Timepoint=='Fx0') %>% select(Subject,Metric,Value)

# compute change relative to baseline
df.dyn <- df.dyn.sim %>% left_join(df.baseline,by=c('Subject','Metric'),suffix=c('','.baseline')) %>%
  mutate(Delta=Value-Value.baseline,DeltaPc=100*(Value-Value.baseline)/Value.baseline)

# exclude certain subjects and subject-timepoints
sub.fail <- c('M201', # M201 is M001
              'M038', # M038 TX START DATE follows dates of MR-Linac scans, and only 2 MR-Linac scans
              'M006', # ses-sim001 has only DTI, not DWI
              'M007', # imaging only patient
              'M052', # only one sim scan
              'M065') # only one sim scan
df.dyn <- df.dyn %>% filter(!(Subject=='M125'&Session=='MRL017'))
df.dyn <- df.dyn %>% filter(!(Subject %in% sub.fail))
df.dyn <- df.dyn %>% filter(!(Subject=='M001'&Session %in% c('sim005','sim006'))) %>% # M001 ses-sim005 and sim-006 are second-round therapy scans
  filter(!(Subject=='M014'&Session=='sim005')) %>% # M014 ses-sim005 is a 1-year follow-up
  filter(!(Subject=='M115'&Session=='sim003')) %>% # M115 ses-sim003 is a fraction 15 (?) scan
  filter(!(Subject=='M199'&Session=='sim002')) # M199 ses-sim002 is a scan at 3 days after treatment start (??)

# rename metrics
df.dyn <- df.dyn %>% left_join(tribble(
  ~Metric,~MetricName,
  'VolumeLowADC','dLowADC',
  'VolumeTumourcore','dGTV'
),
by='Metric') %>%
  select(-Metric)

# join to table of outcomes
df.ttp.renamed <- df.ttp %>% rename(Status=Progressed) %>% mutate(Event='Progression')
df.ttd.renamed <- df.ttd %>% rename(Status=Died) %>% mutate(Event='Death')
df.outcomes <- rbind(df.ttp.renamed,df.ttd.renamed) %>%
  select(Subject,Event,TimeToEventMonths,Status)

if (verbose){
  # make plot of day for each timepoint to verify
  p.timepoints <- df.dyn %>% ggplot(aes(x=Timepoint,y=Day)) +
    geom_point() +
    theme(text=element_text(size=20))
  ggsave(file.path(dir.work,'day_versus_timepoints.jpg'),
         plot=p.timepoints,
         width=8,
         height=6)
}

# join ADC data to progression data and pivot table for prediction
df.cor.all <- df.dyn %>% filter(!(Timepoint=='Fx0')) %>%
  inner_join(df.outcomes,by='Subject') %>%
  pivot_wider(id_cols=c('Subject','TimeToEventMonths','Event','Status'),
              names_from=c('MetricName','Timepoint'),
              values_from=DeltaPc,
              names_sep='.')

# add early/late progression and death columns
df.event.times <- tribble(
  ~Event,~MedianEventTime,
  'Death',14.6,
  'Progression',6.9 
) # median survival and progression-free survival for RT + TMZ from Stupp et al., New Engl J Med, 2005
df.cor.all <- df.cor.all %>% left_join(df.event.times,by='Event') %>% mutate(IsEarly=as.numeric(TimeToEventMonths<MedianEventTime))

# declare predictors associated with volume changes
timepoints <- c('Fx10','Fx20','P1M')
preds.volume <- expand.grid(c("dLowADC"),timepoints) %>%
  mutate(Combo=mapply(function(x,y)paste(x,y,sep='.'),Var1,Var2)) %>% 
  pull(Combo)

# add clinical info
df.cor.all <- df.outcome %>% select(Subject,Age,Sex,Grade,StatusResection,StatusMGMT,StatusIDH1,Status1p19q,ECOG,Location,Dose) %>% right_join(df.cor.all,by='Subject')

# declare events
events <- unique(df.cor.all$Event)

# write dataframes
write_csv(df.cor.all,file.path(dir.work,'response_correlation_dataframe.csv'))
write_csv(df.baseline,file.path(dir.work,'dyn_table_baseline.csv'))

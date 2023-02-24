### 01_createTTP
# creates the time-to-progression (and death) table(s)

# Read MOMENTUM tracker for MOMENTUM ID - OC Study ID correspondence dictionary
filename.tracker <- file.path('data','MOMENTUM_study_tracker_20220714.xlsx')
df.dict <- cbind(read_excel(filename.tracker,range='Tracker!B4:B232'),
                 read_excel(filename.tracker,range='Tracker!A4:A232')) %>%
  tibble() %>%
  rename(Subject=`Study ID`,OC.ID=`OC Study ID`)

## Read spreadsheet of outcomes from Aimee Theriault
fn.meta <- file.path('data','low_adc_cns_cohort_jun2022.xlsx')
df.response.spreadsheet <- cbind(read_excel(fn.meta,range='A4:A44',col_names='OC.ID'),
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
df.outcome$ORDate[df.outcome$Subject=='M009'] <- make_date(year=2019,month=9,day=17)

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

df.event <- data.frame()
for (ix in seq(1,nrow(df.outcome))){
  dates <- c(df.outcome$FU1Date[ix],df.outcome$FU2Date[ix],df.outcome$FU3Date[ix])
  ranos <- c(df.outcome$FU1RANO[ix],df.outcome$FU2RANO[ix],df.outcome$FU3RANO[ix])
  df.event <- rbind(df.event,get.prog.date(dates,ranos))
}
df.outcome <- cbind(df.outcome,df.event) %>% tibble()
df.outcome <- df.outcome %>% 
  mutate(EventDateWithDeath=if_else((Status%in%c(NA,0))&(Died),DateOfDeath,EventDate),
         StatusWithDeath=if_else((Status%in%c(NA,0))&(Died),1,Status))

# handle special cases
loc.M107 <- df.outcome$Subject=='M107' # FU1 evaluated but not FU2 or FU3
df.outcome$EventDateWithDeath[loc.M107] <- df.outcome$FU1Date[loc.M107]
df.outcome$StatusWithDeath[loc.M107] <- 0

loc.M110 <- df.outcome$Subject=='M110' # FU1 evaluated but not FU2 or FU3
df.outcome$EventDateWithDeath[loc.M110] <- df.outcome$FU1Date[loc.M110]
df.outcome$StatusWithDeath[loc.M110] <- 0

loc.M125 <- df.outcome$Subject=='M125' # no follow-ups
df.outcome$Died[loc.M125] <- NA

loc.M177 <- df.outcome$Subject=='M177' # RANO pending for all follow-ups
df.outcome$EventDateWithDeath[loc.M177] <- NA
df.outcome$StatusWithDeath[loc.M177] <- NA

# declare time to progression
df.ttp <- df.outcome %>% 
  mutate(TimeToEvent=EventDateWithDeath-ORDate) %>%
  mutate(TimeToEventMonths=as.numeric(TimeToEvent)/30) %>%
  mutate(Progressed=as.logical(StatusWithDeath)) %>%
  select(Subject,TimeToEventMonths,Progressed)

# Save list of patients with outcomes
out.filename <- file.path(dir.work,'time_to_progression.csv')
write_csv(df.ttp,out.filename)

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

# write time to death table
write_csv(df.ttd,file.path(dir.work,'time_to_death.csv'))

# write full spreadsheet for verification
write_csv(df.outcome,file.path(dir.work,'outcomes_table.csv'))

# write spreadsheet of patients where date of death was set as date of progression
df.outcome.overwritten <- df.outcome %>% filter((EventDate != EventDateWithDeath)|(is.na(EventDate)))
write_csv(df.outcome.overwritten,file.path(dir.work,'outcomes_table_death_as_progression.csv'))


# Create table of clinical data for patients with BOLD fMRI scans for Angus  --------

# # read in list of BOLD subjects
# bold.subjects <- read_csv(file.path('data','subjects_with_bold_fmri.txt'),
#                           col_names='Subject')
# 
# # left join to outcomes dataframe
# bold.outcomes <- bold.subjects %>% left_join(df.outcome,by='Subject') %>%
#   rename(Progressed=Status)
# 
# # write outcomes dataframe
# write_csv(bold.outcomes,file.path('results','metadata','outcomes_BOLD_fMRI_subjects_for_Angus.csv'))

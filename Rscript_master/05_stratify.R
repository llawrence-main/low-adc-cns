### 05_stratify
# Stratifies patients by clinical and volumetric predictors

phase <- 'stratify'
dir.create(file.path(dir.work,phase),showWarnings=FALSE)


# Do stratification -----------------------------------------

# create rank columns in correlation table for volumetric predictors
preds.roc <- preds.volume
thresholds <- df.cor.all %>% filter(Event=='Death') %>% select(Subject,all_of(preds.roc)) %>% pivot_longer(cols=preds.roc,names_to='Predictor',values_to='Value') %>%
  group_by(Predictor) %>%
  summarise(Threshold=median(Value,na.rm=TRUE)) %>%
  column_to_rownames(var="Predictor") %>% t()
for (pred in preds.volume){
  rank.name <- str_replace(pred,'\\.','Rank\\.')
  loc.greater <- df.cor.all[[pred]] >= thresholds['Threshold',pred]
  loc.lesser <- df.cor.all[[pred]] < thresholds['Threshold',pred]
  df.cor.all[[rank.name]] <- NA
  df.cor.all[[rank.name]][loc.greater] <- 'Above'
  df.cor.all[[rank.name]][loc.lesser] <- 'Below'
  df.cor.all[[rank.name]] <- factor(df.cor.all[[rank.name]],levels=c('Below','Above'))
}

# write out thresholds used
write_csv(as.data.frame(thresholds),file.path(dir.work,phase,'stratification_thresholds.csv'))

# create rank columns in correlation table for clinical factor predictors
# References:
# [Curran et al., J Natl Canc Inst, 1993]: Age (>=50 vs. <50), Pathologic grade (AA vs GBM), Surgery (partial/total vs. biopsy)
# [Helseth et al., Acta Neurol Scand, 2010]: Age (continuous), Surgery (resection vs. biopsy)
df.cor.all <- df.cor.all %>% 
  mutate(ResectionRank=sapply(Resection,function(x) 
  if(x %in% c('GTR','STR')){return('Resected')}
  else{return('NotResected')}))
df.cor.all <- df.cor.all %>%
  mutate(AgeRank=sapply(Age,function(x)
    if(x>=50){return('Over50')}
    else{return('Under50')}))
df.cor.all <- df.cor.all %>%
  mutate(ECOGRank=if_else(ECOG<=1,'0-1','2-4'))

# convert clinical predictor columns to factors
df.cor.all <- df.cor.all %>% mutate(Grade=factor(Grade,levels=c('III','IV')),
                      AgeRank=factor(AgeRank,levels=c('Under50','Over50')),
                      ResectionRank=factor(Resection,levels=c('GTR','STR','Biopsy')),
                      MGMTRank=factor(MGMT,levels=c('Methylated','Unmethylated')),
                      IDH1Rank=factor(IDH1,levels=c('Mutated','Wildtype')),
                      ECOGRank=factor(ECOGRank,levels=c('0-1','2-4')))

# declare volumetric predictors 
preds.rank.volume <- sapply(preds.volume,function(x) str_replace(x,'\\.','Rank\\.'))
names(preds.rank.volume) <- c()

# add clinical predictors
preds.clin <- c('AgeRank','ResectionRank','MGMTRank','ECOGRank')
preds.rank <- c(preds.rank.volume,preds.clin)


# Declare dynamics dataframe for MR-sim scans -----------------------------


# for MOMENTUM and GLIO patients on MR-sim, plot change in low-ADC volume over time grouped by early/late
df.dyn.cor <- df.cor.all %>% pivot_longer(cols=preds.volume,names_to='Predictor',values_to='Value') %>% 
  mutate(Region=str_replace(Predictor,'\\..*',''),Timepoint=str_replace(Predictor,'d.*\\.','')) %>% 
  select(-Predictor) %>%
  mutate(Timepoint=factor(Timepoint),IsEarly=as.logical(IsEarly)) %>%
  left_join(fx.day,by='Timepoint') %>% 
  mutate(Day=as.integer(Day))


# Create table of patient characteristics ---------------------------------

# create table of imaging timepoints for MR-sim
mrsim.n.img <- df.dyn.cor %>% filter(Event=='Death',Region=='dLowADC',!is.na(Value)) %>% group_by(Subject) %>% summarise(NumDWI=n()+1) %>% # add 1 to account for dropped Fx0 scan
  mutate(Scanner='Sim')

# create table of imaging timepoints for MR-Linac
mrl.n.img <- df.dyn.interp %>% filter(Event=='Death',Metric=='VolumeLowADC',Scanner=='MRL') %>% group_by(Subject) %>% summarise(NumDWI=n()) %>% mutate(Scanner='MRL')

# combine summary imaging timepoint dataframes
n.img <- rbind(mrsim.n.img,mrl.n.img) %>% relocate(Scanner,.before=Subject)
n.img.total <- n.img %>% group_by(Scanner) %>% summarise(TotalDWI=sum(NumDWI))

# bin number of scans
bin.scan.number <- function(n){
  if (!is.na(n)){
    if (n<10) {
      res <- 'n<10'
    } else if (n>=10 & n<=20) {
      res <- '10<=n<=20'
    } else {
      res <- '20<n'
    }
  } else {
    res <- NA
  }
  return(res)
}
n.img <- n.img %>%
  pivot_wider(names_from=Scanner, values_from=NumDWI) %>%
  mutate(SimBinned = as.character(Sim),
         MRLBinned = mapply(bin.scan.number, MRL))

# create dataframe for patient characteristics
df.char <- df.cor.all %>% 
  filter(Event=='Death') %>%
  select(Subject,Age,Sex,AgeRank,ECOG,Grade,Location,MGMT,IDH1,Resection,Dose) %>%
  mutate(Dose=factor(Dose),
         Resection=factor(Resection,levels=c('GTR','STR','Biopsy')),
         IDH1=factor(IDH1,levels=c('Wildtype','Mutated')),
         MGMT=if_else(MGMT %in% c('NotAssessed','Unknown'),'NotAssessed/Unknown',MGMT)) %>%
  left_join(n.img, by='Subject')

# create full dataframe of patient characteristics
df.char.write <- df.char %>% select(Subject,Sim,MRL,Age,Sex,Grade,Location,ECOG,MGMT,IDH1,Resection,Dose) %>%
  rename(ID=Subject) %>%
  mutate(Location=str_to_title(Location)) %>%
  mutate(Location=str_replace(Location,' Lobe',''))

# put new IDs
ids.summary <- df.char.write %>% 
  mutate(IsMRL=!grepl('GBM',ID)) %>% 
  mutate(IsMRL=factor(IsMRL,levels=c('TRUE','FALSE'))) %>%
  group_by(IsMRL) %>% 
  summarise(n=n()) %>% 
  mutate(Prefix=if_else(IsMRL=='TRUE','MRL','LIN'))
ids.list <- c()
for (ix in 1:nrow(ids.summary)){
  ids.list <- c(ids.list, paste0(ids.summary[[ix,'Prefix']],sprintf('%02d',1:ids.summary[[ix,'n']])))
}
df.char.write <- df.char.write %>% mutate(ID.Clean=ids.list)

# add info on MR-Linac versus MR-sim scanning
subs.mrl.dwi <- df.dyn.interp %>% filter(Scanner=='MRL',Metric=='VolumeLowADC') %>% pull(Subject) %>% unique()
df.char.write <- left_join(df.char.write,tibble(ID=subs.mrl.dwi,MRL.DWI=TRUE),by='ID') %>% 
  mutate(MRL.DWI=if_else(is.na(MRL.DWI),0,1),
         SIM.DWI=1) %>%
  relocate(ID.Clean,.after=ID) %>%
  relocate(SIM.DWI,.after=ID.Clean) %>%
  relocate(MRL.DWI,.after=SIM.DWI)

# write dataframe of characteristics
write_csv(df.char.write,file.path(dir.work,phase,'patient_characteristics_full_table.csv'))

# rename tumour locations
df.char <- df.char %>% mutate(Location=str_to_title(str_replace(Location,' LOBE','')))
tumourloc.names <- c('Frontal','Parietal','Temporal','Occipital',NA)
loc.other <- !(df.char$Location %in% tumourloc.names)
df.char$Location[loc.other] <- 'Other'
df.char <- df.char %>% mutate(Location=factor(Location,levels=c(tumourloc.names,'Other')))

# add info on study
df.char <- df.char %>% mutate(Study=ifelse(grepl('GBM',Subject,fixed=TRUE),'GLIO','MOMENTUM')) %>%
  mutate(Study=factor(Study))

# create age table
df.char.age <- df.char %>% summarise(Median=as.character(median(Age)),
                                     Range=paste(range(Age),collapse='-'),
                                     Mean=as.character(mean(Age)),
                                     Std=as.character(sd(Age)),
                                     Q25=as.character(quantile(Age,0.25)),
                                     Q75=as.character(quantile(Age,0.75))) %>% 
  mutate(Characteristic='Age') %>% 
  pivot_longer(c('Median','Range','Mean','Std','Q25','Q75'),names_to='Name',values_to='Value')
df.char.cont <- df.char.age
write_csv(df.char.cont,file.path(dir.work,phase,'patient_ages.csv'))

# create table of other factors
df.char.fancy <- data.frame()
for (charac in c('Study','SimBinned','AgeRank','Sex','Grade','Location','MGMT','IDH1','Resection','Dose')){
  df.char.tmp <- df.char %>% group_by_at(all_of(charac)) %>% 
    summarise(N=n()) %>% 
    mutate(Characteristic=charac) %>%
    relocate(Characteristic) %>%
    rename(Name=charac) %>%
    mutate(pct=round(100*N/sum(N)))
  df.char.fancy <- rbind(df.char.fancy,df.char.tmp)
}
# add info on MRL scanning
mrl.counts <- df.char %>% select(MRLBinned) %>% 
  group_by(MRLBinned) %>% 
  summarise(N=n()) %>%
  filter(!is.na(MRLBinned)) %>%
  mutate(pct=round(100*N/sum(N))) %>%
  rename(Name=MRLBinned) %>%
  mutate(Characteristic='MRLBinned', .before=Name)
df.char.fancy <- rbind(df.char.fancy,mrl.counts)

# write summary of patient characteristics
df.char.fancy <- df.char.fancy %>% 
  mutate(Nstring=sprintf('%d (%d%%)',N,pct)) %>% 
  select(Characteristic,Name,Nstring)
write_csv(df.char.fancy,file.path(dir.work,phase,'patient_characteristics_summary.csv'))

# get list of momentum subjects used
subs.mrl.used <- df.char.write %>% filter(MRL>0) %>% pull(ID)

# compute number of events (death or progression) for each cohort
outcome.count <- df.cor.all %>% select(Subject, Event, Status) %>% 
  pivot_wider(names_from=Event, values_from=Status) %>%
  mutate(Cohort = ifelse(Subject %in% subs.mrl.used, 'MRL', 'GLIO'))

outcome.count %>%
  group_by(Cohort) %>%
  summarise(N.Progression = sum(Progression, na.rm=TRUE),
            N.Death = sum(Death, na.rm=TRUE),
            N.Total = sum(Progression | !Progression | is.na(Progression))) %>%
  write_csv(file.path(dir.work, phase, 'count_outcomes_by_cohort.csv'))

outcome.count %>%
  summarise(N.Progression = sum(Progression, na.rm=TRUE),
            N.Death = sum(Death, na.rm=TRUE),
            N.Total = sum(Progression | !Progression | is.na(Progression))) %>%
  write_csv(file.path(dir.work, phase, 'count_outcomes_all.csv'))

# create table for patient list and flowchart of exclusion ----------------

# join characteristics of patients used in study
have.contours <- read_csv(file.path('data', 'subjects_with_glio_contours.csv')) %>%
  rename(ID = Subject) %>%
  mutate(ID = str_replace(ID,'sub-','')) %>% 
  left_join(df.char.write, by='ID')

# join characteristics of other patients
grade.list <- data.frame()
for (df.name in c('mrl','glio')) {
  df.tmp <- pt.chars[[df.name]] %>% select(Subject, Grade, StatusIDH1) %>% rename(ID=Subject, IDH1=StatusIDH1)
  grade.list <- rbind(grade.list,df.tmp)
}
have.contours <- have.contours %>% left_join(grade.list, by='ID', suffix=c('','.extra'))

# write spreadsheet
write_csv(have.contours, file.path(dir.work, phase, 'subjects_with_glio_contours.csv'))


# determine date of last follow-up ----------------------------------------

# get dataframe of MOMENTUM subjects
study.dates <- df.char %>% select(Subject) %>%
  filter(!grepl('GBM', Subject))

# bind outcomes dataframe of MRL patients
study.dates <- study.dates %>% left_join(df.outcome, by='Subject') %>% 
  select(Subject, ORDate, FollowupDate, EOS)

# determine end of study date
study.dates <- study.dates %>%
  mutate(EOSDate = as_date(EOS)) %>%
  mutate(EndOfStudy = if_else(EOSDate > FollowupDate, EOSDate, FollowupDate, missing=FollowupDate))

# determine time from OR to end of study
study.dates <- study.dates %>% 
  mutate(ORDate = as.Date(ORDate)) %>%
  mutate(FollowTimeDays = as.numeric(EndOfStudy - ORDate))

# concatenate to GLIO data
fu.time <- rbind(
  select(study.dates, Subject, FollowTimeDays),
  select(pt.chars$glio, Subject, MaxTime) %>% rename(FollowTimeDays=MaxTime)
) %>% filter(Subject %in% df.char$Subject)

# create column for MRL versus GLIO and compute summary stats of follow-up time
fu.time <- fu.time %>% mutate(Cohort = ifelse(Subject %in% subs.mrl.used, 'MRL', 'GLIO'))

fu.time %>%
  group_by(Cohort) %>%
  summarise(Median = median(FollowTimeDays),
            Min = min(FollowTimeDays),
            Max = max(FollowTimeDays)) %>%
  write_csv(file.path(dir.work, phase, 'followup_time_days_by_cohort.csv'))

fu.time %>%
  summarise(Median = median(FollowTimeDays),
            Min = min(FollowTimeDays),
            Max = max(FollowTimeDays)) %>%
  write_csv(file.path(dir.work, phase, 'followup_time_days_all.csv'))

# compute maximum of end of study dates for MOMENTUM patients
sink(file.path(dir.work, phase, 'date_of_last_followup.txt'))
print(study.dates %>% filter(EndOfStudy == max(study.dates$EndOfStudy)))
sink()


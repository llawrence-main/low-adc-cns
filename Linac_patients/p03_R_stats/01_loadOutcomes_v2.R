# This script creates tables of time-to-progression/death (TTP/TTD) for each patient


# Phase 1: Load metadata spreadsheets ---------------------

# declare input data directory
dir.in <- file.path('data','metadata')

# read outcome spreadsheet from Sten, Nov. 2021
# Note: I think the sheet "GBM Patients" is more recent, but it doesn't list all 64 patients with IDs GBM021-GBM084
fn.out <- file.path(dir.in,'GLIO_WORKSHEET_NOVEMBER_2021.xlsx')
sheet.name <- 'GBM Patients'
df.out <- cbind(read_excel(fn.out,sheet=sheet.name,range='A16:A62',col_names='HFN'),
                read_excel(fn.out,sheet=sheet.name,range='B16:B62',col_names='Patient ID'),
                read_excel(fn.out,sheet=sheet.name,range='G16:G62',col_names='Age'),
                read_excel(fn.out,sheet=sheet.name,range='H16:H62',col_names='Sex'),
                read_excel(fn.out,sheet=sheet.name,range='T16:T62',col_names='Grade'),
                read_excel(fn.out,sheet=sheet.name,range='Q16:Q62',col_names='StatusResection'),
                read_excel(fn.out,sheet=sheet.name,range='U16:V62',col_names=c('StatusIDH1','StatusMGMT'),na='N/A'),
                read_excel(fn.out,sheet=sheet.name,range='AO16:AO62',col_names='ECOG'),
                read_excel(fn.out,sheet=sheet.name,range='R16:R62',col_names='Location'),
                read_excel(fn.out,sheet=sheet.name,range='Z16:Z62',col_names='Dose'),
                    read_excel(fn.out,sheet=sheet.name,range='I16:I62',na=c('Unknown'),col_names='Clinical status'),
                    read_excel(fn.out,sheet=sheet.name,range='J16:J62',col_types='date',na=c('N/A','<NA>','Unknown','unknown'),col_names='Date of progression'),
                read_excel(fn.out,sheet=sheet.name,range='M16:M62',na=c('Unknown'),col_names='Survival Status'),
                read_excel(fn.out,sheet=sheet.name,range='N16:O62',col_types='date',na=c('N/A','<NA>','Unknown'),col_names=c('Date of Death (if known)','Date of Last Visit/MRI')),
                read_excel(fn.out,sheet=sheet.name,range='AE16:AE62',col_types='date',na=c('N/A','<NA>','Unknown'),col_names='Date of D0 MRI'),
                read_excel(fn.out,sheet=sheet.name,range='P16:P62',col_types='date',na=c('N/A','<NA>','Unknown'),col_names='Date of OR')) %>%
  mutate(Subject=str_replace(`Patient ID`,'-','')) %>%
  select(-`Patient ID`)

# read outcome spreadsheet from Sten, Nov. 2021, for missing patients
# Note: I think the sheet GBM_15T_patient_list is older, but it lists all patients with IDs GBM021-GBM084
sheet.name <- 'GBM_15T_patient_list'
df.out.extra <- cbind(read_excel(fn.out,sheet=sheet.name,range='A2:A85',col_names='HFN'),
                read_excel(fn.out,sheet=sheet.name,range='B2:B85',col_names='Patient ID'),
                read_excel(fn.out,sheet=sheet.name,range='E2:E85',col_names='Age'),
                read_excel(fn.out,sheet=sheet.name,range='F2:F85',col_names='Sex'),
                read_excel(fn.out,sheet=sheet.name,range='R2:R85',col_names='Grade'),
                read_excel(fn.out,sheet=sheet.name,range='O2:O85',col_names='StatusResection'),
                read_excel(fn.out,sheet=sheet.name,range='S2:T85',col_names=c('StatusIDH1','StatusMGMT'),na='N/A'),
                read_excel(fn.out,sheet=sheet.name,range='P2:P85',col_names='Location'),
                    read_excel(fn.out,sheet=sheet.name,range='G2:G85',col_names='Clinical status',na=c('Unknown')),
                    read_excel(fn.out,sheet=sheet.name,range='H2:H85',col_names='Date of progression',col_types='date',na=c('N/A','<NA>','Unknown','unknown')),
                read_excel(fn.out,sheet=sheet.name,range='K2:K85',col_names='Survival Status',na=c('Unknown')),
                read_excel(fn.out,sheet=sheet.name,range='L2:M85',col_names=c('Date of Death (if known)','Date of Last Visit/MRI'),col_types=c('date','date'),na=c('N/A','<NA>','Unknown')),
                read_excel(fn.out,sheet=sheet.name,range='AB2:AB85',col_names='Date of D0 MRI',col_types='date',na=c('N/A','<NA>','Unknown')),
                read_excel(fn.out,sheet=sheet.name,range='N2:N85',col_names='Date of OR',col_types='date',na=c('N/A','<NA>','Unknown'))) %>%
  mutate(Subject=str_replace(`Patient ID`,'-','')) %>%
  select(-`Patient ID`) %>%
  add_column(ECOG=NA,.after='StatusMGMT') %>%
  add_column(Dose=NA,.after='Location')
df.out.extra <- df.out.extra[21:nrow(df.out.extra),]

# insert rows from GBM_15T_patient_list into outcome dataframe if subject not present
loc.missing <- !(df.out.extra$Subject %in% df.out$Subject)
df.out <- rbind(df.out,df.out.extra[loc.missing,]) %>% tibble() %>% arrange(Subject)

# declare baseline date (date of OR if it exists; otherwise date of D0 MRI)
df.out <- df.out %>% mutate(BaselineDate=`Date of OR`)
loc.or.na <- is.na(df.out$BaselineDate)
df.out$BaselineDate[loc.or.na] <- df.out$`Date of D0 MRI`[loc.or.na]

# compute time to progression/death and last visit
df.out <- df.out %>% mutate(TimeToProgression=`Date of progression`- BaselineDate,
                  TimeToDeath=`Date of Death (if known)`- BaselineDate,
                  TimeToLastVisit=`Date of Last Visit/MRI`- BaselineDate)
df.out$`Survival Status`[df.out$`Survival Status`=='died'] <- 'Died'

# compute maximum time followed
df.out <- df.out %>% mutate(MaxTime=mapply(function(x,y) max(x,y,na.rm=TRUE),TimeToDeath,TimeToLastVisit))


# Phase 2: Create tables of time-to-progression/death ---------------------


# create time-to-progression table
df.ttp <- df.out %>% select(Subject,TimeToProgression,TimeToLastVisit,`Clinical status`) %>%
  dplyr::rename(ProgressionStatus=`Clinical status`) %>%
  mutate(Progressed=TRUE,TimeToEvent=TimeToProgression) %>%
  filter(!is.na(ProgressionStatus))
loc.stable <- df.ttp$ProgressionStatus=='Stable'
df.ttp$Progressed[loc.stable] <- FALSE
df.ttp$TimeToEvent[loc.stable] <- df.ttp$TimeToLastVisit[loc.stable]
df.ttp <- df.ttp %>% mutate(TimeToEventMonths=as.numeric(TimeToEvent)/30) %>%
  select(Subject,TimeToEventMonths,Progressed)
write_csv(df.ttp,file.path(dir.work,'time_to_progression.csv'))
# two patients are missing:
# GBM032: no progression or survival data listed
# GBM038: no progression data listed

# create time-to-death table
df.ttd <- df.out %>% select(Subject,TimeToDeath,TimeToLastVisit,`Survival Status`) %>%
  dplyr::rename(SurvivalStatus=`Survival Status`) %>%
  mutate(Died=TRUE,TimeToEvent=TimeToDeath)

# censor GBM075 at time of last visit because date of death not listed even though status==Died
# censor GBM070 at time of last visit because survival status is "unknown" but date of last visit listed
loc.replace <- df.ttd$Subject%in%c('GBM075','GBM070')
df.ttd$SurvivalStatus[loc.replace] <- 'Alive'

# filter patients with no survival status
df.ttd <- df.ttd %>% filter(!is.na(SurvivalStatus))

# set alive patients time to event to time of last visit
loc.alive <- df.ttd$SurvivalStatus=='Alive'
df.ttd$Died[loc.alive] <- FALSE
df.ttd$TimeToEvent[loc.alive] <- df.ttd$TimeToLastVisit[loc.alive]

# select appropriate columns
df.ttd <- df.ttd %>% 
  mutate(TimeToEventMonths=as.numeric(TimeToEvent)/30) %>%
  select(Subject,TimeToEventMonths,Died)

write_csv(df.ttd,file.path(dir.work,'time_to_death.csv'))
# two patients are missing:
# GBM032: no progression or survival data listed
# GBM036: no survival data listed

# Phase 3: Plot TTP/TTD stats ------------------------------------------------------


# bar plot: number of patients who have progressed
p.ttp.bar <- df.ttp %>% ggplot(aes(x=Progressed)) +
  geom_bar() +
  theme(text=element_text(size=20))
ggsave(file.path(dir.work,'time_to_progression_count.pdf'),plot=p.ttp.bar)

# Kaplan Meier survival curve for TTP
km.ttp <- survfit(Surv(TimeToEventMonths, Progressed) ~ 1, data=df.ttp)
p.ttp.km <- autoplot(km.ttp) +
  theme(text=element_text(size=20)) +
  labs(x='Time from RT planning (months)',y='Proportion progression-free')
ggsave(file.path(dir.work,'km_progression.pdf'),plot=p.ttp.km,width=11,height=7)

# bar plot: number of patients who have died
p.ttd.bar <- df.ttd %>% ggplot(aes(x=Died)) +
  geom_bar() +
  theme(text=element_text(size=28))
ggsave(file.path(dir.work,'time_to_death_count.pdf'),plot=p.ttd.bar)

# Kaplan Meier survival curve for TTD
km.ttd <- survfit(Surv(TimeToEventMonths,Died) ~ 1,data=df.ttd)
p.ttd.km <- autoplot(km.ttd) +
  theme(text=element_text(size=28)) +
  labs(x='Time from RT planning (months)',y='Proportion alive')
ggsave(file.path(dir.work,'km_death.pdf'),plot=p.ttd.km,width=11,height=7)


# Phase 4: Create table of clinical factors --------------------------------

# select salient columns of table
df.meta <- df.out %>% select(Subject,Age,Sex,Grade,StatusResection,StatusMGMT,StatusIDH1,ECOG,Location,Dose) %>%
  rename(GradeCode=Grade)

# change grade codes from numbers to numerals
grade.codes <- tribble(
  ~GradeCode,~Grade,
  1,'I',
  2,'II',
  3,'III',
  4,'IV'
)
df.meta <- df.meta %>% left_join(grade.codes,by='GradeCode') %>% select(-GradeCode)

# modify naming for resection
df.meta$StatusResection[df.meta$StatusResection=='biopsy'] <- 'Biopsy'
df.meta$StatusResection[df.meta$StatusResection=='No resection'] <- 'NoResection'

# modify naming for MGMT
df.meta <- df.meta %>% mutate(StatusMGMT=str_to_title(StatusMGMT))
df.meta$StatusMGMT[df.meta$StatusMGMT=='Unmethyalted'] <- 'Unmethylated'
# df.meta$StatusMGMT[df.meta$StatusMGMT=='Unknown'] <- NA

# modify naming for IDH1
df.meta$StatusIDH1[df.meta$StatusIDH1=='WT'] <- 'Wildtype'
df.meta$StatusIDH1[df.meta$StatusIDH1=='unknown'] <- 'Unknown'

# order columns
df.clin <- df.meta %>% select(Subject,Age,Sex,Grade,StatusResection,StatusMGMT,StatusIDH1,ECOG,Location,Dose)

# write table
write_csv(df.clin,file.path(dir.work,'clinical_factors.csv'))

### 02_createModelData
# creates the dataframe used for survival prediction

# Preprocess table of low-ADC region metrics ----------------------------------------------------

# read table of volume dynamic metrics
dyn.table.name <- 'dyn_table'
fn.dyn <- file.path('results','volume_dynamics',sprintf('%s.csv',dyn.table.name))
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

# # subset to low-ADC volume only
# df.dyn <- df.dyn %>% filter(Metric=='VolumeLowADC') %>%
#   select(-Metric)

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

# make plot of day for each timepoint to verify
p.timepoints <- df.dyn %>% ggplot(aes(x=Timepoint,y=Day)) +
  geom_point() +
  theme(text=element_text(size=20))
ggsave(file.path(dir.work,'day_versus_timepoints.jpg'),
       plot=p.timepoints,
       width=8,
       height=6)

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
write_csv(df.cor.all,file.path('results','response_correlation_dataframe.csv'))
write_csv(df.baseline,file.path('results','volume_dynamics','dyn_table_baseline.csv'))


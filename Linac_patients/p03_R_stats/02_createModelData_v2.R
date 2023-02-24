### 02_createModelData
# creates the table used for Kaplan-Meier survival analysis

# declare input data directory
dir.in <- file.path('interim')

# load low-ADC volume table
fn.adc <- file.path(dir.in,'low_adc_volumes.csv')
df.adc <- read_csv(fn.adc,col_types=list(
  col_factor(),
  col_factor(),
  col_factor(),
  col_double(),
  col_factor(),
  col_double()
))

# subset to grade III/IV patients
df.adc <- df.adc %>% left_join(df.clin,by='Subject') %>% filter(Grade %in% c('III','IV'))

# subset to ADC threshold of 1.25 and enclosing ROI
df.adc <- df.adc %>% filter(ADCThreshold==1.25,EnclosingROI==enclosing.roi.use)

# load table of temporal labels and join to table of low-ADC volumes
scan.dict <- tibble(Timepoint=factor(c('d0','d10','d20','d60')),Scan=factor(c('Fx0','Fx10','Fx20','P1M')))
df.labels <- read_tsv(file.path(dir.in,'derivatives','session_dict','session_dict.tsv'),col_types=list(
  col_factor(),
  col_factor(),
  col_datetime(),
  col_factor()
)) %>%
  left_join(scan.dict,by='Timepoint')
df.adc <- df.adc %>% left_join(df.labels,by=c('Subject','Session'))

# compute relative change in volume of low-ADC region and enclosing ROI
df.baseline <- df.adc %>% filter(Scan=='Fx0') %>% select(Subject,EnclosingROI,ADCThreshold,VolumeEnclosingROI,Volume) %>%
  dplyr::rename(VolumeEnclosingROI0=VolumeEnclosingROI,Volume0=Volume)
df.delta <- df.adc %>% left_join(df.baseline,by=c('Subject','EnclosingROI','ADCThreshold')) %>%
  filter(!is.na(Volume0)) %>% # exclude subjects with no Fx0 low-ADC region
  filter(Volume0>0) %>% # exclude low-ADC regions with zero volume at baseline
  mutate(DeltaPc=100*(Volume-Volume0)/Volume0) %>%
  mutate(DeltaPcEnclosing=100*(VolumeEnclosingROI-VolumeEnclosingROI0)/VolumeEnclosingROI0) %>%
  filter(!(Scan=='Fx0'))

# subset dataframe to subject-sessions with high Dice scores between AIAA tumourcore and planning GTV
if (filter.by.dice) {
  # load table of Dice scores
  dice <- read_csv(file.path('interim','dice_contour_sources.csv'),col_types=list(
    col_factor(),
    col_factor(),
    col_factor(),
    col_factor(),
    col_double()
  )
  )
  dice <- dice %>% mutate(Contour1=str_replace_all(Contour1,'-','\\.'),Contour2=str_replace_all(Contour2,'-','\\.'))
  
  # determine subject-sessions with high Dice scores
  scans.good.dice <- dice %>% filter(Contour1=='manual.GTV.plan',Contour2=='aiaa.tumourcore') %>% filter(Dice>dice.threshold) %>% select(Subject,Session,Dice)
  
  # subset dataframe of ADC changes
  df.delta <- inner_join(scans.good.dice,df.delta,by=c('Subject','Session'))
}

# join to table of outcomes
df.ttp.renamed <- df.ttp %>% rename(Status=Progressed) %>% mutate(Event='Progression')
df.ttd.renamed <- df.ttd %>% rename(Status=Died) %>% mutate(Event='Death')
df.outcomes <- rbind(df.ttp.renamed,df.ttd.renamed) %>%
  select(Subject,Event,TimeToEventMonths,Status)

# reshape dataframe for survival correlationdf.co
df.cor.all <- df.delta %>% left_join(df.outcomes,by='Subject') %>% ungroup() %>% 
  select(Event,TimeToEventMonths,Status,Subject,Scan,DeltaPc,DeltaPcEnclosing,Age,Sex,Grade,StatusResection,StatusMGMT,StatusIDH1,ECOG,Location,Dose) %>%
  rename(dLowADC=DeltaPc,dGTV=DeltaPcEnclosing) %>%
  pivot_wider(names_from=c('Scan'),values_from=c('dLowADC','dGTV'),names_sep='.') %>%
  mutate(Event=factor(Event))

# declare predictor and outcome  column names
scans <- c("Fx10","Fx20","P1M")
preds.volume <- expand.grid(c("dLowADC","dGTV"),scans) %>%
  mutate(Combo=mapply(function(x,y)paste(x,y,sep='.'),Var1,Var2)) %>% 
  pull(Combo)
events <- levels(df.cor.all$Event)

# write correlation dataframe
write_csv(df.cor.all,file.path('interim','response_correlation_dataframe.csv'))

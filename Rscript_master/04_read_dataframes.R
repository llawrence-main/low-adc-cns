# 04_read_dataframes
# read dataframes of low-ADC volumes and outcomes from GLIO and MOMENTUM cohorts

phase <- 'read_dataframes'
dir.create(file.path(dir.work,phase),showWarnings=FALSE)

# Read dataframes for response correlation for MOMENTUM and GLIO patients --------------------------------

# declare predictors
scans <- c("Fx10","Fx20","P1M")
preds.volume <- expand.grid(c("dLowADC","dGTV"),scans) %>%
  mutate(Combo=mapply(function(x,y)paste(x,y,sep='.'),Var1,Var2)) %>% 
  pull(Combo)

# declare columns to select
salient <- c('Event','Subject','TimeToEventMonths','Status',preds.volume,'Age','Sex','ECOG','Grade','Location','StatusMGMT','StatusIDH1','StatusResection','Dose')

# MOMENTUM study dataframe
df.momentum <- read_csv(file.path(dir.results,'preproc_mrl','response_correlation_dataframe.csv')) %>%
  select(all_of(salient))

# GLIO study dataframe
df.glio <- read_csv(file.path(dir.results,'preproc_glio','response_correlation_dataframe.csv')) %>%
  select(all_of(salient))

# bind dataframes and exclude unwanted subjects
df.cor.all <- rbind(df.momentum,df.glio)

# omit grade III subjects and IDH1 mutated subjects
subs.gradeIII.IDHmut <- df.cor.all %>% filter(Grade=='III' | StatusIDH1=='Mutated') %>% pull(Subject) %>% unique()
subs.exclude <- unique(c(subs.exclude,subs.gradeIII.IDHmut))

df.cor.all <- df.cor.all %>%
  filter(!Subject %in% subs.exclude)

# rename columns
df.cor.all <- df.cor.all %>% rename(Resection=StatusResection,MGMT=StatusMGMT,IDH1=StatusIDH1)

# add early/late progression and death columns
df.event.times <- tribble(
  ~Event,~MedianEventTime,
  'Death',14.6,
  'Progression',6.9
) # median survival and progression-free survival for RT + TMZ from Stupp et al., New Engl J Med, 2005
df.cor.all <- df.cor.all %>% left_join(df.event.times,by='Event') %>% mutate(IsEarly=as.integer((TimeToEventMonths<MedianEventTime)&(Status)))
loc.tbd <- (df.cor.all$Status==FALSE) & (df.cor.all$TimeToEventMonths<df.cor.all$MedianEventTime) # early/late status cannot be determined yet
loc.norecord <- is.na(df.cor.all$TimeToEventMonths) # no record of event time
df.cor.all$IsEarly[loc.tbd|loc.norecord] <- NA

# declare events
events <- c('Progression','Death')

# add missing info
clin.extra <- read_excel('data/extra_patient_info.xlsx') %>%
  filter(ID %in% c('GBM040','GBM044','GBM081')) %>%
  select(ID,Dose) %>%
  rename(Subject=ID)
df.cor.all <- df.cor.all %>% left_join(clin.extra,by='Subject',suffix=c('','.override')) %>%
  mutate(Dose=if_else(is.na(Dose.override),Dose,Dose.override)) %>%
  select(-Dose.override)

# Read volume dynamics dataframe for MOMENTUM patients on MRL and interpolate volumes -------------

# read volume dynamics dataframe for MOMENTUM patients and exclude unwanted subjects
df.dyn <- read_csv(file.path('data','MRL_dyn_table.csv')) %>%
  filter(!Subject %in% subs.exclude) %>%
  filter(!Subject %in% subs.exclude.dyn)

# read timepoint info
df.timepoint <- read_csv(file.path(dir.results,'preproc_mrl','MRL_fraction_session.csv')) %>%
  filter(!Subject %in% subs.exclude)
session.sim <- read_csv(file.path('data','session_day_sim.csv'))
df.timepoint.day <- df.timepoint %>% left_join(select(session.sim,Subject,Session,TxDay),by=c('Subject','Session'))

# declare dataframe for MR-sim low-ADC volumes
df.dyn.sim <- df.dyn %>% filter(grepl('sim',Session,fixed=TRUE),Session==TumourcoreSession)

# get subjects used in response correlation
subjects.cor <- df.cor.all$Subject

# get dataframe of correspondence between MR-sim sessions and days
# df.days <- df.dyn.sim %>% filter(Metric=='VolumeLowADC') %>% select(Subject,TumourcoreSession,Day)
df.days <- df.timepoint.day %>% select(Subject,Session,TxDay) %>% rename(TumourcoreSession=Session,Day=TxDay)

# get volume dynamics dataframe with MRL data and low-ADC volume only; bind to MR-sim days
df.dyn <- df.dyn %>%
  left_join(df.days,by=c('Subject','TumourcoreSession'),suffix=c('','.sim'))
df.dyn.mrl <- df.dyn %>% filter(grepl('MRL',Session,fixed=TRUE))

# declare interpolation function
my_interp <- function(xs,ys,xouts){
  # interpolates from sample points and a single query point and returns a single interpolated value
  # query point argument may be a vector, but all values must be identical
  
  if (length(xs)<2){
    return(NA)
  } else {
    qx <- xouts[1]
    assert(all(qx==xouts),msg='first value not equal to all other values in xouts')
    # use value at previous sample point
    res <- approx(x=xs,y=ys,xout=qx,method='constant',f=0,rule=1:2)
    return(res$y)
  }
}

if (verbose){
  # test my_interp
  x.test <- seq(0,5,1)
  y.test = x.test^2
  
  x.out <- 1.5
  y.interp <- my_interp(x.test,y.test,x.out)
  
  x.out2 <- rep(3.5,5)
  y.interp2 <- my_interp(x.test,y.test,x.out2)
  
  pdf(file=file.path(dir.work,phase,'my_interp_function_test.pdf'))
  plot(x.test,y.test,'b',main='Interpolation function test')
  points(x.out,y.interp,col='red')
  points(x.out2[1],y.interp2,col='blue')
  dev.off()
}

# interpolate volumes
df.dyn.interp <- df.dyn.mrl %>% filter(Subject %in% subjects.cor) %>% 
  group_by(Subject,Session,Day,Metric) %>% 
  summarise(InterpValue=my_interp(xs=Day.sim,ys=Value,xouts=Day)) %>%
  ungroup() %>%
  rename(Value=InterpValue)


# check interpolation command
if (verbose){
  # create test dataframe
  v.day <- seq(0,42,1)
  n.days <- length(v.day)
  v.simday <- c(-10,14,28,60)
  n.simdays <- length(v.simday)
  v.values <- c(1,2,3,4)
  df.test <- data.frame(Day=rep(v.day,n.simdays),
             Day.sim=rep(v.simday,times=1,each=n.days),
             Value=rep(v.values,times=1,each=n.days)) %>%
    tibble()
  df.test.interp <- df.test %>% group_by(Day) %>% summarise(Value=my_interp(xs=Day.sim,ys=Value,xouts=Day))
  p.test.interp <- df.test %>% mutate(Day.sim=factor(Day.sim)) %>%
    ggplot(aes(x=Day,y=Value)) +
    geom_point(aes(color=Day.sim)) +
    geom_line(aes(color=Day.sim)) +
    geom_point(data=df.test.interp) +
    geom_line(data=df.test.interp) +
    labs(x='Day',y='Low-ADC volume (a.u.)',title='Test of interpolation of low-ADC volumes')
  
  ggsave(file.path(dir.work,phase,'interpTest_lowADC_artificialData.pdf'),plot=p.test.interp)
}

# plot low-ADC volume timeseries for one subject using all MR-sim contours
subs.interp <- unique(df.dyn.interp$Subject)
for (sub.interp in subs.interp){
  df.interp.sub <- df.dyn.interp %>% filter(Subject==sub.interp,Metric=='VolumeLowADC')
  p.dyn.interp <- df.dyn.mrl %>% 
    filter(Subject==sub.interp,Metric=='VolumeLowADC') %>%
    mutate(Day.sim=factor(Day.sim)) %>%
    ggplot(aes(x=Day,y=Value)) +
    geom_point(aes(color=Day.sim)) +
    geom_line(aes(color=Day.sim)) +
    geom_point(data=df.interp.sub,aes(x=Day,y=Value)) +
    geom_line(data=df.interp.sub,aes(x=Day,y=Value)) +
    scale_x_continuous(breaks=seq(0,45,5),labels=seq(0,45,5)) +
    labs(x='Days',y='Low-ADC volume (cc)',title=sprintf('%s low-ADC timeseries',sub.interp))
  ggsave(file.path(dir.work,phase,sprintf('interpTest_lowADC_%s.jpg',sub.interp)),plot=p.dyn.interp)
}

# join to dataframe of MR-sim
df.dyn.interp <- cbind(df.dyn.interp,data.frame(Scanner='MRL'))
df.dyn.interp <- df.dyn.sim %>% 
  select(Subject,Session,Day,Metric,Value) %>%
  filter(Subject %in% subjects.cor) %>%
  cbind(data.frame(Scanner='Sim')) %>%
  rbind(df.dyn.interp) %>%
  tibble()

# read table of baseline values for MR-sim
df.baseline <- read_csv(file.path(dir.results,'preproc_mrl','dyn_table_baseline.csv')) %>%
  filter(!Subject %in% subs.exclude) %>%
  mutate(Scanner='Sim') %>%
  relocate(Scanner,.after='Metric')

# use MR-sim values for MRL baseline
df.baseline.mrl <- df.baseline %>% filter(Metric=='VolumeLowADC') %>%
  mutate(Scanner='MRL')
df.baseline <- rbind(df.baseline,df.baseline.mrl)

# compute change relative to baseline
df.dyn.interp <- df.baseline %>%
  right_join(df.dyn.interp,by=c('Subject','Metric','Scanner'),suffix=c('.baseline','')) %>%
  mutate(Delta=Value-Value.baseline,
         DeltaPc=100*(Value-Value.baseline)/Value.baseline)

# bind to dataframe of early/late death
df.outcomes.mrl <- df.cor.all %>% filter(!grepl('GBM',Subject,fixed=TRUE))
df.dyn.interp <- df.outcomes.mrl %>% select(Subject,Event,IsEarly,TimeToEventMonths,Status) %>%
  right_join(df.dyn.interp,by=c('Subject')) %>%
  mutate(IsEarly=as.logical(IsEarly))

# add timepoint info for MR-sim scans
df.dyn.interp <- df.dyn.interp %>% left_join(df.timepoint,by=c('Subject','Session'))

# plot histogram of low-ADC volumes at baseline
p.baseline.vol <- df.baseline %>%
  filter(Scanner=='MRL') %>%
  ggplot(aes(x=Value)) +
  geom_histogram(bins=20) +
  labs(x='Low-ADC volume (cc)',y='Count') +
  theme(text=element_text(size=28))
ggsave(file.path(dir.work,phase,'lowADC_baseline_volume.tiff'),
       plot=p.baseline.vol,
       width=10,
       height=7)

# create plots of patient metadata --------------------------------------------------------

# plot grade
df.grade <- df.cor.all %>% group_by(Subject,Grade) %>% summarise(n=n()) %>% select(-n)
if (verbose){
  p.grade <- df.grade %>%
    ggplot(aes(x=Grade)) + 
    geom_bar() +
    theme(text=element_text(size=20))
  ggsave(file.path(dir.work,phase,'patient_grade_barplot.pdf'),plot=p.grade,width=7,height=7)

  # summarize GTV volume changes for MR-sim scans and outcome data
  mrsim.data <- df.cor.all %>% select(Subject,Event,TimeToEventMonths,dGTV.Fx10,dGTV.Fx20,dGTV.P1M) %>%
    pivot_wider(names_from=Event,values_from=TimeToEventMonths,names_prefix='TimeTo')
  write_csv(mrsim.data,file.path(dir.work,phase,'mrsim_data_summary.csv'))
  
  # summarize baseline low-ADC and GTV volumes
  vol.baseline.summary <- df.baseline %>% group_by(Metric) %>% summarise(Median=median(Value),Mean=mean(Value),Min=min(Value),Max=max(Value))
  write_csv(vol.baseline.summary,file.path(dir.work,phase,'baseline_volume_summary.csv')) 

}

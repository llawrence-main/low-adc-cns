# 09_evaluateBias
# evaluates the bias of the low-ADC volumes on the MRL relative to MR-sim

phase <- 'bias_eval'
dir.create(file.path(dir.work,phase),showWarnings=FALSE)

# read volume dynamics dataframes for MOMENTUM patients subset to low-ADC volume and MRL scanner
df.bias <- read_csv(file.path('data','MRL_dyn_table.csv')) %>%
  filter(Metric=='VolumeLowADC',grepl('MRL',Session,fixed=TRUE)) %>%
  select(-Metric) %>% tibble() %>%
  filter(!Subject %in% subs.exclude) %>%
  filter(!Subject %in% subs.exclude.dyn)

# subset volume dataframes to MRL scan taken same day as MR-sim, join to table of MR-sim volumes, compute differences
df.bias <- df.dyn.sim %>% filter(Metric=='VolumeLowADC') %>% select(Subject,TumourcoreSession,Day,Value) %>%
  right_join(df.bias,by=c('Subject','TumourcoreSession'),suffix=c('.sim','')) %>%
  filter(Day==Day.sim) %>%
  mutate(DiffAbs=Value-Value.sim,
         DiffRel=DiffAbs/Value.sim*100) %>%
  pivot_longer(cols=c(DiffAbs,DiffRel),names_to='DiffType',values_to='DiffVal')

# write bland-altman stats
bias.stats <- df.bias %>% group_by(DiffType) %>% summarise(DiffsMedian=median(DiffVal),DiffsMean=mean(DiffVal),LOA.Lower=DiffsMean-1.96*sd(DiffVal),LOA.Upper=DiffsMean+1.96*sd(DiffVal),DiffsQ5=quantile(DiffVal,0.05),DiffsQ95=quantile(DiffVal,0.95),Min=min(DiffVal),Max=max(DiffVal),N=n())
bias.stats %>%
  write_csv(file.path(dir.work,phase,'biasEval_bland_altman_stats.csv'))

# create bland altman plot for original volumes alone
diff.types <- unique(bias.stats$DiffType)
for (diff.type in diff.types){
  bias.stats.plot <- bias.stats %>% filter(DiffType==diff.type) 
  p.bias.ba.orig <- df.bias %>% 
    filter(DiffType==diff.type) %>%
    ggplot(aes(x=Value.sim,y=DiffVal)) +
    geom_point(size=4) +
    geom_hline(yintercept=bias.stats.plot$DiffsMedian,linetype='solid',size=1) +
    theme(text=element_text(size=32),
          plot.margin=margin(10,20,0,0)) +
    labs(x='MRsim (cc)',y=diff.type) 
  ggsave(file.path(dir.work,phase,sprintf('biasEval_bland_altman_plot_%s.eps',diff.type)),plot=p.bias.ba.orig,width=9,height=7,dpi=400)
}

# write number of unique patients and number of scans
n.bias.subs <- df.bias %>% pull(Subject) %>% unique() %>% length()
n.paired.total <- df.bias %>% nrow()/2
bias.numbers <- data.frame(NumberSubjects=n.bias.subs, NumberPairedScans=n.paired.total)
write_csv(bias.numbers, file.path(dir.work, phase, 'biasEval_numbers.csv'))

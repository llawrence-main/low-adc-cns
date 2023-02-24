# 08_mrl_survival
# correlation of intra-treatment ADC changes and outcome for MOMENTUM patients

prefix <- 'respMomentum'

phase <- 'survival_mrl'
dir.create(file.path(dir.work,phase),showWarnings=FALSE)

# Pre-process MRL data to resample to common timepoints and stratify --------------------------------------------------

# resample MRL data to common time points by linear interpolation
approx.yvals <- function(x,y,xout){
  res <- approx(x=x,y=y,xout=xout)
  return(res$y)
}
days.bin <- seq(0,40,5)
df.dyn.interp.mrl.lowadc <- df.dyn.interp %>% filter(Scanner=='MRL',Metric=='VolumeLowADC',!is.na(Value.baseline))
n.sub <- length(unique(df.dyn.interp.mrl.lowadc$Subject))
df.mrl.res.all <- df.dyn.interp.mrl.lowadc %>% 
  group_by(Subject,Event,IsEarly,TimeToEventMonths,Status,Scanner) %>% 
  summarise(DeltaPc=approx.yvals(x=Day,y=DeltaPc,xout=days.bin)) %>%
  ungroup() %>%
  cbind(data.frame(Day=rep(days.bin,times=n.sub))) %>%
  tibble() %>%
  select(Subject,Event,IsEarly,TimeToEventMonths,Status,Day,Scanner,DeltaPc)
df.mrl.res <- df.mrl.res.all %>% filter(!is.na(IsEarly)) %>%
  select(Subject,Event,IsEarly,Day,Scanner,DeltaPc)

# resample MR-sim low-ADC volumes by nearest neighbour
df.sim.res <- df.dyn.interp %>% filter(Scanner=='Sim',
                         Metric=='VolumeLowADC',
                         !is.na(IsEarly),
                         !Timepoint=='Fx0') %>%
  select(-Day) %>%
  left_join(fx.day,by='Timepoint') %>%
  select(Subject,Event,IsEarly,Day,Scanner,DeltaPc)

# bind data frames
df.res <- rbind(df.mrl.res,df.sim.res) %>%
  mutate(Day=as.integer(Day))

# compute strata by low-ADC change
df.medians.mrl <- df.mrl.res.all %>% group_by(Event,Day) %>%
  summarise(MedianDeltaPc=median(DeltaPc,na.rm=TRUE))
df.mrl.res.all <- df.mrl.res.all %>% left_join(df.medians.mrl,by=c('Event','Day')) %>%
  mutate(Stratum = ifelse(DeltaPc>MedianDeltaPc,'Above','Below')) %>%
  mutate(Stratum = factor(Stratum,levels=c('Below','Above')))
write_csv(df.medians.mrl, file.path(dir.work, phase, 'mrl_stratification_thresholds.csv'))

# declare plotting parameters -------------------------------------

scan.labs <- c('MR-Linac','MR-sim')
scanner.list <- c('MRL','Sim')
names(scan.labs) <- c('MRL','Sim')

# create boxplots of resampled data, grouped by early/late progression
scanner.xlims <- rbind(c(-3,45),c(-3,80))
rownames(scanner.xlims) <- scanner.list

scanner.ypos <- c(220,90)
names(scanner.ypos) <- scanner.list

scanner.ylims <- rbind(c(-100,240),c(-100,100))
rownames(scanner.ylims) <- scanner.list

scanner.width <- c(3,10)
names(scanner.width) <- scanner.list

# Plot low-ADC changes from MR-Linac at each time point ----------------------

dw <- scanner.width['MRL']

# dummy dataframe for geom_signif to make placement of brackets completely manual
dummy.data <- tribble(
  ~Day,~DeltaPc,~IsEarly,
  10,100,TRUE
)

df.pvals.all <- data.frame()
for (event in events.cox) {

  # do Wilcoxon rank-sum test
  df.mrl.earlylate <- df.mrl.res.all %>%
    filter(Event==event,!is.na(IsEarly))
  df.pvals <- data.frame()
  for (timepoint in days.bin){
    df.earlylate.subset <- df.mrl.earlylate %>% filter(Day==timepoint,
                                                       !is.na(DeltaPc))
    res.wilcox <- wilcox.test(formula=DeltaPc~IsEarly,data=df.earlylate.subset,alternative='less')
    df.pvals <- rbind(df.pvals,data.frame(
      Day=timepoint,
      pVal=res.wilcox$p.value,
      n=nrow(df.earlylate.subset)))
  }
  df.pvals <- df.pvals %>% mutate(Outcome=event) %>% relocate(Outcome)
  df.pvals.all <- rbind(df.pvals.all, df.pvals)
}

df.pvals.all <- df.pvals.all %>% 
  mutate(pValAdjusted = p.adjust(pVal, method='holm')) %>%
  mutate(Significant=pValAdjusted<alph)
write_csv(df.pvals.all,file.path(dir.work,phase,'wilcoxon_pvalues_volumeChange_by_earlyLate_outcome.csv'))


# plot low-ADC volume changes with grouping by response
for (event in events.cox){
  
  df.pvals <- df.pvals.all %>% filter(Outcome==event)
  
  # declare min and max x-values
  days.signif <- df.pvals %>% filter(Significant==TRUE) %>% pull(Day)
  xmins <- days.signif-dw/4.0
  xmaxs <- days.signif+dw/4.0
  signif.ypos <- 220

  # plot low-ADC volumes for all patients
  p.mrl.res.all <- df.mrl.res.all %>%
    filter(Event==event, !is.na(IsEarly)) %>%
    ggplot(aes(x=Day,y=DeltaPc,shape=IsEarly,linetype=IsEarly)) +
    geom_violin(aes(group=interaction(Day,IsEarly)),position=position_dodge(width=dw),scale='width',width=2.5,draw_quantiles=c(0.5),lwd=1) +
    geom_point(size=2,position=position_jitterdodge(jitter.width=0,dodge.width=dw,seed=0)) +
    theme(text=element_text(size=36)) +
    labs(x='Time from first fraction (days)',y='Volume change (%)') +
    scale_color_manual(values=c('#000000','#FF0000')) +
    scale_shape_manual(values=shapes.isearly) +
    scale_linetype_manual(values=ltypes.isearly) +
    scale_x_continuous(breaks=days.bin,labels=days.bin) +
    scale_y_continuous(limits=scanner.ylims['MRL',])
  filename.jpg <- file.path(dir.work,phase,sprintf('lowADC_all_patients_outcome-%s.eps',event))
  ggsave(filename.jpg,
         plot=p.mrl.res.all,
         width=12,
         height=8)

}

# Do Cox modelling --------------------------------------------------------

hr.col <- '#0055FF' # colour for low-ADC region

# declare predictors and formulas for Cox modelling
formulas.cox <- c(as.formula('Surv(TimeToEventMonths,Status) ~ Stratum'))

# do Cox tests
res.cox.mrl <- data.frame()
zph.tests.mrl <- data.frame()
for (event in events.cox){
  for (day in days.bin){
    models.cox <- lapply(formulas.cox,function(x) coxph(x,data=df.mrl.res.all,subset=(Day==day)&(Event==event)))
    results.cox <- lapply(models.cox,
                          function(x){
                            x <- summary(x)
                            p.value<-x$sctest["pvalue"]
                            sc.test<-signif(x$sctest["test"],2)
                            beta<-signif(x$coef[1], digits=5);#coefficient beta
                            HR <-signif(x$coef[2], digits=5);#exp(beta)
                            HR.confint.lower <- signif(x$conf.int[,"lower .95"], 5)
                            HR.confint.upper <- signif(x$conf.int[,"upper .95"],5)
                            HR.confint <- paste0(HR.confint.lower, " - ", HR.confint.upper)
                            N <- x$n
                            res<-c(beta, HR, HR.confint.lower, HR.confint.upper, HR.confint, sc.test, p.value, N)
                            names(res)<-c("beta", "HR", "CI.Lower", "CI.Upper", "95% CI for HR", "ScTest",
                                          "pVal", "N")
                            return(res)
                          })
    res.tmp <- as.data.frame(t(as.data.frame(results.cox,check.names=FALSE)))
    res.tmp <- rownames_to_column(res.tmp,var='Predictor')
    res.tmp <- res.tmp %>%
      mutate(Day=day,.before=Predictor) %>%
      mutate(Event=event,.before=Day) %>%
      mutate(pVal=as.numeric(as.character(pVal))) %>%
      mutate(
        N=as.integer(as.character(N)),
        beta=as.numeric(as.character(beta)),
        HR=as.numeric(as.character(HR)),
        CI.Lower=as.numeric(as.character(CI.Lower)),
        CI.Upper=as.numeric(as.character(CI.Upper)),
        ScTest=as.numeric(as.character(ScTest)))
    res.cox.mrl <- rbind(res.cox.mrl,res.tmp)
    
    res.zph <- cox.zph(models.cox[[1]])
    zph.tests.mrl <- rbind(zph.tests.mrl,
                           data.frame(event=event,
                                      day=day,
                                      p.value=res.zph$table['Stratum','p'])
    )
  }
}

# plot hazard ratio over time
hr.col <- '#0055FF'
p.hr <- res.cox.mrl %>% ggplot(aes(x=Day)) +
  facet_wrap(vars(Event),ncol=1) +
  geom_point(aes(y=HR),size=8,shape=shape.codes[1]) +
  geom_errorbar(aes(ymin=CI.Lower,ymax=CI.Upper),width=1.5,size=1.5) +
  geom_hline(aes(yintercept=1),linetype='dashed') +
  theme(text=element_text(size=32)) +
  labs(x='Time from first fraction (days)',y='Hazard ratio') +
  scale_x_continuous(labels=seq(0,40,5),breaks=seq(0,40,5)) +
  scale_y_continuous(trans='log10', limits=c(0.05, 200)) +
  theme(text=element_text(size=36),
        panel.grid.major.y = element_line(color='#CCCCCC'),
        panel.grid.minor.y = element_blank(),
        panel.grid.minor.x = element_blank(),
        legend.position = 'none')
ggsave(file.path(dir.work,phase,'Cox_hazard_ratio.eps'),
       plot=p.hr,
       width=8,
       height=12,
       dpi=300)

# adjust p-values
res.cox.mrl <- res.cox.mrl %>% mutate(pValAdjusted=p.adjust(pVal,method='holm')) %>%
  mutate(Significant=pValAdjusted<alph) %>%
  mutate(pValAdjusted = sapply(pValAdjusted,fmt.pval),
         pVal=sapply(pVal,fmt.pval))
  

if (verbose){
  # plot p-values over time
  p.pvals <- res.cox.mrl %>%
    ggplot(aes(x=Day,y=pValAdjusted)) +
    facet_wrap(vars(Event),ncol=1) +
    geom_point(size=6,color=hr.col) +
    geom_hline(aes(yintercept=0.05),linetype='dashed') +
    scale_x_continuous(labels=seq(0,80,10),breaks=seq(0,80,10),limits=c(-2,80)) +
    scale_y_continuous(trans='log10',limits=c(1e-4,2)) +
    labs(x='Time from first fraction (days)',y='p-value',fill='Predictor') +
    theme(text=element_text(size=36),
          panel.grid.major.y = element_line(color='#CCCCCC'),
          panel.grid.minor.y = element_blank(),
          panel.grid.minor.x = element_blank(),
          legend.position = 'none')
  ggsave(file.path(dir.work,phase,'Cox_adjusted_pvalue.pdf'),
         plot=p.pvals,
         width=9,
         height=8)
}

# create fancy table for paper
res.cox.mrl.fancy <- res.cox.mrl %>% 
  select(Event, Day, HR, CI.Lower, CI.Upper, pValAdjusted, N) %>%
  tibble() %>%
  mutate(HR = signif(HR, digits=2),
         CI.Lower = signif(CI.Lower, digits=2),
         CI.Upper = signif(CI.Upper, digits=2)) %>%
  mutate(HR.string = sprintf('%.2f [%.3f, %.3f]', HR, CI.Lower, CI.Upper))
write_csv(res.cox.mrl.fancy, file.path(dir.work, phase, 'Cox_hazard_ratios_fancy.csv'))

# write table of p-values used in plot
write_csv(res.cox.mrl,file.path(dir.work,phase,'Cox_hazard_ratios.csv'))

# write table of hazard ratios and proportional hazards assumption tests
write_csv(zph.tests.mrl, file.path(dir.work, phase, 'Cox_PH_tests.csv'))

# write the number of events
num.events <- df.mrl.res.all %>% group_by(Subject,Event,Status) %>% summarise(n=n()) %>% group_by(Event) %>% summarise(NumEvents=sum(Status,na.rm=TRUE))
write_csv(num.events, file.path(dir.work, phase, 'number_of_events.csv'))

# Compute concordance index over time -------------------------------------

# preprocess MRL low-ADC measurements
mrl.lowADC <- df.mrl.res.all %>% 
  pivot_wider(id_cols=c('Subject','Event','TimeToEventMonths','Status'),names_from=Day,values_from=Stratum,names_prefix='D') %>%
  filter(!is.na(TimeToEventMonths))

# compute concordance index for the low-ADC change each day
mrl.conc.res <- data.frame()
for (event in events.cox){
  for (day.bin in days.bin){
    pred <- paste0('D',day.bin)
    df.conc <- mrl.lowADC %>% filter(!is.na(get(pred)),Event==event)
    conc.idx <- concordance.index(x=as.integer(df.conc[[pred]]),
                                  surv.time=df.conc$TimeToEventMonths,
                                  surv.event=df.conc$Status,
                                  method="noether",
                                  alternative="greater")
    mrl.conc.res <- rbind(mrl.conc.res,data.frame(event=event,
                                                  pred=pred,
                                                  mean=conc.idx$c.index,
                                                  lower=conc.idx$lower,
                                                  upper=conc.idx$upper,
                                                  p.value=conc.idx$p.value,
                                                  n=conc.idx$n))
  }
}
mrl.conc.res <- mrl.conc.res %>% tibble() %>%
  mutate(Day=as.numeric(str_extract(pred,"(?<=D).*"))) %>%
  mutate(p.value.adjusted=p.adjust(p.value,method='holm')) %>%
  mutate(significant = p.value.adjusted<alph) %>%
  mutate(p.value=sapply(p.value,fmt.pval),
         p.value.adjusted=sapply(p.value.adjusted,fmt.pval))
  
write_csv(mrl.conc.res,file.path(dir.work,phase,'concordance_index_mrl.csv'))

# plot the concordance index over time
p.conc.mrl <- mrl.conc.res %>% ggplot(aes(x=Day)) +
  facet_wrap(vars(event),ncol=1) +
  geom_point(aes(y=mean),size=8,shape=shape.codes[1]) +
  geom_errorbar(aes(ymin=lower,ymax=upper),width=2.5,size=1.5) +
  geom_hline(aes(yintercept=0.5),linetype='dashed') +
  scale_color_manual(values=c('#0055FF')) +
  labs(x='Time from first fraction (days)',y='Concordance index') +
  theme(text=element_text(size=36),
        legend.position = "none") +
  scale_x_continuous(labels=seq(0,40,5),breaks=seq(0,40,5)) +
  scale_y_continuous(labels=seq(0,1,0.2), breaks=seq(0,1,0.2), limits=c(0,1.1))
ggsave(file.path(dir.work,phase,'concordance_index_plot.pdf'),
       plot=p.conc.mrl,
       width=8,
       height=12)

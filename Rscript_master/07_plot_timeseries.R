# 07_plot_timeseries
# plots the low-ADC volume timeseries for MRL and MR-sim data, with grouping by response
# also plots the volume change at fraction 10 versus fraction 20 and one-month post-radiotherapy

phase <- 'timeseries'
dir.create(file.path(dir.work,phase),showWarnings=FALSE)
  
# declare dataframe to plot
df.measurements <- df.dyn.interp %>% filter(Event=='Death')

if (verbose){
  # for MOMENTUM patients, plot low-ADC volume per patient, with colouring by scanner
  p.interpMRL <- df.measurements %>%
    filter(Metric=='VolumeLowADC') %>%
    ggplot(aes(x=Day,y=Value,color=Scanner)) +
    geom_point() +
    geom_line(aes(group=interaction(Subject,Scanner)),linetype='dashed') +
    facet_wrap(vars(Subject),scales='free_y') +
    scale_color_manual(values=c('red','blue')) +
    labs(y='Low-ADC volume (cc)') +
    theme(text=element_text(size=16))
  ggsave(file.path(dir.work,phase,'lowADC_momentum_perPatient.pdf'),plot=p.interpMRL,width=22,height=11)
  
  # for MOMENTUM patients, plot low-ADC relative volume change per patient, with colouring by scanner
  p.interpMRL.rel <- df.measurements %>%
    filter(Metric=='VolumeLowADC') %>%
    ggplot(aes(x=Day,y=DeltaPc,color=Scanner)) +
    geom_point() +
    geom_line(aes(group=interaction(Subject,Scanner))) +
    facet_wrap(vars(Subject),scales='free_y') +
    scale_color_manual(values=c('red','blue')) +
    labs(y='Low-ADC volume (cc)') +
    theme(text=element_text(size=16))
  ggsave(file.path(dir.work,phase,'lowADC_deltaPc_momentum_perPatient.pdf'),plot=p.interpMRL.rel,width=22,height=11)
  
  
  # for MOMENTUM patients with both MRL and MR-sim, plot relative change in low-ADC volume, coloured by early/late progression
  p.isearly <- df.dyn.interp %>% filter(Event=='Progression',
                                        Metric=='VolumeLowADC',
                                      !is.na(IsEarly),
                                      (Day>=0)&(Day<=45)) %>%
    ggplot(aes(x=Day,y=DeltaPc,color=IsEarly)) +
    geom_point() +
    geom_line(aes(group=Subject),linetype='dashed') +
    scale_color_manual(values=c('black','grey')) +
    facet_wrap(vars(Scanner),nrow=1,scales='free_y') +
    xlim(0,42) +
    theme(text=element_text(size=24))
  ggsave(file.path(dir.work,phase,'lowADC_momentum_isEarlyProgression.pdf'),plot=p.isearly,width=20,height=9)
  
}

# summarize tumour volume changes
dyn.cor.summary <- df.dyn.cor %>%
  filter(Event=='Death') %>%
  group_by(Region,Timepoint) %>%
  summarise(Median=median(Value,na.rm=TRUE),
            Min=min(Value,na.rm=TRUE),
            Max=max(Value,na.rm=TRUE))
write_csv(dyn.cor.summary,file.path(dir.work,phase,'volume_changes_summary.csv'))

# plot volume changes by early/late for each outcome
shapes.isearly <- c(1,19)
ltypes.isearly <- c('42','solid')
df.pvals.all <- data.frame()
for (event.use in events.cox){  
  df.dyn.cor.earlylate <- df.dyn.cor %>%
    filter(Event==event.use,!is.na(IsEarly))
  regions <- unique(df.dyn.cor.earlylate$Region)
  
  # do Wilcoxon rank-sum test on volume changes between early/late death groups
  df.pvals <- data.frame()
  for (region in regions){
    for (timepoint in scans){
      df.earlylate.subset <- df.dyn.cor.earlylate %>% filter(Timepoint==timepoint,
                                                               Region==region,
                                                               !is.na(Value))
      res.wilcox <- wilcox.test(formula=Value~IsEarly,data=df.earlylate.subset,alternative='less')
      df.pvals <- rbind(df.pvals,data.frame(Region=region,
                                            Timepoint=timepoint,
                                            pVal=res.wilcox$p.value,
                                            n=nrow(df.earlylate.subset)))
    }
  }
  df.pvals <- df.pvals %>% mutate(Outcome=event.use) %>% relocate(Outcome)
  df.pvals.all <- rbind(df.pvals.all, df.pvals)
}
df.pvals.all <- df.pvals.all %>%
  mutate(pValAdjusted=p.adjust(pVal,method='holm')) %>%
  mutate(pVal=sapply(pVal,fmt.pval),
         pValAdjusted=sapply(pValAdjusted,fmt.pval)) %>%
  mutate(Significant=pValAdjusted<alph)
write_csv(df.pvals,file.path(dir.work,phase,'wilcoxon_pvalues_volumeChange_by_earlyLate.csv'))


# plot volume changes versus time with grouping by outcome
for (event.use in events.cox){
  df.pvals <- df.pvals.all %>% filter(Outcome==event.use)
  for (region in regions){
    # extract days for which difference is significant and declare xlimits for geom_signif
    dw <- 10
    days.signif <- left_join(filter(df.pvals,Region==region),fx.day,by='Timepoint') %>% filter(Significant==TRUE) %>% pull(Day)
    xmins <- days.signif-dw/4.0
    xmaxs <- days.signif+dw/4.0
    
    # make plot
    p.isearly.death <- df.dyn.cor.earlylate %>%
      filter(Region==region) %>%
      ggplot(aes(x=Day,y=Value,linetype=IsEarly,group=interaction(Day,IsEarly))) +
      geom_violin(draw_quantiles=c(0.5),lwd=1,position=position_dodge(width=dw),scale='width',width=dw*0.9) +
      geom_point(aes(shape=IsEarly),position=position_jitterdodge(jitter.width=0,dodge.width=dw,seed=0)) +
      scale_color_manual(values=c('#000000','#555555')) +
      scale_shape_manual(values=shapes.isearly) +
      scale_linetype_manual(values=ltypes.isearly) +
      scale_x_continuous(breaks=seq(0,80,20),labels=seq(0,80,20),limits=c(0,80)) +
      ylim(c(-100,110)) +
      theme(text=element_text(size=32)) +
      labs(x='Time from first fraction (days)',y='Volume change (%)',color='Early')
    ggsave(file.path(dir.work,phase,sprintf('%s_momentumAndGlio_isEarly_outcome-%s.eps',region,event.use)),
           plot=p.isearly.death,
           width=9,
           height=7,
           dpi=400)
    
  }
  
}


# histograms of low-ADC and GTV changes -------------------------

if (verbose){
  # create histograms
  p.dyn.cor <- df.dyn.cor %>%
    filter(Event=='Death') %>%
    ggplot(aes(x=Value)) +
    geom_histogram() +
    facet_grid(Region~Timepoint) +
    theme(text=element_text(size=28)) +
    labs(x='Percentage volume change (%)',y='Count')
  ggsave(file.path(dir.work,phase,'histograms_volume_changes.jpg'),
         plot=p.dyn.cor,
         width=17,
         height=9,
         dpi=400)
}


# Make correlation plots of volume changes on different days --------------

df.volcor <- df.cor.all %>% filter(Event=='Death')
roi.prefs <- c('LowADC', 'GTV')
prefs.fancy <- c('Low-ADC', 'GTV')
names(prefs.fancy) <- roi.prefs
x.timepoint <- 'Fx10'
y.timepoints <- c('Fx20', 'P1M')
volcor.coeffs <- data.frame()
for (roi.pref in roi.prefs){
  for (y.timepoint in y.timepoints){
    
    # declare x- and y-variable names
    x.name <- paste0('d', roi.pref, '.', x.timepoint)
    y.name <- paste0('d', roi.pref, '.', y.timepoint)
    
    # compute Pearson correlation coefficient
    tmp.test <- cor.test(formula=as.formula(paste('~', x.name, '+', y.name)), data=df.volcor)
    volcor.coeffs <- rbind(volcor.coeffs, data.frame(
      x=x.name,
      y=y.name,
      r=tmp.test$estimate,
      p.val=tmp.test$p.value,
      df=tmp.test$parameter))
    sink(file.path(dir.work, phase, sprintf('volcor_cortest_%s_%s.txt', x.name, y.name)))
    print(tmp.test)
    sink()

    # create scatterplot
    p.volcor <- df.volcor %>% 
      ggplot(aes(.data[[x.name]], .data[[y.name]])) +
      geom_point(size=2) +
      stat_smooth(method='lm', formula=y~x, color='black', se=FALSE) +
      theme(text=element_text(size=30)) +
      labs(x=sprintf('Change in %s %s (%%)', prefs.fancy[roi.pref], x.timepoint),
           y=sprintf('Change in %s %s (%%)', prefs.fancy[roi.pref], y.timepoint))
    ggsave(file.path(dir.work, phase, sprintf('volcor_%s_vs_%s.pdf', x.name, y.name)),
           plot=p.volcor,
           width=8,
           height=7)
    
  }
}

# adjust p-values
volcor.coeffs <- volcor.coeffs %>% mutate(p.val.adjusted = p.adjust(p.val, method='holm'))

# write correlation coefficients dataframe
volcor.coeffs %>% write_csv(file.path(dir.work, phase, 'volcor_pearson_coeffs.csv'))

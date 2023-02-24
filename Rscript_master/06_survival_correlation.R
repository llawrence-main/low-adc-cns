### 06_survival_correlation
# Survival analysis with Cox models and concordance indices for low-ADC and GTV volume changes

phase <- 'survival'
dir.create(file.path(dir.work,phase),showWarnings=FALSE)

# declare predictors and formulas for Cox modelling
preds.cox <- preds.rank
formulas.cox <- sapply(preds.cox,function(x) as.formula(paste('Surv(TimeToEventMonths,Status) ~ ',x)))

# Kaplan-Meier curves and univariate Cox modelling -----------------------------------------------------------

res.cox <- data.frame()
cols.surv <- c('blue','red')
events.cox <- c('Death','Progression')
for (event in events.cox){
  if (verbose){
    # plot stratified KM curves
    univ.km <- lapply(formulas.cox,function(x) survfit.formula(x,data=df.cor.all,subset=Event==event))
    univ.plots <- lapply(univ.km,function(x) autoplot(x,surv.size=2,conf.int=FALSE)+
                           scale_colour_manual(values=cols.surv) +
                           theme(text=element_text(size=38)) +
                           labs(x='Time from surgery (months)',y='Fraction surviving') +
                           scale_y_continuous(labels=seq(0,1,0.25),limits=c(0,1)) +
                           xlim(0,50))
  
    lapply(preds.cox,function(x) ggsave(filename=file.path(dir.work,phase,sprintf('KM_outcome-%s_predictor-%s.pdf',event,x)),
                                            plot=univ.plots[[x]],
                                            width=14,
                                            height=8))
  }
  
  # do Cox modelling and save results
  models.cox <- lapply(formulas.cox,function(x) coxph(x,data=df.cor.all,subset=Event==event))
  summaries.cox <- lapply(models.cox, function(x) {return(summary(x))})
  dfs.cox <- lapply(summaries.cox,
                    function(x){
                      coefs <- rownames_to_column(as.data.frame(x$coef),var="Predictor") %>% select(-`se(coef)`,-z)
                      c.ints <- as.data.frame(x$conf.int) %>% select(`lower .95`,`upper .95`)
                      .df <- cbind(coefs,c.ints) %>% 
                        tibble() %>% 
                        mutate(N=x$n) %>% 
                        rename(beta=coef,HR=`exp(coef)`,CI.Lower=`lower .95`,CI.Upper=`upper .95`,pVal=`Pr(>|z|)`) %>%
                        relocate(pVal,.before=N) %>%
                        mutate(`95% CI for HR`=sprintf('%f-%f',CI.Lower,CI.Upper)) %>%
                        relocate(`95% CI for HR`,.after=CI.Upper)
                      return(.df)
                    })
  res.tmp <- plyr::rbind.fill(dfs.cox) %>%
    tibble() %>%
    mutate(Outcome=event, .before=Predictor)
  res.cox <- rbind(res.cox,res.tmp)
  
  # do tests of proportional hazards assumption
  tests.ph <- lapply(models.cox,cox.zph)
  
  # create table of p-values for test results from scaled Schoenfeld residuals
  test.pvals <- lapply(preds.cox,function(x) tests.ph[[x]]$table[x,'p'])
  names(test.pvals) <- preds.cox
  df.test.pvals <- t(as.data.frame(test.pvals)) %>%
    as.data.frame() %>%
    rename("p.value"="V1") %>%
    rownames_to_column(var="Predictor")
  write_csv(df.test.pvals,file.path(dir.work,phase,sprintf('Cox_PH_assumption_tests_outcome-%s.csv',event)))
  
  if (verbose){
    # plot scaled Schoenfeld residuals against transformed time
    test.plots <- lapply(tests.ph,
                         function(test.ph){
                           tibble(Time=test.ph$x,Residual=test.ph$y) %>%
                             ggplot(aes(x=Time,y=Residual)) +
                             geom_point() +
                             stat_smooth() +
                             theme(text=element_text(size=20))
                         }
    )
    lapply(preds.cox,function(x) ggsave(filename=file.path(dir.work,phase,sprintf('SchoenfeldResiduals_outcome-%s_predictor-%s.pdf',event,x)),
                                        plot=test.plots[[x]],
                                        width=14,
                                        height=8))
  }
  
}

# declare function to format p-values as strings
fmt.pval <- function(p){
  if (p<0.001){
    res <- '<.001'
  } else {
    res <- sprintf('%.4f',signif(p,2))
    res <- str_replace(res,'0','')
    res <- str_replace(res,'0*$','')
  }
  return(res)
}

# create fancy data frame for table in paper
res.cox.fancy.all <- res.cox %>%
  mutate(pValAdjusted=p.adjust(pVal,method='holm')) %>%
  mutate(Significant=pValAdjusted<alph) %>%
  mutate(pValAdjustedFormatted=sapply(pValAdjusted,fmt.pval),
         pVal=sapply(pVal,fmt.pval)) %>%
  mutate(Significant=pValAdjusted<alph)

res.cox.fancy <- res.cox.fancy.all %>%
  mutate(HR = signif(HR,2), CI.Lower=signif(CI.Lower,2),CI.Upper=signif(CI.Upper,2)) %>% 
  mutate(`95% CI for HR`=sprintf('%s - %s',CI.Lower,CI.Upper)) %>%
  select(Outcome,Predictor,HR,`95% CI for HR`,pVal,pValAdjustedFormatted,Significant,N) %>%
  rename(pValAdjusted=pValAdjustedFormatted)

write_csv(res.cox.fancy,file.path(dir.work,phase,'Cox_stats.csv'))

# Create fancy KM curves --------------------------------------------------

if (create.fancy.km){
  time.steps <- c(5,3)
  names(time.steps) <- events.cox
  for (km.event in events.cox){
    # create list of KM curve objects
    km.list <- list()
    km.list$LowADCFx10 <- survfit.formula(formula=Surv(TimeToEventMonths,Status)~dLowADCRank.Fx10,data=df.cor.all,subset=Event==km.event)
    km.list$GTVFx10 <- survfit.formula(formula=Surv(TimeToEventMonths,Status)~dGTVRank.Fx10,data=df.cor.all,subset=Event==km.event)
    km.list$MGMT <- survfit.formula(formula=Surv(TimeToEventMonths,Status)~MGMTRank,data=df.cor.all,subset=Event==km.event)
    km.list$Resection <- survfit.formula(formula=Surv(TimeToEventMonths,Status)~ResectionRank,data=df.cor.all,subset=Event==km.event)
    km.list$ECOG <- survfit.formula(formula=Surv(TimeToEventMonths,Status)~ECOGRank,data=df.cor.all,subset=Event==km.event)
    
    # plot KM curves with number at risk
    km.names <- names(km.list)
    strata.font.sizes <- c(20,20,15,15)
    n.km <- length(km.names)
    ps.km <- list()
    time.step <- time.steps[km.event]
    for (ix in seq(1,n.km)){
      km.name <- km.names[ix]
      p.km <- ggkm(get(km.name,km.list),
                   timeby=time.step,
                   xlabs='Time from surgery (months)',
                   ylabs='Fraction surviving',
                   main=element_blank(),
                   pval=FALSE,
                   fontsize.axes=24,
                   fontsize.risk=6,
                   fontsize.strata=strata.font.sizes[ix],
                   returns=TRUE)
      ggsave(file=file.path(dir.work,phase,sprintf('fancyKM_outcome-%s_predictor-%s.eps',km.event,km.name)),
             plot=p.km,
             width=8,
             height=6,
             dpi=400)
    }
  }
}


# Create plots for Cox modelling results --------------------------

cox.for.plot <- res.cox.fancy.all %>% filter(!(Predictor %in% preds.clin)) %>%
  mutate(Timepoint=str_extract(Predictor,"Fx[0-9]+|P1M")) %>%
  mutate(Predictor=str_replace(Predictor,'(\\.Fx[0-9]+|\\.P1M)Above','')) %>%
  relocate(Timepoint,.before=Predictor) %>% 
  tibble() %>%
  mutate(Predictor=factor(Predictor,levels=c('dLowADCRank','dGTVRank'))) %>%
  left_join(fx.day,by='Timepoint') %>%
  filter(!is.na(Predictor))
shape.codes <- c(19,17) # circle for low-ADC,triangle for GTV

# create plot of hazard ratios for different time points
p.cox <- cox.for.plot %>%
  ggplot(aes(x=Day,shape=Predictor)) +
  facet_wrap(vars(Outcome),ncol=1) +
  geom_point(aes(y=HR),position=position_dodge(width=6),size=8) + 
  geom_errorbar(aes(ymin=CI.Lower,ymax=CI.Upper),position=position_dodge(width=6),width=5,size=1.5) +
  geom_hline(aes(yintercept=1),linetype='dashed') +
  scale_shape_manual(values=shape.codes) +
  labs(x='Time from first fraction (days)',y='Hazard ratio',fill='Predictor') +
  scale_x_continuous(labels=seq(0,80,10),breaks=seq(0,80,10),limits=c(-2,80)) +
  ylim(0.5, 7.5) +
  theme(text=element_text(size=36),
        panel.grid.major.y = element_line(color='#CCCCCC'),
        panel.grid.minor.y = element_blank(),
        panel.grid.minor.x = element_blank(),
        legend.position = 'none')
ggsave(file.path(dir.work,phase,'Cox_model_hazard_ratios.eps'),
       plot=p.cox,
       width=8,
       height=12,
       dpi=300)

if (verbose){
  # create plot of p-values over time
  p.pvals <- cox.for.plot %>%
    ggplot(aes(x=Day,y=pValAdjusted,shape=Predictor)) + 
    facet_wrap(vars(Outcome),ncol=1) +
    geom_point(position=position_dodge(width=6),size=6) + 
    geom_hline(aes(yintercept=0.05),linetype='dashed') +
    scale_x_continuous(labels=seq(0,80,10),breaks=seq(0,80,10),limits=c(-2,80)) +
    scale_y_continuous(trans="log10") +
    scale_shape_manual(values=shape.codes) + 
    labs(x='Time from first fraction (days)',y='p-value',fill='Predictor') +
    theme(text=element_text(size=28)) +
    theme(text=element_text(size=36),
          panel.grid.major.y = element_line(color='#CCCCCC'),
          panel.grid.minor.y = element_blank(),
          panel.grid.minor.x = element_blank(),
          legend.position = 'none')
  ggsave(file.path(dir.work,phase,'Cox_model_adjusted_pvalue.jpg'),
         plot=p.pvals,
         width=8,
         height=12,
         dpi=400)
}

# Compute concordance indices -----------------------------

# compute concordance index for each predictor
conc.res <- data.frame()
conc.store <- list()
conc.store$Death <- list()
conc.store$Progression <- list()
for (event in events.cox){
  for (pred in preds.cox){
    df.conc <- df.cor.all %>% filter(Event==event) %>%
      filter(!is.na(get(pred)),!is.na(TimeToEventMonths))
    conc.idx <- concordance.index(x=as.integer(df.conc[[pred]]),
                                  surv.time=df.conc$TimeToEventMonths,
                                  surv.event=df.conc$Status,
                                  method="noether",
                                  alternative="greater")
    conc.res <- rbind(conc.res,data.frame(event=event,
                                          pred=pred,
                                          mean=conc.idx$c.index,
                                          lower=conc.idx$lower,
                                          upper=conc.idx$upper,
                                          p.value=conc.idx$p.value,
                                          n=conc.idx$n))
    conc.store[[event]][[pred]] <- conc.idx
  }
}
conc.res <- conc.res %>% 
  tibble() %>% 
  mutate(event=as.character(event),pred=as.character(pred)) %>%
  mutate(p.value.adjusted=p.adjust(p.value,method='holm')) %>%
  mutate(p.value = sapply(p.value,fmt.pval),
         p.value.adjusted=sapply(p.value.adjusted,fmt.pval)) %>%
  mutate(significant = p.value.adjusted<alph)
write_csv(conc.res,file.path(dir.work,phase,'concordance_index_pvals.csv'))

# preprocess for plotting
conc.plot <- conc.res %>% 
  mutate(Timepoint=str_extract(pred,"(?<=\\.).*"),vol=str_extract(pred,".*(?=\\.)")) %>%
  left_join(fx.day,by='Timepoint') %>%
  mutate(vol=factor(vol,levels=c('dLowADCRank','dGTVRank')))

# plot concordance index over time
p.conc <- conc.plot %>% ggplot(aes(x=Day,shape=vol)) +
  facet_wrap(vars(event),ncol=1) +
  geom_point(aes(y=mean),position=position_dodge(width=6),size=8) + 
  geom_errorbar(aes(ymin=lower,ymax=upper),position=position_dodge(width=6),width=5,size=1.5) +
  geom_hline(aes(yintercept=0.5),linetype='dashed') +
  scale_shape_manual(values=shape.codes) +
  labs(x='Time from first fraction (days)',y='Concordance index') +
  theme(text=element_text(size=36),
        legend.position = "none") +
  scale_x_continuous(labels=seq(0,80,10),breaks=seq(0,80,10),limits=c(-2,80)) +
  scale_y_continuous(breaks=seq(0,1,0.1),limits=c(0.45,0.95))
ggsave(file.path(dir.work,phase,'concordance_index_plot.eps'),
       plot=p.conc,
       width=8,
       height=12)


# builds the model for predicting MR-sim ADC values from MR-Linac ADC values
# model is a second-order polynomial that passes through the origin

# libraries
library(tidyverse)
library(polynom)

# options
theme_set(theme_bw())
dir.out <- file.path('results','adc_bias_correction')


# create table of paired scan days ----------------------------------------

# read dataframes of session-date correspondence
timing.sim <- read_csv(file.path('results','metadata','session_day_sim.csv')) %>%
  select(Subject,Session,Date)
timing.mrl <- read_csv(file.path('results','metadata','session_day_mrl.csv')) %>%
  select(Subject,Session,Date)

# join dataframes by subject and date
timing.paired.all <- inner_join(timing.sim,timing.mrl,by=c('Subject','Date'),suffix=c('Sim','MRL')) %>%
  select(Subject,SessionMRL,SessionSim)

# subset to subjects with GLIO contours
dir.glio <- file.path('results','mr_sim','glio_contours')
subjects <- str_replace(list.files(dir.glio),'sub-','')
timing.paired <- timing.paired.all %>% filter(Subject%in%subjects)

# write dataframe
write_csv(timing.paired,file.path(dir.out,'paired_scan_list.csv'))

# create model to predict MR-sim ADC --------------------------------------


# dataframe of median ADC values for MRL and Ingenia
df.adc <- read_csv(file.path(dir.out,'paired_MRL_MRsim_ADCs.csv'),col_types=list(
  col_factor(),
  col_factor(),
  col_factor(),
  col_factor(),
  col_double(),
  col_double()
))

# build model and compute predictions
model.sim <- lm(formula=ValueSim ~ 0 + ValueMRL,data=df.adc)
preds.sim <- predict(model.sim,df.adc)
df.adc <- df.adc %>% mutate(ValueSimPred=preds.sim)

# plot data and model
p.model <- df.adc %>% ggplot(aes(x=ValueMRL,ValueSim)) +
  geom_point() +
  geom_abline(slope=1,intercept=0,color='black',linetype='dashed') +
  geom_line(aes(y=ValueSimPred),color='blue') +
  xlim(0.5,2.75) + 
  ylim(0.5,2.75) +
  theme(text=element_text(size=30))
ggsave(file.path(dir.out,'model_plot.pdf'),plot=p.model,width=7,height=7)

# write model coefficients
model.coefs <- tribble(
  ~Scanner,~p0,~p1,
  'Ingenia',0,model.sim$coefficients['ValueMRL'],
  'Achieva',0,model.sim$coefficients['ValueMRL']
)
write_csv(model.coefs,file.path(dir.out,'model_coeffs.csv'))

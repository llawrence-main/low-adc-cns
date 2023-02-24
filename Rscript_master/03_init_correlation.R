### 03_init_correlation
# initializes survival correlation data

dir.work <- dir.results

# Script options ----------------------------------------------------------

sub.debug <- 'M009' # subject to use for debugging

# Subjects to exclude
subs.exclude <- c('GBM032', # no outcomes
                  'GBM073', # no outcomes
                  'M125') # lost to follow-up before any follow-up MRI
subs.exclude.dyn <- c('M108', # only one MR-Linac scan with DWI
                      'M098') # baseline low-ADC < 1cc

# plotting
theme_set(theme_bw())

# days to assign to fraction time points
fx.day <- tribble(
  ~Timepoint,~Day,
  'Fx0',-7,
  'Fx10',14,
  'Fx20',28,
  'P1M',70
)

# declare significance threshold
alph <- 0.05
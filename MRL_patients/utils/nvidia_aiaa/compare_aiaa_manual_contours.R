# library
library(tidyverse)

# set options
theme_set(theme_bw())

# create output directory

#work.dir <- file.path('results','20211213_dice_contours')
work.dir <- file.path('results','20211215_dice_contours')
dir.create(work.dir,showWarnings=FALSE)

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

# compute medians
dice.medians <- dice %>% group_by(Contour1,Contour2) %>% 
  summarise(MedianDice=median(Dice)) %>% 
  ungroup()

# plot Dice scores for manual GTV and tumour core, histogram with all data pooled
contour1 <- 'manual.GTV'
contour2 <- 'aiaa.tumourcore'
p.hist <- dice %>% filter(Contour1==contour1,Contour2==contour2) %>%
  ggplot(aes(x=Dice)) + 
  geom_histogram(bins=20) +
  geom_vline(data=dice.medians%>%filter(Contour1==contour1,Contour2==contour2),mapping=(aes(xintercept=MedianDice)),color='red') +
  theme(text=element_text(size=28)) +
  xlim(0,1.05)
ggsave(file.path(work.dir,sprintf('dice_%s_%s_histogram.pdf',contour1,contour2)),
       plot=p.hist,
       width=8.5,
       height=7)

# plot Dice score for manual GTV and tumourcore, per patient
p.perpatient <- dice %>% filter(Contour1==contour1,Contour2==contour2) %>%
  ggplot(aes(x=Subject,y=Dice)) +
  geom_point() +
  geom_line(aes(group=Subject)) +
  theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust=1, size = 16),
        axis.text.y = element_text(size=16),
        text = element_text(size=20)) +
  ylim(0,1)
ggsave(file.path(work.dir,sprintf('dice_%s_%s_perpatient.pdf',contour1,contour2)),
       plot=p.perpatient,
       width=20,
       height=9)

# plot difference in Dice scores between GTV-tumourcore and GTV-wholetumour
dice.wt.tc <- dice %>% filter(Contour1=='manual.GTV') %>%
  pivot_wider(names_from='Contour2',values_from='Dice') %>%
  mutate(DiceDiff=aiaa.tumourcore-aiaa.wholetumour)
p.wt.tc <- dice.wt.tc %>% ggplot(aes(x=DiceDiff)) + 
  geom_histogram(bins=20) +
  theme(text=element_text(size=28)) +
  labs(x='Tumour core - whole tumour',y='Count',title='Dice with GTV')
ggsave(file.path(work.dir,'dice_tc_minus_wt.pdf'),
       plot=p.wt.tc,
       width=8,
       height=7)

# plot Dice for GTV of the day versus Dice for GTV at planning
dice.plan <- dice %>% 
  pivot_wider(names_from=c('Contour1','Contour2'),values_from='Dice') %>%
  filter(!(Session == 'GLIO01'))
xs <- c('manual.GTV.plan_aiaa.tumourcore','manual.GTV.plan_aiaa.wholetumour')
ys <- c('manual.GTV_aiaa.tumourcore','manual.GTV_aiaa.wholetumour')
for (x in xs){
  for (y in ys){
    p.plan <- dice.plan %>% ggplot(aes_string(x=x,y=y)) +
      geom_point() +
      xlim(0,1) +
      ylim(0,1) +
      theme(text=element_text(size=20))
    ggsave(file.path(work.dir,sprintf('dice_%s_vs_%s.pdf',x,y)),
           plot=p.plan,
           width=10,
           height=8)
  }
}


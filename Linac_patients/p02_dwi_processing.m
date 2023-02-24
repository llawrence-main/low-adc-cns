%% clear
clc
clear all
close all

%% script options
test_one = false;

%% add paths
addpath(genpath('utils'));

%% declare parameters
root = '..';

%% get list of subjects
if test_one
    subjects = {'GBM052'};
else
    subjects = get_subjects(root);
end

%% fit ADC maps
fit_adc_maps(root,subjects);

%% create low-ADC regions
create_low_adc_all(root,subjects);

%% create table of low-ADC volumes
create_low_adc_table(root,subjects);

%% list missing files
list_missing(root,subjects);

%% create verification figures
create_verification_figures(root,subjects);

%% create ImNO 2022 figures
create_imno_2022_figures(root,true);

%% create comparison figure of enclosing ROIs
fig_dir = fullfile(root,'results','20211201_enclosing_roi_comparison');
create_enclosing_roi_comparison_figure(root,fig_dir);

%% compute Dice coefficient

cont1 = struct;
cont1.source = 'manual';
cont1.labels = {'GTV'};

cont2 = struct;
cont2.source = 'aiaa';
cont2.labels = {'tumourcore','wholetumour'};

compute_dice_contour_sources(root,subjects,cont1,cont2,...
    'IncludePlan',true,...
    'UseCoreg',true);
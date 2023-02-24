%% Clear
clc
clear all
close all

%% Declare parameters

% script options
overwrite = 0;
test_one = 0;

% directories
work_dir = '/home/llawrence/Documents/repositories/dwi_response';

% subjects used in dwi_response analysis (GBM, with GLIO study T1c contours)
subjects = get_subject_list(work_dir);
if test_one    
    subjects = {'M125'};
end

% all high-grade glioma subjects
subjects_all = get_subject_list_all(work_dir);
% fits ADC maps for all high-grade glioma subjects so that the maps can be
% used in other projects

%% Fit ADC to co-registered MRL DWI
do_mrl_adc_fitting(work_dir,subjects_all); 

%% Compute trace image from MR-sim DWI
trace_image_sim(work_dir,subjects_all);

%% Fit ADC to co-registered MR-sim DWI
do_sim_adc_fitting(work_dir,subjects_all);

%% Create ROIs from quantitative MRI
create_qmri_rois(work_dir,subjects);

%% Create volume dynamics table
force = {'M125_MRL017'};
force_subjects = {};
create_volume_dynamics_table(work_dir,subjects,force,...
    'ADCType','original',...
    'ForceSubjects',force_subjects);
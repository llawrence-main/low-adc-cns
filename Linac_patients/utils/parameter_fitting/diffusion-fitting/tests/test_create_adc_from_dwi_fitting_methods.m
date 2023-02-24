%% Clear
clc
clear all
close all

%% Declare parameters

% commit
com = '8825ce4';

% filenames
folder = '/scratch/llawrence/diffusion-fitting/testdata_adc';
dwi_filename = fullfile(folder,'sub-M020_ses-MRL001_run-01_dwi_coreg.nii.gz');
mask_filename = fullfile(folder,'sub-M020_ses-sim003_acq-fatsat_T1w_brain_mask.nii.gz');

% b-values
all_bvals = [0:10:50,75,100,200,400,800];
bval_indices = [false(1,7),true(1,4)];
nsa = [4,1,1,1,1,1,1,1,2,3,8];

% resolution
res = [2,2.18,5];

% methods
methods = {'LLS','WLLS','WLLS2'};
n_methods = length(methods);

%% Fit ADC using all methods and save
for ix = 1:n_methods
    method = methods{ix};
    fprintf('testing ADC fit method: %s\n',method);
    adc_filename = fullfile(folder,com,['adc_map_',method,'.nii.gz']);
    create_adc_from_dwi(dwi_filename,all_bvals,bval_indices,adc_filename,...
        'ResampleResolution',res,...
        'MaskPath',mask_filename,...
        'Method',method,...
        'Averages',nsa);
end
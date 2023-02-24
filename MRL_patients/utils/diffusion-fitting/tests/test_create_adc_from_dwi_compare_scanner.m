%% Clear
clc
clear all
close all

%% Copy files to working directory

work = fullfile('tests','work');
if ~exist(work,'dir')
    mkdir(work);
end

parent = '/laudata/llawrence/diffusion-fitting-test';
fn_dwi = fullfile(parent,'nii','401_DWI_prebeam_4min40s_11b_maxb800.nii.gz');
fn_adc = fullfile(parent,'nii','404_dADC.nii.gz');

copyfile(fn_dwi,fullfile(work,'dwi.nii.gz'));
copyfile(strrep(fn_dwi,'.nii.gz','.bval'),fullfile(work,'dwi.bval'));
copyfile(fn_adc,fullfile(work,'adc_scanner.nii.gz'));

copyfile(fullfile(parent,'hdbet','t1_mask.nii.gz'),fullfile(work,'brain_mask.nii.gz'));

%% Read b-values
all_bvals = dlmread(fullfile(work,'dwi.bval'));
bval_indices = true(1,numel(all_bvals));

%% Fit ADC and save volume
fn_adc_fitted = fullfile(work,'adc_fitted.nii.gz');
create_adc_from_dwi(fn_dwi,all_bvals,bval_indices,fn_adc_fitted,...
    'Method','LLS',...
    'MaskPath',fullfile(work,'brain_mask.nii.gz'));
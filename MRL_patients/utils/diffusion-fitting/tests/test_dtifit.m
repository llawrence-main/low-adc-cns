%% Clear
clc
clear all
close all

%% Declare directories
work_dir = '/scratch/llawrence/phantom/20210401_DTI';
dti_name = '401_WIP_DTI_fsl_eddy_maxb500';
bvals_filename = fullfile(work_dir,'nii',[dti_name,'.bval']);
bvecs_filename = fullfile(work_dir,'nii',[dti_name,'.bvec']);
dti_filename = fullfile(work_dir,'topup',[dti_name,'_resampled.nii.gz']);
out_filebase = fullfile(work_dir,'dti',[dti_name,'_resampled_inhouse']);
mask_filename = fullfile(work_dir,'topup','phantom_mask.nii.gz');

%% Call dtifit
dtifit(bvals_filename,bvecs_filename,dti_filename,out_filebase,...
    'Mask',mask_filename);
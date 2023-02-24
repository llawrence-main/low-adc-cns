%% clear
clc
clear all
close all

%% create nifti

% create ROI
img = false(100,100,100);
c = 50;
w = 10;
img(c-w:c+w,c-w:c+w,c-w:c+w) = true;
nii = nii_tool('init',uint8(img));

% declare pixel dimensions
nii.hdr.pixdim(2:4) = [1,2,5];

% write nifti
fn_nii = 'test_roi.nii.gz';
nii_tool('save',nii,fn_nii);

%% call compute_roi_volume
vol = compute_roi_volume(fn_nii);
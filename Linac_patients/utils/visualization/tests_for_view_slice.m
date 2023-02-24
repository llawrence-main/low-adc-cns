%% Clear
clc
clear all
close all

%% Declare path to files
fname_t1w = fullfile('/laudata/alau/data/MRL/bids-cns-mrl/dataset-mrl/sub-M001/ses-MRL001/anat',...
    'sub-M001_ses-MRL001_T1w.nii.gz');
assert(exist(fname_t1w,'file')>0,'Not a file: %s\n',fname_t1w);
fname_gtv = fullfile('/laudata/llawrence','longitudinal_mrl','results','longitudinal_dwi','contours',...
    'sub-M001','ses-MRL001',...
    'rGTV.nii.gz');
assert(exist(fname_gtv,'file')>0,'Not a file: %s\n',fname_gtv);
fname_adc = fullfile('/laudata/llawrence','longitudinal_mrl','results','longitudinal_dwi','adc',...
    'sub-M001','ses-MRL003',...
    'rsub-M001_ses-MRL003_adc.nii.gz');
assert(exist(fname_adc,'file')>0,'Not a file: %s\n',fname_adc);

%% Load NIfTIs
nii_t1w = nii_tool('load',fname_t1w);
nii_gtv = nii_tool('load',fname_gtv);
nii_adc = nii_tool('load',fname_adc);

%% View a single axial slice
s = 100;
test = 'no orientation';
args = {nii_t1w};
test_view_slice(test,args,0);

test = 'invalid orientation';
args = {nii_t1w,'foo'};
test_view_slice(test,args,0);

test = 'no slice number';
args = {nii_t1w,'axial'};
test_view_slice(test,args,0);
    
test = 'proper call with nii';
args = {nii_t1w,'axial',s};
test_view_slice(test,args,1);

test = 'proper call with matrix';
args = {nii_t1w.img(:,:,s)};
test_view_slice(test,args,1);

%% View sagittal and coronal slices
s = size(nii_t1w.img,1)/2;
test = 'view sagittal';
args = {nii_t1w,'sagittal',s};
test_view_slice(test,args,1);

test = 'view coronal';
args = {nii_t1w,'coronal',s};
test_view_slice(test,args,1);

%% View contours on single axial slice
s = 64;
test = 'GTV contour on axial slice, nifti';
args = {nii_t1w,'axial',s,'Contours',nii_gtv};
test_view_slice(test,args,s);

test = 'GTV contour on axial slice, volume';
args = {nii_t1w,'axial',s,'Contours',nii_gtv.img};
test_view_slice(test,args,s);

%% View contours on single axial slice with colour wash
s = 64;
test = 'GTV contour on axial slice, nifti';
args = {nii_t1w,'axial',s,'Contours',nii_gtv,'ContourStyle','wash','WashAlpha',0.2};
test_view_slice(test,args,s);
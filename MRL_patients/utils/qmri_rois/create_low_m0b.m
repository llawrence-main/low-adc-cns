function [nii_out,nii_m0b,params] = create_low_m0b(fn_m0b,fn_bound)
% create the low-M0b ROI
% Arguments
%     fn_m0b: filename of M0b nifti
%     fn_bound: filename of ROI that defines boundary of low-M0b ROI
% Returns
%     nii_out: nifti for low-M0b ROI
%     nii_qmt: nifti for qMT
%     params: parameters used in calculation of ROI

% declare parameters
vx_qmt = [2.5,2.5,5];
m0b_thresh = 0.05;

% xform M0b map to acquisition dimensions
nii_m0b = nii_xform(fn_m0b,vx_qmt);
m0b = double(nii_m0b.img)*nii_m0b.hdr.scl_slope+nii_m0b.hdr.scl_inter;
m0b(m0b<1e-9) = NaN; % remove zero values outside of the 3 slices

% load boundary ROI in space of M0b
nii_bound = nii_xform(fn_bound,nii_m0b);
bound = nii_bound.img>0.9;

% define M0b ROI by thresholding M0b map, taking largest connected
% component, and intersecting with boundary ROI
roi = (m0b < m0b_thresh)&bound;
roi = largest_cc(roi);
nii_out = nii_tool('init',uint8(roi));
nii_out.hdr = nii_m0b.hdr;
nii_out.hdr.scl_slope = 1;
nii_out.hdr.scl_inter = 0;

% declare output structure
params = struct;
params.m0b_thresh = m0b_thresh;

end
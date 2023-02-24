function nii_out = create_m0b_adc_cmb(fn_adc,fn_m0b,fn_bound,adc_thresh,m0b_thresh)
% creates the combined ADC-M0b ROI
% Arguments
%     fn_adc: filename of ADC nifti
%     fn_m0b: filename of M0b nifti
%     fn_bound: filename of boundary ROI
%     adc_thresh: threshold for ADC map
%     m0b_thresh: threshold for M0b map
% Returns
%     nii_out: low-M0b-low-ADC ROI

% declare parameters
vx_qmt = [2.5,2.5,5];

% xform M0b to acquition dimensions
nii_m0b = nii_xform(fn_m0b,vx_qmt);
m0b = double(nii_m0b.img)*nii_m0b.hdr.scl_slope+nii_m0b.hdr.scl_inter;
m0b(m0b<1e-9) = NaN; % remove zero values outside of the 3 slices

% xform ADC to M0b space
nii_adc = nii_xform(fn_adc,nii_m0b);
adc = double(nii_adc.img)*nii_adc.hdr.scl_slope+nii_adc.hdr.scl_inter;

% load boundary ROI in space of M0b
nii_bound = nii_xform(fn_bound,nii_m0b);
bound = nii_bound.img>0.9;

% define ROI by thresholding M0b and ADC, taking largest connected
% component and intersecting with boundary ROI
roi = (m0b < m0b_thresh)&(adc < adc_thresh)&bound;
roi = largest_cc(roi);
nii_out = nii_tool('init',uint8(roi));
nii_out.hdr = nii_m0b.hdr;
nii_out.hdr.scl_slope = 1;
nii_out.hdr.scl_inter = 0;
            
end
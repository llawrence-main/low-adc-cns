function [nii_out,params] = create_low_adc(fn_adc,fn_bound)
% create the low-ADC ROI
% Arguments
%     fn_adc: filename of ADC nifti
%     fn_bound: filename of ROI that defines boundary of low-ADC ROI, can
%     also be a cell array to account for multifocal tumour
% Returns
%     nii_out: nifti for low-ADC ROI
%     params: parameters used in calculation of ROI
% Notes
%     - if cell array for fn_bound passed, a low-ADC region is created for
%     each ROI and the union is returned

% declare parameters
adc_thresh = 1.25;

if iscell(fn_bound)
    % recursive case
    niis = cellfun(@(x)create_low_adc(fn_adc,x),fn_bound,'UniformOutput',false);
    nii_out = niis{1};
    for ix = 2:numel(fn_bound)
        nii_out.img = nii_out.img | niis{ix}.img;
    end
    nii_out.img = uint8(nii_out.img);
else   
    % base case
    
    % load ADC map
    nii_adc = nii_tool('load',fn_adc);
    adc = double(nii_adc.img)*nii_adc.hdr.scl_slope+nii_adc.hdr.scl_inter;
    
    % load boundary ROI
    nii_bound = nii_xform(fn_bound,nii_adc);
    bound = nii_bound.img>0.9;
    
    % define ROI by thresholding ADC map and intersecting with boundary ROI
    roi = (adc < adc_thresh)&bound;    
    nii_out = nii_tool('init',uint8(roi));
    nii_out.hdr = nii_adc.hdr;
    nii_out.hdr.scl_slope = 1;
    nii_out.hdr.scl_inter = 0;
    
end
    
% create parameters structure
params = struct;
params.FilenameADC = fn_adc;
params.FilenameBoundaryROI = fn_bound;
params.ADCThreshold = 1.25;

end

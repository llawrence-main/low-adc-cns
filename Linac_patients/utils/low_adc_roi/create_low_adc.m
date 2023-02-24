function create_low_adc(fn_adc,fn_bound,adc_thresh,fn_out,overwrite)
% creates low-ADC ROIs
% Args:
%     fn_adc (str): filename of ADC nifti
%     fn_bound (str): filename of ROI that defines boundary of low-ADC ROI
%     adc_thresh (vector): list of upper threshold values
%     fn_out (str): filename of output
%     overwrite (bool): overwrite existing file?

if exist(fn_out,'file')&&~overwrite
    
    fprintf('Low-ADC ROI nifti already exists: %s\n',fn_out);
    
else

    % load ADC map
    nii_adc = nii_tool('load',fn_adc);
    adc = double(nii_adc.img)*nii_adc.hdr.scl_slope+nii_adc.hdr.scl_inter;
    
    % load boundary ROI
    nii_bound = nii_xform(fn_bound,nii_adc);
    bound = nii_bound.img>0.9;
    
    % define ROI by thresholding ADC map and intersecting with boundary ROI
    n_roi = numel(adc_thresh);
    sz_adc = size(adc);
    rois = false([sz_adc,n_roi]);
    for ix = 1:n_roi
        roi = (adc < adc_thresh(ix))&bound;        
        rois(:,:,:,ix) = roi;
    end
    
    % put ROIs into nifti
    nii_out = nii_tool('init',uint8(rois));
    nii_out.hdr = nii_adc.hdr;
    nii_out.hdr.scl_slope = 1;
    nii_out.hdr.scl_inter = 0;
    
    % save nifti
    out_dir = fileparts(fn_out);
    if ~exist(out_dir,'dir')
        mkdir(out_dir);
    end
    nii_tool('save',nii_out,fn_out);
    fprintf('Low-ADC ROI volume saved: %s\n',fn_out);
    
    % create BIDS .json sidecar
    fn_json = strrep(fn_out,'.nii.gz','.json');    
    fn_rel = bids_relative(fn_adc,0);
    data = struct;    
    data.Sources = {fn_rel};
    create_json(fn_json,data);    
    
    % create .tsv for ADC thresholds used
    fn_tsv = strrep(fn_out,'.nii.gz','.thresh');
    create_tsv(fn_tsv,adc_thresh);
    
end

end



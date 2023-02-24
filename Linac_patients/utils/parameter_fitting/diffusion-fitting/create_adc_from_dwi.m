function create_adc_from_dwi(dwi_path,all_bvals,bval_indices,output_path,varargin)
%CREATE_ADC_FROM_DWI Create an ADC map from DWI
% Arguments:
%     dwi_path: filename of DWI
%     all_bvals: all b-values of the DWI
%     bval_indices: logical array indicating which b-values to use in fit
%     output_path: filename of ADC volume to save
%
% Parameters
%     'NaNBadFits': (default=true) where the set fits yielding
%     non-physical parameter values to NaN
%     'ResampleResolution': (default=[]) if nonempty, will
%     resample the DWI to the given voxel size
%     'MaskPath': (default='') if nonempty, will only fit ADC to
%     voxels within the mask
%     'Method': (default='LLS') method for ADC fit. Options are
%     'LLS' (linear least-squares), 'WLLS' (weighted linear least-squares),
%     and 'WLLS2' (two-step WLLS).
%     'Averages': (default=ones) number of averages at each
%     b-value. Used only if 'Method' is 'WLLS'.
%     'BIDSjson': (default=false) if true, will create .json sidecar with
%     fitting info
%
% Returns: N/A

% Parse inputs
p = inputParser;
addParameter(p,'NaNBadFits',true);
addParameter(p,'ResampleResolution',[]);
addParameter(p,'MaskPath','');
addParameter(p,'Method','LLS');
addParameter(p,'Averages',[]);
addParameter(p,'BIDSjson',false);
parse(p,varargin{:});
vox_dim = p.Results.ResampleResolution;
mask_path = p.Results.MaskPath;
nsa = p.Results.Averages;
method = p.Results.Method;
bids_json = p.Results.BIDSjson;

% Check inputs
assert(exist(dwi_path,'file')>0,'the DWI file does not exist');
assert(length(all_bvals)==length(bval_indices),'all_bvals and bval_indices are not the same length.');
assert(isempty(nsa)||(length(all_bvals)==length(nsa)),'all_bvals and number of averages are not the same length');
hdr_dwi = nii_tool('hdr',dwi_path);
assert(hdr_dwi.dim(5)==length(all_bvals),'the length of all_bvals and the number of volumes in the DWI are not equal');
out_dir = fileparts(output_path);
assert(exist(out_dir,'dir')>0,'the output directory does not exist');

% Load DWI or resample
if isempty(vox_dim)
    nii_dwi = nii_tool('load',dwi_path);
else
    nii_dwi = nii_xform(dwi_path,vox_dim);
end

% Subset b-values and averages
bvals = all_bvals(bval_indices);
nb = length(bvals);
if ~isempty(nsa)
    nsa = nsa(bval_indices);
end

% Resample mask to DWI
if isempty(mask_path)
    mask = true(nii_dwi.hdr.dim(2:4));
else
    nii_mask = nii_xform(mask_path,nii_dwi);
    mask = nii_mask.img>0.9;
end

% Scale DWI and subset volumes
dwi = double(nii_dwi.img(:,:,:,bval_indices))*nii_dwi.hdr.scl_slope+nii_dwi.hdr.scl_inter;
dwi_size = size(dwi);

% Reshape DWI for call to do_fit_adc
sig = permute(dwi,[4,1,2,3]);
sig = reshape(sig,nb,[]);

% Do the fits
fits = do_fit_adc(bvals,sig(:,mask(:)),...
    'NaNBadFits',p.Results.NaNBadFits,...
    'Averages',nsa,...
    'Method',method);

% Store and shape ADC map
num_vox = size(sig,2);
adc = NaN(1,num_vox);
adc(mask(:)) = fits.D;
adc = reshape(adc,dwi_size(1:3));

% Save ADC
nii_adc = struct;
nii_adc.hdr = nii_dwi.hdr;
nii_adc.hdr.scl_slope = 1;
nii_adc.hdr.scl_inter = 0;
nii_adc.hdr.dim(1) = 3;
nii_adc.hdr.dim(5) = 1;
nii_adc.img = adc*1e3; % Save in units of um^2/ms
nii_tool('save',nii_adc,output_path);

if bids_json
    % create BIDS .json sidecar
    fn_json = strrep(output_path,'.nii.gz','.json');
    info = struct;
    info.Source = dwi_path;
    info.FitBValues = bvals;
    info.FitMethod = method;
    spm_jsonwrite(fn_json,info);
end

end
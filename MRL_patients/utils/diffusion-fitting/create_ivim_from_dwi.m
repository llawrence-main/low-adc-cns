function create_ivim_from_dwi(dwi_path,all_bvals,bval_indices,b_thresh,output_base,varargin)
%Create IVIM maps from DWI
% Arguments:
%     dwi_path: filename of DWI
%     all_bvals: all b-values of the DWI
%     bval_indices: logical array indicating which b-values to use in fit
%     b_thresh: threshold b-value for omitting perfusion effects
%     output_base: base filename to save IVIM D and f maps
% Parameters
%     'NaNBadFits': (default=true) where the set fits yielding
%     non-physical parameter values to NaN
%     'ResampleResolution': (default=[]) if nonempty, will
%     resample the DWI to the given voxel size
%     'MaskPath': (default='') if nonempty, will only fit to
%     voxels within the mask
%     'Method': (default='LLS') method for ADC fit. Options are
%     'LLS' (linear least-squares), 'WLLS' (weighted linear least-squares),
%     and 'WLLS2' (two-step WLLS).
%     'Averages': (default=ones) number of averages at each
%     b-value. Used only if 'Method' is 'WLLS'.

% Parse inputs
p = inputParser;
addParameter(p,'NaNBadFits',true);
addParameter(p,'ResampleResolution',[]);
addParameter(p,'MaskPath','');
addParameter(p,'Method','LLS');
addParameter(p,'Averages',[]);
parse(p,varargin{:});
vox_dim = p.Results.ResampleResolution;
mask_path = p.Results.MaskPath;
nsa = p.Results.Averages;

% Check inputs
assert(exist(dwi_path,'file')>0,'the DWI file does not exist');
assert(length(all_bvals)==length(bval_indices),'all_bvals and bval_indices are not the same length.');
assert(isempty(nsa)||(length(all_bvals)==length(nsa)),'all_bvals and number of averages are not the same length');
hdr_dwi = nii_tool('hdr',dwi_path);
assert(hdr_dwi.dim(5)==length(all_bvals),'the length of all_bvals and the number of volumes in the DWI are not equal');
if ~isempty(mask_path)
    hdr_mask = nii_tool('hdr',mask_path);
    assert(all(hdr_mask.dim(2:4)==hdr_dwi.dim(2:4)),'the spatial dimensions of the mask and the DWI are not equal');
end
out_dir = fileparts(output_base);
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

% Reshape DWI for call to fitting function
sig = permute(dwi,[4,1,2,3]);
sig = reshape(sig,nb,[]);

% Do the fits
fits = do_fit_ivim_fD(bvals,b_thresh,sig(:,mask(:)),...
    'NaNBadFits',p.Results.NaNBadFits,...
    'Averages',nsa,...
    'Method',p.Results.Method);

% Store and shape D and f maps
num_vox = size(sig,2);
params = {'f','D'};
for ix_p = 1:numel(params)
    param = params{ix_p};    
    map = NaN(1,num_vox);
    map(mask(:)) = fits.(param);
    map = reshape(map,dwi_size(1:3));
    
    nii_map = struct;
    nii_map.hdr = nii_dwi.hdr;
    nii_map.hdr.scl_slope = 1;
    nii_map.hdr.scl_inter = 0;
    nii_map.hdr.dim(1) = 3;
    nii_map.hdr.dim(5) = 1;
    if strcmp(param,'D')
        nii_map.img = map*1e3; % Save in units of um^2/ms
    else
        nii_map.img = map;
    end
    nii_tool('save',nii_map,strcat(output_base,'_',param,'.nii.gz'));    
end

end
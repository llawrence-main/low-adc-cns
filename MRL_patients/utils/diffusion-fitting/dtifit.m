function dtifit(bval_filename,bvec_filename,dti_filename,out_filebase,varargin)
%DTIFIT Fit diffusion tensor model to diffusion MRI data and save volumes
%as NIfTIs.
%     DTIFIT(BVAL_FILENAME,BVEC_FILENAME,DTI_FILENAME,OUT_FILEBASE) fits
%     a diffusion tensor model using the b-values and directions in
%     BVAL_FILENAME and BVEC_FILENAME and the diffusion data in
%     DTI_FILENAME and saves maps of the eigenvalues/eigenvectors, mean
%     diffusivity, fractional anisotropy, and b=0 signal, appending
%     appropriate suffixes to OUT_FILEBASE. The fit is done using linear
%     least squares.
%
%     DTIFIT(...,'MASK',MASK_FILENAME) resamples the mask in MASK_FILENAME
%     to the DTI dimensions and only fits to voxels labelled TRUE.
% 
%     DTIFIT(...,'GradientTensor',GT_FILENAME) loads the gradient tensor
%     stored in the NIfTI GT_FILENAME and corrects the b-vector at each
%     voxel before fitting

% Input parser
iparser = inputParser;
addParameter(iparser,'Mask','');
addParameter(iparser,'GradientTensor','');
parse(iparser,varargin{:});
mask_filename = iparser.Results.Mask;
gt_filename = iparser.Results.GradientTensor;
varargs_dtifit = {}; % variable arguments for DTI fitting

% Load b-values and b-vectors
bvals = dlmread(bval_filename);
bvecs = dlmread(bvec_filename);

% Load DTI
nii_dti = nii_tool('load',dti_filename);
dti = double(nii_dti.img)*nii_dti.hdr.scl_slope+nii_dti.hdr.scl_inter;

% Check inputs
assert(length(bvals)==size(bvecs,2),'The number of b-values and directions must be the same.');
assert(length(bvals)==size(dti,4),'The number of b-values and diffusion acquisitions must be the same.');

% Reshape DTI data
sz_dti = size(dti);
n_bvals = sz_dti(4);
dti = reshape(permute(dti,[4,1,2,3]),n_bvals,[]);
n_vox = size(dti,2);

% Resample mask to DTI if function called with mask filename
if isempty(mask_filename)
    mask = true(1,n_vox);
else
    assert(exist(mask_filename,'file')>0,'Mask file does not exist.');
    nii_mask = nii_xform(mask_filename,nii_dti,'','nearest',0);
    mask = logical(nii_mask.img(:));
end

% Load gradient tensor if function called with filename
if ~isempty(gt_filename)
    assert(exist(gt_filename,'file')>0,'Gradient tensor file does not exist.');
    nii_L = nii_tool('load',gt_filename);
    L = (double(nii_L.img))*nii_L.hdr.scl_slope+nii_L.hdr.scl_inter;
    sz_L = size(L);
    assert(sz_L(4)==9,'Gradient tensor fourth dimension must be 9.');
    assert(all(sz_L(1:3)==nii_dti.hdr.dim(2:4)),'Gradient tensor must have the same spatial dimensions as the DTI volume.');
    L = reshape(permute(L,[4,1,2,3]),9,[]);
    L = reshape(L,[3,3,n_vox]);
    L = L(:,:,mask);
    varargs_dtifit = [varargs_dtifit,{'GradientTensor',L}];
end

% Fit diffusion tensors
fit = do_fit_dti(bvals,bvecs,dti(:,mask),varargs_dtifit{:});

% Compute metrics from diffusion tensors and store in structure
maps = struct;
maps.S0 = NaN(1,n_vox);
maps.S0(mask) = fit.S0;
V_fieldnames = {'V1','V2','V3'};
L_fieldnames = {'L1','L2','L3'};
for ix = 1:3
    maps.(V_fieldnames{ix}) = NaN(3,n_vox);
    maps.(L_fieldnames{ix}) = NaN(1,n_vox);
end
maps.MD = NaN(1,n_vox);
maps.FA = NaN(1,n_vox);
vox_inds = find(mask);
for ix_mask = 1:nnz(mask)
    ix_vox = vox_inds(ix_mask);
    try
        [V,Lambda] = eig(fit.D(:,:,ix_mask));
    catch ME
        if strcmp(ME.identifier,'MATLAB:eig:matrixWithNaNInf')
            V = NaN(3,3);
            Lambda = NaN(3,3);
        else
            rethrow(ME);
        end
    end
    [L,I] = sort(diag(Lambda),'descend');
    V = V(:,I);
    for jx = 1:3
        maps.(V_fieldnames{jx})(:,ix_vox) = V(:,jx);
        maps.(L_fieldnames{jx})(:,ix_vox) = L(jx);
    end
    maps.MD(ix_vox) = mean(L);
    maps.FA(ix_vox) = sqrt(1/2)*sqrt(((L(1)-L(2))^2+(L(2)-L(3))^2+(L(3)-L(1))^2)/(sum(L.^2)));    
end

% Reshape metrics into volumes
maps.S0 = reshape(maps.S0,sz_dti(1:3));
for ix = 1:3
    maps.(V_fieldnames{ix}) = reshape(maps.(V_fieldnames{ix})',[sz_dti(1:3),3]);
    maps.(L_fieldnames{ix}) = reshape(maps.(L_fieldnames{ix}),sz_dti(1:3));
end
maps.MD = reshape(maps.MD,sz_dti(1:3));
maps.FA = reshape(maps.FA,sz_dti(1:3));

% Save maps
maps2nii(maps,nii_dti,[out_filebase,'_dti']);
end
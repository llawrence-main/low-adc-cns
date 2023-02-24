function [hd,nii_out,out] = compute_hausdorff_nii(fn1,fn2,varargin)
% Returns the directed Hausdorff distance from one ROI to another
% (fn1->fn2)
% Arguments
%     fn1: filename of first ROI
%     fn2: filename of second ROI
% Returns
%     hd: Hausdorff distance
%     nii_out: nifti in which true voxels are those used for Hausdorff distance calculation
%     out: debugging structure

% parse inputs
p = inputParser;
addParameter(p,'xform',false);
parse(p,varargin{:});
xform = p.Results.xform;

% load ROIs
nii1 = nii_tool('load',fn1);
if xform   
    nii2 = nii_xform(fn2,fn1);    
else
    nii2 = nii_tool('load',fn2);    
end
roi1 = nii1.img>0.5;
roi2 = nii2.img>0.5;
assert(all(size(roi1)==size(roi2)),'The two ROIs are not the same size');

% declare parameters
vox_dim = nii1.hdr.pixdim(2:4);

% compute directed Hausdorff distance of largest connected components
rois = {roi1,roi2};
n_rois = length(rois);
point_sets = cell(1,n_rois);
ind_sets = cell(1,n_rois);
for idx = 1:n_rois    
    inds = find(rois{idx});
    [row,col,slice] = ind2sub(size(rois{idx}),inds);
    point_sets{idx} = [row*vox_dim(1),col*vox_dim(2),slice*vox_dim(3)];
    ind_sets{idx} = [row,col,slice];
end
[hd,ix_1,ix_2] = directed_hausdorff(point_sets{1},point_sets{2});
inds_hd = [ix_1,ix_2];

% create verification ROI nifti of points used for Hausdorff distance
nii_out = nii1;
nii_out.img(:) = false;
for idx = 1:n_rois
    inds = ind_sets{idx};
    ix_hd = inds_hd(idx);
    nii_out.img(inds(ix_hd,1),inds(ix_hd,2),inds(ix_hd,3)) = true;
end
nii_out.img = uint8(nii_out.img);


% declare debugging struct
out = struct;
out.ind_sets = ind_sets;
out.inds_hd = inds_hd;
out.hd = hd;
out.vox_dim = vox_dim;

end
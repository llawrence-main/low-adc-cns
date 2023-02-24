function [vol,nii] = compute_roi_volume(fn)
% Returns the volume of a given ROI in NIfTI format
% Arguments
%     fn: filename of ROI NIfTI
% Returns
%     vol: volume of ROI in cm^3
%     nii: nifti of ROI

nii = nii_tool('load',fn);
nii.img = logical(nii.img);
n_vol = size(nii.img,4);
vol = zeros(1,n_vol);
for ix = 1:n_vol
    vol(ix) = nnz(nii.img(:,:,:,ix))*prod(nii.hdr.pixdim(2:4))*1e-3;
end

end
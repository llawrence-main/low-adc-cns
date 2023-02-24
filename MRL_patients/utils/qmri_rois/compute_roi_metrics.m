function [vol,nii] = compute_roi_metrics(fn)
% Returns the volume dynamic metrics for a given ROI in NIfTI format
% Arguments
%     fn: filename of ROI NIfTI
% Returns
%     vol: volume of ROI in cm^3
%     nii: nifti of ROI

nii = nii_tool('load',fn);
nii.img = logical(nii.img);
vol = nnz(nii.img)*prod(nii.hdr.pixdim(2:4))*1e-3;

end
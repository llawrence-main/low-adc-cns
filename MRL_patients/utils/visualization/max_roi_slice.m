function slice_nos = max_roi_slice(roi,dims)
%{
Returns the slice containing the greatest number of ROI voxels along given
dimension.
IN
roi: ROI
dim: dimension numbers
OUT
slice_nos: slice number with maximum number of ROI voxels in each requested
dimension
%}
% check inputs
assert(islogical(roi),'roi must be a logical array');
assert(nnz(roi)>0,'all voxels in roi are false');

% find max slice
num_dims = length(dims);
slice_nos = NaN(1,num_dims);
for dim_no = 1:num_dims
    dim = dims(dim_no);
    num_slices = size(roi,dim);
    inds = 1:ndims(roi);
    inds(dim) = inds(end);
    inds(end) = dim;    
    flat_roi = reshape(permute(roi,inds),[],num_slices);
    [~,slice_no] = max(sum(flat_roi));
    if nnz(roi)==0
        slice_no = NaN;
    end
    slice_nos(dim_no) = slice_no;
end
end
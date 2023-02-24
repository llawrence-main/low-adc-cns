function adjust_adc(fn_adc,p,fn_out)
% adjusts ADC values by applying a voxel-wise polynomial model 
% args:
%     fn_adc (str): filename of  ADC volume
%     p (array, double): coefficients of polynomial
%     fn_out (str): output filename

% read nifti
nii = nii_tool('load',fn_adc);
nii.img = double(nii.img)*nii.hdr.scl_slope+nii.hdr.scl_inter;
sz = size(nii.img);

% adjust values voxel-wise
flat = polyval(p,nii.img(:));

% reshape
nii.img = reshape(flat,sz);

% save
nii_tool('save',nii,fn_out);

end

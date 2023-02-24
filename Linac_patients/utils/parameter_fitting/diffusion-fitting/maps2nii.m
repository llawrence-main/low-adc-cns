function maps2nii(maps,nii_template,out_filebase)
%MAPS2NII Write parameter maps to NIfTIs.
%     MAPS2NII(MAPS,NII_TEMPLATE,OUT_FILEBASE) writes each field of the
%     structure MAPS to a NIfTI in the same space as NII_TEMPLATE and saves
%     to OUT_FILEBASE, appending the fieldname as a suffix. Assumes that
%     all maps have the same spatial dimensions as the template NIfTI.

% Parse inputs
mapnames = fieldnames(maps);
n_maps = length(mapnames);
assert(n_maps>0,'Maps structure is empty.');

% Overwrite slope and intercept values in template header
nii_template.hdr.scl_slope = 1;
nii_template.hdr.scl_inter = 0;

% Save maps
for ix = 1:n_maps
    % Get map
    name = mapnames{ix};
    map = maps.(name);
    % Overwrite dimensions in template
    nii_template.hdr.dim(1) = ndims(map);   
    nii_template.hdr.dim(5) = size(map,4);
    sz_map = size(map);
    assert(all(sz_map(1:3)==nii_template.hdr.dim(2:4)),...
        'All maps must have the same spatial dimensions as the NIfTI template.');
    % Save map
    nii_template.img = map;
    savename = [out_filebase,'_',name,'.nii.gz'];
    nii_tool('save',nii_template,savename);
end
end
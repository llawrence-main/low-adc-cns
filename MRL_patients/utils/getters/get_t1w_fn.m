function [fn_t1w,lab_t1w] = get_t1w_fn(folder)
% Returns the name of the T1w volumes in the given folder
% Arguents
%     folder: folder containing niftis
% Returns
%     fn_t1w: filenames of T1w volumes
%     lab_t1w: labels of T1w volumes (no parent, no extension)

d = dir(fullfile(folder,'*T1w*.nii.gz'));
n = numel(d);
fn_t1w = cell(1,n);
lab_t1w = cell(1,n);
for ix = 1:n
    lab_t1w{ix} = erase(d(ix).name,'.nii.gz');
    fn_t1w{ix} = fullfile(folder,d(ix).name);
end
end
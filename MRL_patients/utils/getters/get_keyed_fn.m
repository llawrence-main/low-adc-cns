function [fn,lab] = get_keyed_fn(folder,key,ext)
% Returns the name of files in the folder with the given key
% Arguents
%     folder: folder
%     key: keyword
%     ext: extension
% Returns
%     fn: filenames
%     lab: labels(no parent, no extension)

d = dir(fullfile(folder,['*',key,'*',ext]));
n = numel(d);
fn = cell(1,n);
lab = cell(1,n);
for ix = 1:n
    lab{ix} = erase(d(ix).name,'.nii.gz');
    fn{ix} = fullfile(folder,d(ix).name);
end
end
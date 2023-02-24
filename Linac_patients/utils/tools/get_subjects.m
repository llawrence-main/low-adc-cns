function subjects = get_subjects(root)
% return a list of subjects
% args:
%     root (str): root of project

info = dir(fullfile(root,'data','bids-mrsim-glio','sub-*'));
n = numel(info);
subjects = cell(n,1);
for ix = 1:n
    subjects{ix} = strrep(info(ix).name,'sub-','');
end


end
function subjects = get_subjects_man_tc(work)
% returns a list of subjects with mnaually-defined tumour core
% args:
%     work (str): working directory
% returns:
%     subjects (cell): list of subjects

folder = fullfile(work,'data','aiaa_seg_tc_modified');
subjects = cellstr(spm_select('List',folder,'dir','sub-'));
subjects = erase(subjects,'sub-');

end
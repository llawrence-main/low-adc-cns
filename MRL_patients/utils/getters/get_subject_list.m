function subjects = get_subject_list(work_dir)
% Returns the list of subjects for dwi_response
% Arguments
%     work_dir: working directory
% Returns
%     subjects: list of subjects

% fn_reference = fullfile(work_dir,'results','subject_reference_list.csv');
% T = readtable(fn_reference);
% subjects = T.Subject;
% [~,fns] = get_keyed_fn(fullfile(work_dir,'results','mr_sim','glio_contours'),'sub-','');
% subjects = reshape(erase(fns,'sub-'),[],1);
fn = fullfile(work_dir,'data','subject_list_dwi_response.xlsx');
t = readtable(fn);
subjects = t.ID;

end
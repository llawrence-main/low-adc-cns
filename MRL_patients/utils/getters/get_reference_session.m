function [ref_session,ref_name] = get_reference_session(work_dir,subject)
% Returns the reference session for a given subject
% Arguments
%     work_dir: working directory
%     subject: subject name
% Returns
%     ref_session: reference session (to which all volumes are registered)
%     ref_name: full reference name

fn_csv = fullfile(work_dir,'results','subject_reference_list.csv');
t = readtable(fn_csv);

loc = strcmp(t.Subject,subject);
ref_name = t.ReferenceVolume{loc};

bits = split(ref_name,'_');
ref_session = erase(bits{2},'ses-');


end
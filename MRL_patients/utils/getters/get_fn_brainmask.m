function fn_mask = get_fn_brainmask(work_dir,subject)
% Returns the filename for the brain mask for a given subject
% Arguments
%     work_dir: working directory
%     subject: subject name
% Returns
%     fn_mask: filename of brain mask

[session,name] = get_reference_session(work_dir,subject);
fn_mask = fullfile(work_dir,'results','mr_linac','seg',...
    ['sub-',subject],['ses-',session],...
    strcat(name,'_brain_mask.nii.gz'));

end

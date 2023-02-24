function brain_filename = get_brain_filename(seg_dir,subject)
% Returns the brain mask filename for a given subject
% Arguments
%     seg_dir: directory with segmentations
%     subject: subject name
% Returns
%     brain_filename: filename of brain mask

brain_dir = fullfile(seg_dir,subject,'ses-MRL001');
d = dir(fullfile(brain_dir,'*brain_mask.nii.gz'));
brain_filename = fullfile(brain_dir,d(1).name);

end
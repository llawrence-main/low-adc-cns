function fn = get_fn_brainmask(root,subject)
% return filename of HD-BET brain mask
% args:
%     root (str): root of project
%     subject (str): subject name
% returns:
%     fn (str): filename of brain mask

work = fullfile(root,'interim','derivatives','hdbet',...
    ['sub-',subject],'ses-GLIO01','anat');
info= dir(fullfile(work,'*_mask.nii.gz'));
fn = fullfile(work,info(1).name);

end
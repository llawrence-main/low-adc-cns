function fn = get_fn_contour(root,subject,session,name)
% returns the filename for the request contour for a given subject and session. Uses
% co-registered contours.
% args:
%     root (str): project root
%     subject (str): subject name
%     session (str): session name
% returns
%     fn (str): filename of contour. Empty if file does not exist.

% check inputs
validatestring(name,{'GTV','CTV','tumourcore'});

% declare filename
if strcmp(name,'tumourcore')
    contour_dir = fullfile(root,'interim','derivatives','coreg_aiaa_seg');
else
    contour_dir = fullfile(root,'interim','derivatives','coreg_contours');
end
fn = fullfile(contour_dir,['sub-',subject],['ses-',session],'anat',...
    sprintf('sub-%s_ses-%s_label-%s_desc-coreg_mask.nii.gz',subject,session,name));
if ~exist(fn,'file')
    warning('Returning empty string; File does not exist: %s\n',fn);
    fn = '';
end

end
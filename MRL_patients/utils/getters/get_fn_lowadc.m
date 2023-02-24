function [fns,labels] = get_fn_lowadc(roi_dir,subject,session)
% returns the filenames and labels of the low-ADC ROIs
% args:
%     roi_dir (str): ROI directory
%     subject (str): subject name
%     session (str): session name
% returns:
%     fns (cell): array of ROI filenames
%     labels (cell): array of labels

% scanner = session2scanner(session);
% if strcmp(scanner,'mrl')
fns = get_keyed_fn(fullfile(roi_dir,['sub-',subject],['ses-',session]),...
    'encl-tc',...
    '.nii.gz');
[~,names] = cellfun(@(x)fileparts(x),fns,'uniformoutput',0);
ks = strfind(names,'encl-tc');
labels = cellfun(@(x,y)x(y+8:y+13),names,ks,'uniformoutput',0);
% elseif strcmp(scanner,'sim')
%     fns = get_keyed_fn(fullfile(roi_dir,['sub-',subject],['ses-',session]),...
%         'low_adc',...
%         '.nii.gz');
%     labels = {session};
% end

end